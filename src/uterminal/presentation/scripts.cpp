#include "scripts.h"
#include "domain/parameters.h"
#include "infrastructure/storage.h"
#include "infrastructure/scriptfiles.h"
#include <QCollator>
#include <QDateTime>
#include <QDirIterator>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QSaveFile>
#include <QUuid>
#include <algorithm>

namespace ut {
namespace {
bool languageValid(const QString &s) { return QStringList{"python","powershell","cmd"}.contains(s); }
bool idValid(const QString &s) { static QRegularExpression r("^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$"); return r.match(s).hasMatch(); }
QString extension(const QString &s) { return s=="python"?"py":s=="cmd"?"cmd":"ps1"; }
QStringList legacyCommandWords(const QString &text,bool *valid){
    QStringList words;QString word;QChar quote;bool started=false;*valid=true;
    for(const auto ch:text){
        if(!quote.isNull()){if(ch==quote)quote=QChar();else word+=ch;started=true;continue;}
        if(ch=='"'||ch=='\''){quote=ch;started=true;continue;}
        if(ch=='#')break;
        if(ch.isSpace()){if(started){words.append(word);word.clear();started=false;}}
        else{word+=ch;started=true;}
    }
    if(started)words.append(word);*valid=quote.isNull();return words;
}
}
Scripts::Scripts(const QString &directory,QObject *parent):QAbstractListModel(parent),m_directory(directory) {
    connect(this,&Scripts::selectionChanged,this,&Scripts::parameterValuesChanged);
    m_state=readJson(directory+"/state.json"); m_sort=m_state["sortMode"].toString("added_time");
    reload(); m_draft=readJson(directory+"/draft.json");
}
int Scripts::rowCount(const QModelIndex &p) const { return p.isValid()?0:m_visible.size(); }
QHash<int,QByteArray> Scripts::roleNames() const { return {{IdRole,"scriptId"},{TitleRole,"title"},{DescriptionRole,"description"},{LanguageRole,"language"},{IconRole,"iconName"},{SelectedRole,"selected"},{RunningRole,"running"},{FavoriteRole,"favorite"}}; }
QVariant Scripts::data(const QModelIndex &i,int role) const {
    if(!i.isValid()||i.row()<0||i.row()>=m_visible.size())return {};
    const auto &s=m_visible[i.row()];
    switch(role){case IdRole:return s["id"].toString();case TitleRole:return s["title"].toString();case DescriptionRole:return s["description"].toString();case LanguageRole:return s["language"].toString();case IconRole:return s["icon"].toString("terminal");case SelectedRole:return s["id"].toString()==m_selected;case RunningRole:return m_running.contains(s["id"].toString());case FavoriteRole:return s["favorite"].toBool();default:return {};}
}
QJsonObject Scripts::get(const QString &id)const { for(const auto&s:m_items)if(s["id"].toString()==id)return s;return {}; }
QVariantMap Scripts::selected()const { return get(m_selected).toVariantMap(); }
QVariantList Scripts::parameters()const { return get(m_selected)["parameters"].toArray().toVariantList(); }
QVariantMap Scripts::parameterValues()const {
    QVariantMap result;const auto inputs=m_parameterInputs.value(m_selected);
    for(const auto &entry:parameters()){
        const auto parameter=entry.toMap();const auto id=parameter["id"].toString();
        if(parameter["kind"].toString()=="boolean"){result[id]=inputs.value(id,parameter.value("default")).toBool();continue;}
        auto value=inputs.value(id,parameter.value("default")).toString();
        if(parameter["kind"].toString()=="choice"){
            bool found=false;for(const auto &option:parameter["options"].toList())found|=option.toMap()["value"].toString()==value;
            if(!found)value=parameter["default"].toString();
        }
        result[id]=value;
    }
    return result;
}
void Scripts::setParameterValue(const QString &id,const QString &value){
    if(!parameterValues().contains(id))return;
    for(const auto &entry:parameters()){
        const auto parameter=entry.toMap();if(parameter["id"].toString()!=id)continue;
        if(parameter["kind"].toString()=="boolean"){emit error(QStringLiteral("请使用复选框修改布尔参数"));return;}
        if(parameter["kind"].toString()!="choice")continue;
        bool valid=false;for(const auto &option:parameter["options"].toList())valid|=option.toMap()["value"].toString()==value;
        if(!valid){emit error(QStringLiteral("请选择有效选项：")+parameter["label"].toString());return;}
    }
    m_parameterInputs[m_selected][id]=value;emit parameterValuesChanged();
}
void Scripts::setBooleanParameter(const QString &id,bool value){
    for(const auto &entry:parameters())if(entry.toMap()["id"].toString()==id&&entry.toMap()["kind"].toString()=="boolean"){
        m_parameterInputs[m_selected][id]=value;emit parameterValuesChanged();return;
    }
}
bool Scripts::dropParameterFile(const QString &id,const QList<QUrl> &urls){
    if(urls.size()!=1 || !urls.first().isLocalFile())return false;
    const auto path=urls.first().toLocalFile();if(path.isEmpty())return false;
    for(const auto ch:path)if(ch.unicode()<32 || ch==QChar(127))return false;
    for(const auto &entry:parameters()){
        const auto parameter=entry.toMap();
        const auto kind=parameter["kind"].toString();
        if(parameter["id"].toString()==id && (kind=="file" || kind=="directory")){
            if(kind=="directory"&&!QFileInfo(path).isDir())return false;
            setParameterValue(id,QDir::toNativeSeparators(path));return true;
        }
    }
    return false;
}
void Scripts::resetParameterValues(){m_parameterInputs.remove(m_selected);emit parameterValuesChanged();}
QString Scripts::argumentError(const QJsonObject &script){
    const auto value=script["arguments"];if(value.isUndefined()||value.isNull())return {};
    if(!value.isArray())return QStringLiteral("命令行参数必须是 JSON 字符串数组");
    if(!value.toArray().isEmpty()&&script["language"].toString()!="python")return QStringLiteral("独立命令行参数目前仅支持 Python；旧版 PowerShell/BAT 不执行这些参数，请先移除或转换");
    for(const auto &entry:value.toArray()){
        if(!entry.isString()||entry.toString().contains(QChar(0)))return QStringLiteral("每个命令行参数必须是无空字符的文本");
    }
    return {};
}
QString Scripts::parameterSource(const QJsonObject &script){
    QString source=script["code"].toString();
    for(const auto &argument:script["arguments"].toArray())source+='\n'+argument.toString();
    return source;
}
QJsonObject Scripts::resolvedArgumentConditions(QJsonObject script,const QVariantMap &values){
    if(!script.value("legacyConditionalArguments").toBool())return script;
    QJsonArray arguments;
    for(const auto &entry:script["arguments"].toArray()){
        auto text=entry.toString();const auto colon=text.indexOf(':');
        if(text.startsWith('?')&&colon>=0){
            const auto value=values.value(text.mid(1,colon-1));
            if(!value.isValid()||value.isNull()||(value.metaType().id()==QMetaType::QString?value.toString().isEmpty():!value.toBool()))continue;
            text=text.mid(colon+1);
        }
        arguments.append(text);
    }
    script["arguments"]=arguments;script.remove("legacyConditionalArguments");return script;
}
bool Scripts::setDraftArguments(const QString &json){
    const auto doc=QJsonDocument::fromJson(json.toUtf8());
    if(!doc.isArray()){emit error(QStringLiteral("请输入 JSON 字符串数组，例如 [\"--name\",\"中文名称\"]"));return false;}
    auto next=m_draft;next["arguments"]=doc.array();const auto problem=argumentError(next);
    if(!problem.isEmpty()){emit error(problem);return false;}
    updateDraft("arguments",doc.array().toVariantList());return true;
}
void Scripts::setDraftArgument(int index,const QString &value){
    auto arguments=m_draft["arguments"].toArray();if(index<0||index>arguments.size())return;
    if(index==arguments.size())arguments.append(value);else arguments[index]=value;
    updateDraft("arguments",arguments.toVariantList());
}
void Scripts::removeDraftArgument(int index){
    auto arguments=m_draft["arguments"].toArray();if(index<0||index>=arguments.size())return;
    arguments.removeAt(index);updateDraft("arguments",arguments.toVariantList());
}
QString Scripts::environmentError(const QJsonValue &environment) {
    if(environment.isUndefined()||environment.isNull())return {};
    if(!environment.isObject())return QStringLiteral("环境变量必须是名称和值的映射");
    QSet<QString> names;
    const auto entries=environment.toObject();
    for(auto it=entries.begin();it!=entries.end();++it){
        const auto name=it.key().toUpper();
        if(name.isEmpty()||name.contains('=')||name.contains(QChar(0))||name.contains('\n')||name.contains('\r'))return QStringLiteral("环境变量名称无效：")+it.key();
        if(!it.value().isString()||it.value().toString().contains(QChar(0)))return QStringLiteral("环境变量值必须是无空字符的文本：")+it.key();
        if(names.contains(name))return QStringLiteral("Windows 环境变量名称不区分大小写，存在重复：")+it.key();
        if(name.startsWith("PYTHON")||name.startsWith("UTERMINAL_")||name=="VIRTUAL_ENV"||name=="POPTOOLS_OUTPUT_DIR")return QStringLiteral("此环境变量由应用管理：")+it.key();
        names.insert(name);
    }
    return {};
}
QVariantList Scripts::draftEnvironment()const {
    QVariantList rows;const auto entries=m_draft["env"].toObject();
    for(auto it=entries.begin();it!=entries.end();++it)rows.append(QVariantMap{{"name",it.key()},{"value",it.value().toString()}});
    return rows;
}
bool Scripts::setDraftEnvironment(const QString &name,const QString &value){
    auto entries=m_draft["env"].toObject();entries[name]=value;
    auto problem=environmentError(entries);if(!problem.isEmpty()){emit error(problem);return false;}
    updateDraft("env",entries.toVariantMap());return true;
}
void Scripts::removeDraftEnvironment(const QString &name){auto entries=m_draft["env"].toObject();entries.remove(name);updateDraft("env",entries.toVariantMap());}
void Scripts::reload(){
    m_items.clear();
    QDir root(m_directory+"/scripts");
    for(const auto &name:root.entryList(QDir::Dirs|QDir::NoDotAndDotDot)){
        QString problem; auto item=readJson(root.filePath(name+"/definition.json"),&problem);
        if(item.isEmpty()) { if(!problem.isEmpty())emit error(problem);continue; }
        auto relative=item["sourcePath"].toString();
        if(QFileInfo(relative).fileName()!=relative || !idValid(item["id"].toString())){emit error(QStringLiteral("脚本路径无效：")+name);continue;}
        QFile code(root.filePath(name+"/"+relative));
        if(!code.open(QIODevice::ReadOnly)){emit error(code.errorString());continue;}
        item["code"]=QString::fromUtf8(code.readAll());
        if(!item.contains("env")&&item.contains("environment"))item["env"]=item["environment"];
        m_items.append(item);
    }
    if(get(m_selected).isEmpty())m_selected=m_items.isEmpty()?QString():m_items.first()["id"].toString();
    rebuild();emit countChanged();emit selectionChanged();
}
QStringList Scripts::customOrder() const {
    auto items=m_items;std::stable_sort(items.begin(),items.end(),[](const auto&a,const auto&b){return a["order"].toInt()<b["order"].toInt();});
    QSet<QString> available,seen;for(const auto &item:items)available.insert(item["id"].toString());
    QStringList result;
    for(const auto &entry:m_state["customOrder"].toArray()){const auto id=entry.toString();if(available.contains(id)&&!seen.contains(id)){result.append(id);seen.insert(id);}}
    for(const auto &item:items){const auto id=item["id"].toString();if(!seen.contains(id))result.append(id);}
    return result;
}
void Scripts::rebuild(){
    beginResetModel();m_visible.clear();
    for(const auto &s:m_items){
        if(m_filter=="favorite"&&!s["favorite"].toBool())continue;
        if(m_filter!="all"&&m_filter!="favorite"&&s["language"].toString()!=m_filter)continue;
        if(!m_query.isEmpty()&&!(s["title"].toString()+" "+s["description"].toString()+" "+s["language"].toString()).contains(m_query,Qt::CaseInsensitive))continue;
        m_visible.append(s);
    }
    QCollator collator(QLocale("zh_CN"));collator.setCaseSensitivity(Qt::CaseInsensitive);collator.setNumericMode(true);
    auto usage=m_state["usage"].toObject(); auto recent=m_state["recent"].toObject();
    QHash<QString,int> ranks;const auto order=customOrder();for(int i=0;i<order.size();++i)ranks[order[i]]=i;
    std::stable_sort(m_visible.begin(),m_visible.end(),[&](const auto&a,const auto&b){
        auto ai=a["id"].toString(),bi=b["id"].toString();
        if(m_sort=="name")return collator.compare(a["title"].toString(),b["title"].toString())<0;
        if(m_sort=="usage")return usage[ai].toInt()>usage[bi].toInt();
        if(m_sort=="recent")return recent[ai].toDouble()>recent[bi].toDouble();
        if(m_sort=="custom")return ranks.value(ai)<ranks.value(bi);
        return a["createdAt"].toDouble()>b["createdAt"].toDouble();
    });endResetModel();
}
void Scripts::setQuery(const QString &v){m_query=v.trimmed();rebuild();emit filterChanged();}
void Scripts::setLanguageFilter(const QString &v){m_filter=v;rebuild();emit filterChanged();}
void Scripts::setSortMode(const QString &v){if(!QStringList{"name","usage","recent","custom","added_time"}.contains(v))return;m_sort=v;m_state["sortMode"]=v;saveState();rebuild();emit filterChanged();}
void Scripts::select(const QString &id){if(get(id).isEmpty())return;m_selected=id;rebuild();emit selectionChanged();}
void Scripts::newDraft(const QString &code,const QString &language){
    m_draft={{"id",""},{"title",""},{"description",""},{"language",languageValid(language)?language:"powershell"},{"code",code},{"icon","terminal"},{"timeoutSeconds",300},{"executionMode","process"},{"workingDirectory",""},{"confirmBeforeRun",false}};
    writeJson(m_directory+"/draft.json",m_draft);emit draftChanged();
}
void Scripts::editSelected(){m_draft=get(m_selected);writeJson(m_directory+"/draft.json",m_draft);emit draftChanged();}
void Scripts::updateDraft(const QString &key,const QVariant &v){
    if(key=="language"&&languageValid(v.toString())&&v.toString()!=m_draft["language"].toString()&&m_draft.contains("bundleEntryPoint")){
        // Keep the imported basename when changing language; save validation prevents
        // the renamed entry point from overwriting an attachment.
        const auto entry=m_draft["bundleEntryPoint"].toString();
        m_draft["bundleEntryPoint"]=QFileInfo(entry).completeBaseName()+"."+extension(v.toString());
    }
    m_draft[key]=QJsonValue::fromVariant(v);writeJson(m_directory+"/draft.json",m_draft);emit draftChanged();
}
bool Scripts::persist(QJsonObject item){
    const auto argumentProblem=argumentError(item);if(!argumentProblem.isEmpty()){emit error(argumentProblem);return false;}
    const auto environmentProblem=environmentError(item["env"]);if(!environmentProblem.isEmpty()){emit error(environmentProblem);return false;}
    auto id=item["id"].toString(); auto language=item["language"].toString();
    if(!idValid(id)||!languageValid(language)){emit error(QStringLiteral("脚本标识或语言无效"));return false;}
    QString dir=m_directory+"/scripts/"+id;QDir().mkpath(dir);
    const auto definitionPath=dir+"/definition.json";
    if(QFile::exists(definitionPath)&&backupFile(definitionPath,m_directory+"/backups").isEmpty()){
        emit error(QStringLiteral("无法备份原脚本，未保存修改。请检查备份目录和可用磁盘空间：")+m_directory+"/backups");return false;
    }
    QString source="source-"+QUuid::createUuid().toString(QUuid::Id128)+"."+extension(language);
    QSaveFile f(dir+"/"+source);auto bytes=item["code"].toString().toUtf8();
    if(!f.open(QIODevice::WriteOnly)||f.write(bytes)!=bytes.size()||!f.commit()){emit error(f.errorString());return false;}
    item.remove("code");item["sourcePath"]=source;item["schemaVersion"]=1;
    QString problem;if(!writeJson(definitionPath,item,&problem)){QFile::remove(dir+"/"+source);emit error(problem);return false;}
    return true;
}
bool Scripts::saveDraft(){
    if(m_draft["title"].toString().trimmed().isEmpty()||m_draft["code"].toString().trimmed().isEmpty()){emit error(QStringLiteral("请填写脚本名称和代码"));return false;}
    auto parsed=Parameters::parse(parameterSource(m_draft),m_draft.value("parameterMetadata").toArray());if(!parsed.error.isEmpty()){emit error(parsed.error);return false;}
    auto next=m_draft;next["parameters"]=parsed.parameters;
    const auto filesProblem=scriptFilesError(next);if(!filesProblem.isEmpty()){emit error(filesProblem);return false;}
    if(next["id"].toString().isEmpty()){next["id"]="custom."+QUuid::createUuid().toString(QUuid::Id128);next["createdAt"]=double(QDateTime::currentMSecsSinceEpoch());next["order"]=m_items.size();}
    next["revision"]=next["revision"].toInt()+1;next["modifiedAt"]=double(QDateTime::currentMSecsSinceEpoch());
    if(!persist(next))return false;
    m_selected=next["id"].toString();m_draft=next;writeJson(m_directory+"/draft.json",m_draft);reload();emit saved();return true;
}
bool Scripts::deleteSelected(){
    if(m_running.contains(m_selected)){emit error(QStringLiteral("请先停止脚本"));return false;}
    if(get(m_selected).isEmpty())return false;
    auto src=m_directory+"/scripts/"+m_selected;auto dest=m_directory+"/backups/deleted-"+m_selected+"-"+QUuid::createUuid().toString(QUuid::Id128);
    QDir().mkpath(m_directory+"/backups");if(!QDir().rename(src,dest)){emit error(QStringLiteral("无法将脚本移入备份目录"));return false;}
    m_parameterInputs.remove(m_selected);
    reload();return true;
}
void Scripts::toggleFavorite(const QString&id){auto s=get(id);if(s.isEmpty())return;s["favorite"]=!s["favorite"].toBool();if(persist(s))reload();}
bool Scripts::move(const QString&id,int index){
    if(m_sort!="custom"||index<0||index>=m_visible.size())return false;
    auto list=m_visible;qsizetype from=-1;for(qsizetype i=0;i<list.size();++i)if(list[i]["id"].toString()==id)from=i;
    if(from<0)return false;if(from==index)return true;list.move(from,index);
    auto order=customOrder();QSet<QString> visible;for(const auto &item:list)visible.insert(item["id"].toString());
    int next=0;for(auto &entry:order)if(visible.contains(entry))entry=list[next++]["id"].toString();
    auto state=m_state;state["customOrder"]=QJsonArray::fromStringList(order);QString problem;
    if(!writeJson(m_directory+"/state.json",state,&problem)){emit error(problem);return false;}
    m_state=state;rebuild();return true;
}
QString Scripts::exportSelected()const{return QString::fromUtf8(QJsonDocument(QJsonObject{{"format","uterminal.script"},{"format_version",1},{"script",get(m_selected)}}).toJson());}
QVariantMap Scripts::importText(const QString &text,bool replace){
    auto doc=QJsonDocument::fromJson(text.toUtf8());if(!doc.isObject())return {{"status","error"},{"message",QStringLiteral("无效 JSON")}};
    auto root=doc.object();QJsonObject item;
    if(root["format"].toString()=="uterminal.script"&&root["format_version"].toInt()==1)item=root["script"].toObject();
    else if(root["format"].toString()=="poptools.custom-script"&&root["format_version"].toInt()==1)item=root["tool"].toObject();
    else if(root.contains("executor")||root.contains("language"))item=root;
    else return {{"status","error"},{"message",QStringLiteral("不支持的分享格式或版本")}};
    if(item.contains("executor")){
        if(item.contains("parameters")&&!item.value("parameters").isArray())return {{"status","error"},{"message",QStringLiteral("旧参数定义必须是数组")}};
        item["parameterMetadata"]=item.value("parameters").toArray();
        auto executor=item["executor"].toObject();auto language=executor["kind"].toString();if(language=="batch")language="cmd";
        if(executor.contains("requirements"))item["externalRequirements"]=executor["requirements"];
        item["language"]=language;item["code"]=executor["command"];item["workingDirectory"]=executor["cwd"];
        item["useOutputDirectoryAsWorkingDirectory"]=executor["cwd"].toString().isEmpty();
        item["env"]=executor["env"];item["timeoutSeconds"]=executor["timeout_seconds"];
        item["icon"]=item["presentation"].toObject()["icon"];item["confirmBeforeRun"]=item["presentation"].toObject()["confirm_before_run"];
        for(const auto &argument:executor["args"].toArray())if(argument.toString().startsWith('?')&&argument.toString().contains(':'))
            item["legacyConditionalArguments"]=true;
        item["arguments"]=executor["args"];
        item.remove("executor");item.remove("presentation");
    }
    if(!languageValid(item["language"].toString())||!idValid(item["id"].toString())||item["code"].toString().trimmed().isEmpty())return {{"status","error"},{"message",QStringLiteral("脚本语言、ID 或源码无效")}};
    const auto requirements=item.value("externalRequirements");
    if(!requirements.isUndefined()){
        if(!requirements.isArray())return {{"status","error"},{"message",QStringLiteral("外部运行要求必须是字符串数组")}};
        for(const auto &value:requirements.toArray()){
            if(!value.isString()||value.toString().trimmed().isEmpty())return {{"status","error"},{"message",QStringLiteral("外部运行要求包含无效条目")}};
            if(value.toString().trimmed().compare("android_device",Qt::CaseInsensitive)==0)
                return {{"status","error"},{"message",QStringLiteral("此脚本依赖旧版 android_device 设备选择机制，UTerminal 不支持；请先改写为独立脚本")}};
        }
    }
    if(!item.contains("env")&&item.contains("environment"))item["env"]=item["environment"];
    const auto environmentProblem=environmentError(item["env"]);if(!environmentProblem.isEmpty())return {{"status","error"},{"message",environmentProblem}};
    const auto filesProblem=scriptFilesError(item);if(!filesProblem.isEmpty())return {{"status","error"},{"message",filesProblem}};
    const auto argumentProblem=argumentError(item);if(!argumentProblem.isEmpty())return {{"status","error"},{"message",argumentProblem}};
    if(!get(item["id"].toString()).isEmpty()&&!replace)return {{"status","duplicate"},{"message",QStringLiteral("存在同名 ID，是否替换？")}};
    if(m_running.contains(item["id"].toString()))return {{"status","error"},{"message",QStringLiteral("不能覆盖运行中的脚本")}};
    if(item.contains("parameterMetadata")&&!item.value("parameterMetadata").isArray())return {{"status","error"},{"message",QStringLiteral("参数元数据必须是数组")}};
    auto parsed=Parameters::parse(parameterSource(item),item.value("parameterMetadata").toArray());if(!parsed.error.isEmpty())return {{"status","error"},{"message",parsed.error}};
    item["parameters"]=parsed.parameters;item["createdAt"]=double(QDateTime::currentMSecsSinceEpoch());
    if(!persist(item))return {{"status","error"},{"message",QStringLiteral("保存失败")}};
    m_selected=item["id"].toString();reload();return {{"status","ok"}};
}
bool Scripts::exportCollection(const QString&directory){
    QJsonArray scripts;for(const auto&s:m_items)scripts.append(s);
    QString error;bool ok=writeJson(directory+"/uterminal-scripts.json",{{"format","uterminal.collection"},{"version",1},{"scripts",scripts}},&error);if(!ok)emit this->error(error);return ok;
}
QString Scripts::importCollection(const QString&directory){
    QStringList report;auto collection=readJson(directory+"/uterminal-scripts.json");
    QJsonArray entries=collection.value("scripts").toArray();
    if(collection.isEmpty()){
        QDirIterator it(directory+"/tools",{"*.json"},QDir::Files,QDirIterator::Subdirectories);
        while(it.hasNext()){auto path=it.next();QString readError;auto entry=readJson(path,&readError);if(entry.isEmpty()){report.append(path+": "+(readError.isEmpty()?QStringLiteral("空脚本定义"):readError));continue;}
            auto ex=entry["executor"].toObject();auto command=ex["command"].toString();
            const auto kind=ex["kind"].toString();
            QString source=command.trimmed();
            if(source.size()>1&&((source.front()=='"'&&source.back()=='"')||(source.front()=='\''&&source.back()=='\'')))source=source.mid(1,source.size()-2);
            QStringList commandArguments;bool validWords=true;
            if(kind=="python"&&!command.contains('\n')&&!command.contains('\r')){
                auto words=legacyCommandWords(command,&validWords);
                if(!words.isEmpty()&&words.first().endsWith(".py",Qt::CaseInsensitive)){source=words.takeFirst();commandArguments=words;}
            }
            const bool fileReference=!source.contains('\n')&&!source.contains('\r')&&((kind=="python"&&source.endsWith(".py",Qt::CaseInsensitive))||(kind=="batch"&&(source.endsWith(".bat",Qt::CaseInsensitive)||source.endsWith(".cmd",Qt::CaseInsensitive))));
            QString candidate=QDir(directory).absoluteFilePath(source);
            auto base=QDir(directory).canonicalPath()+"/";auto canonical=QFileInfo(candidate).canonicalFilePath();
            if(fileReference){
                if(!validWords){report.append(entry["title"].toString()+": "+QStringLiteral("源码命令的引号未闭合"));continue;}
                if(canonical.isEmpty()||!QFileInfo(canonical).isFile()){report.append(entry["title"].toString()+": "+QStringLiteral("源码文件不存在：")+source);continue;}
                if(!canonical.startsWith(base,Qt::CaseInsensitive)){report.append(entry["title"].toString()+": "+QStringLiteral("源码文件不在所选集合目录内：")+source);continue;}
                QFile f(canonical);if(!f.open(QIODevice::ReadOnly)){report.append(entry["title"].toString()+": "+f.errorString());continue;}
                ex["command"]=QString::fromUtf8(f.readAll());
                QString attachmentsError;
                if(!captureScriptFiles(canonical,&entry,&attachmentsError)){report.append(entry["title"].toString()+": "+attachmentsError);continue;}
                if(!commandArguments.isEmpty()){
                    const auto existing=ex.value("args");if(!existing.isUndefined()&&!existing.isNull()&&!existing.isArray()){report.append(entry["title"].toString()+": "+QStringLiteral("旧版 args 必须为数组"));continue;}
                    QJsonArray args;for(const auto &argument:commandArguments)args.append(argument);for(const auto &argument:existing.toArray())args.append(argument);ex["args"]=args;
                }
                entry["executor"]=ex;
            }
            entries.append(entry);
        }
    }
    for(const auto&e:entries){auto result=importText(QString::fromUtf8(QJsonDocument(e.toObject()).toJson()),false);report.append(e.toObject()["title"].toString()+": "+result.value("status").toString()+" "+result.value("message").toString());}
    return report.isEmpty()?QStringLiteral("未找到可导入脚本"):report.join('\n');
}
void Scripts::setParameterDefault(const QString&id,const QString&value){
    auto item=get(m_selected);if(item.isEmpty())return;
    const auto code=Parameters::withDefault(item["code"].toString(),id,value);
    item["code"]=code;QJsonArray arguments;
    for(const auto &argument:item["arguments"].toArray())arguments.append(Parameters::withDefault(argument.toString(),id,value));
    if(item.contains("arguments"))item["arguments"]=arguments;
    const auto parsed=Parameters::parse(parameterSource(item),item.value("parameterMetadata").toArray());bool matches=false;
    for(const auto &entry:parsed.parameters){const auto p=entry.toObject();if(p["id"].toString()==id)matches=p["default"].toString()==value;}
    if(!parsed.error.isEmpty()||!matches){emit error(QStringLiteral("此值无法保存为参数默认值，请检查选项或参数语法"));return;}
    item["code"]=code;item["parameters"]=parsed.parameters;item["revision"]=item["revision"].toInt()+1;item["modifiedAt"]=double(QDateTime::currentMSecsSinceEpoch());
    if(persist(item))reload();
}
void Scripts::saveState(){QString problem;if(!writeJson(m_directory+"/state.json",m_state,&problem))emit error(problem);}
void Scripts::setRunning(const QString&id,bool running){if(running)m_running.insert(id);else m_running.remove(id);rebuild();}
void Scripts::recordUse(const QString&id){auto usage=m_state["usage"].toObject();usage[id]=usage[id].toInt()+1;m_state["usage"]=usage;auto recent=m_state["recent"].toObject();recent[id]=double(QDateTime::currentMSecsSinceEpoch());m_state["recent"]=recent;saveState();rebuild();}
}
