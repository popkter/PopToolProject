#include <QtTest>
#include <QTemporaryDir>
#include "domain/parameters.h"
#include "presentation/scripts.h"
#include "presentation/settings.h"
#include "application/pythonenvironment.h"
#include "application/plugins.h"
#include "application/updates.h"
#include "infrastructure/updatepackage.h"
#include "infrastructure/storage.h"
#include "infrastructure/scriptfiles.h"
#include <QNetworkReply>
#include <QJsonDocument>

class FixtureReply : public QNetworkReply {
    QByteArray m_bytes;qsizetype m_position=0;bool m_ready=false;
public:
    FixtureReply(const QNetworkRequest &request,QByteArray bytes,QObject *parent):QNetworkReply(parent),m_bytes(std::move(bytes)){
        setRequest(request);setUrl(request.url());open(QIODevice::ReadOnly|QIODevice::Unbuffered);
        QTimer::singleShot(0,this,[this]{if(isFinished())return;m_ready=true;emit readyRead();if(isFinished())return;setFinished(true);emit finished();});
    }
    void abort()override{if(isFinished())return;setError(OperationCanceledError,"cancelled");setFinished(true);emit finished();}
    qint64 bytesAvailable()const override{return (m_ready?m_bytes.size()-m_position:0)+QNetworkReply::bytesAvailable();}
protected:
    qint64 readData(char *data,qint64 max)override{const auto count=qMin(max,bytesAvailable());if(count<=0)return -1;memcpy(data,m_bytes.constData()+m_position,size_t(count));m_position+=count;return count;}
};
class FixtureNetwork : public QNetworkAccessManager {
public:
    QList<QByteArray> responses;
protected:
    QNetworkReply *createRequest(Operation,const QNetworkRequest &request,QIODevice *)override{return new FixtureReply(request,responses.isEmpty()?QByteArray():responses.takeFirst(),this);}
};

class CoreTests:public QObject {
    Q_OBJECT
private slots:
    void packageArguments(){QString error;QCOMPARE(ut::PythonEnvironment::packageArguments("Pillow>=10 requests==2.32.3",&error).size(),2);QVERIFY(error.isEmpty());ut::PythonEnvironment::packageArguments("--target C:/other",&error);QVERIFY(!error.isEmpty());}
    void pythonWriteReservation(){QTemporaryDir tmp;ut::Plugins plugins(tmp.path(),tmp.path());QVERIFY(plugins.reservePython("3.13.14"));QVERIFY(plugins.pythonReserved("3.13.14"));QVERIFY(!plugins.reservePython("3.13.14"));plugins.acquire("python","3.13.14");QVERIFY(plugins.inUse("python","3.13.14"));plugins.release("python","3.13.14");QVERIFY(!plugins.inUse("python","3.13.14"));plugins.releasePythonReservation("3.13.14");QVERIFY(!plugins.pythonReserved("3.13.14"));}
    void parameterDeclarations(){
        auto source=QStringLiteral("Var VIN = ${车架号:abc}\nprint('${VIN}')\n${模式:开=1|关=0} ${文件@file}");
        auto parsed=ut::Parameters::parse(source);QVERIFY2(parsed.error.isEmpty(),qPrintable(parsed.error));QCOMPARE(parsed.parameters.size(),3);
        QString error;auto text=ut::Parameters::render(source,{{"VIN","中文"},{"文件","C:/a b.txt"}},&error);
        QVERIFY(error.isEmpty());QVERIFY(!text.contains("Var VIN"));QVERIFY(text.contains("print('中文')"));QVERIFY(text.contains("1 C:/a b.txt"));
    }
    void missingParameter(){QString error;ut::Parameters::render("${required}",{},&error);QVERIFY(!error.isEmpty());}
    void updateDownloadCacheAndCancellation(){
        QTemporaryDir tmp;ut::Settings settings(tmp.path());ut::Plugins plugins(tmp.path(),tmp.path());FixtureNetwork network;
        const QByteArray package="fixture package bytes";const auto hash=QString::fromLatin1(QCryptographicHash::hash(package,QCryptographicHash::Sha256).toHex());
        const QJsonObject asset{{"name","UTerminal-0.2.0-win-x64-setup.exe"},{"browser_download_url","https://github.com/popkter/PopToolProject/releases/download/v0.2.0/setup.exe"},{"digest","sha256:"+hash},{"size",package.size()}};
        network.responses.append(QJsonDocument(QJsonArray{QJsonObject{{"tag_name","v0.2.0"},{"assets",QJsonArray{asset}}}}).toJson());
        ut::Updates updates(tmp.path(),&settings,&plugins,nullptr,&network);updates.check();QTRY_VERIFY(!updates.busy());QVERIFY(!updates.available().isEmpty());
        network.responses.append(package);updates.download();updates.cancelDownload();QVERIFY(!updates.busy());QVERIFY(updates.downloaded().isEmpty());
        network.responses.append(package);updates.download();QTRY_VERIFY(!updates.busy());QCOMPARE(updates.downloaded()["version"].toString(),QString("0.2.0"));QVERIFY(!updates.installOnExit());
        const auto path=tmp.path()+"/updates/"+updates.downloaded()["file"].toString();QVERIFY(ut::verifyUpdatePackage(path,package.size(),hash));
        updates.setInstallOnExit(true);QVERIFY(updates.installOnExit());updates.setInstallOnExit(false);
        {ut::Updates restored(tmp.path(),&settings,&plugins);QCOMPARE(restored.downloaded()["version"].toString(),QString("0.2.0"));QVERIFY(!restored.installOnExit());}
        QFile altered(path);QVERIFY(altered.open(QIODevice::WriteOnly|QIODevice::Truncate));altered.write("bad");altered.close();
        updates.setInstallOnExit(true);QVERIFY(!updates.installOnExit());ut::Updates rejected(tmp.path(),&settings,&plugins);QVERIFY(rejected.downloaded().isEmpty());
    }
    void updateSelectionAndPolicy(){
        auto release=[](const QString &version,bool preview=false,const QString &name=QString()){
            QJsonObject asset{{"name",name.isEmpty()?"UTerminal-"+version+"-win-x64-setup.exe":name},{"browser_download_url","https://github.com/popkter/PopToolProject/releases/download/v"+version+"/setup.exe"},{"digest","sha256:"+QString(64,'a')},{"size",1234}};
            return QJsonObject{{"tag_name","v"+version},{"prerelease",preview},{"assets",QJsonArray{asset}}};
        };
        QJsonArray releases{release("0.3.0-beta.2",true),release("0.2.0"),release("9.0.0",false,"PopTools-9.0.0-setup.exe"),release("0.3.0-beta.10",true)};
        QCOMPARE(ut::Updates::selectRelease(releases,"0.1.0",false)["version"].toString(),QString("0.2.0"));
        QCOMPARE(ut::Updates::selectRelease(releases,"0.1.0",true)["version"].toString(),QString("0.3.0-beta.10"));
        QVERIFY(ut::Updates::selectRelease(releases,"0.3.0",true).isEmpty());
        auto stable=release("0.3.0");stable["tag_name"]="uterminal-v0.3.0";releases.append(stable);
        QCOMPARE(ut::Updates::selectRelease(releases,"0.3.0-beta.10",true)["version"].toString(),QString("0.3.0"));
        const QJsonObject developmentAsset{{"name","UTerminal-0.3.0-win-x64-setup.exe"},{"browser_download_url","https://github.com/popkter/PopToolProject/releases/download/uterminal-dev-200/UTerminal-0.3.0-win-x64-setup.exe"},{"digest","sha256:"+QString(64,'b')},{"size",4321}};
        const QJsonObject development{{"tag_name","uterminal-dev-200"},{"prerelease",true},{"assets",QJsonArray{developmentAsset}}};
        QVERIFY(ut::Updates::selectRelease(QJsonArray{development},"0.3.0",false).isEmpty());
        QCOMPARE(ut::Updates::selectRelease(QJsonArray{development},"0.3.0",true)["version"].toString(),QString("0.3.0-dev.200"));
        QVERIFY(ut::Updates::selectRelease(QJsonArray{development},"0.3.0-dev.200",true).isEmpty());
        QCOMPARE(ut::Updates::selectRelease(QJsonArray{development},"0.3.0-dev.199",true)["buildId"].toInteger(),qint64(200));
        const auto semanticDevelopment=release("0.4.0-dev.201",true);
        QCOMPARE(ut::Updates::selectRelease(QJsonArray{semanticDevelopment},"0.3.0",true)["version"].toString(),QString("0.4.0-dev.201"));
        QVERIFY(!ut::Updates::due("manual",0,100000,false));QVERIFY(ut::Updates::due("startup",100000,100000,false));QVERIFY(!ut::Updates::due("startup",0,100000,true));
        QVERIFY(!ut::Updates::due("daily",100000,100001,true));QVERIFY(ut::Updates::due("daily",100000,186400,true));QVERIFY(!ut::Updates::due("weekly",100000,186400,true));
    }
    void pluginArchiveSizeBoundaries(){
        QVERIFY(ut::Plugins::archiveSizeError(14515433,14515433,true).isEmpty());
        QVERIFY(!ut::Plugins::archiveSizeError(14515433,14515432,true).isEmpty());
        QVERIFY(!ut::Plugins::archiveSizeError(14515433,14515434,false).isEmpty());
        QVERIFY(ut::Plugins::archiveSizeError(0,100,true).isEmpty());
        QVERIFY(!ut::Plugins::archiveSizeError(0,0,true).isEmpty());
        QVERIFY(!ut::Plugins::archiveSizeError(0,512ll*1024*1024+1,false).isEmpty());
        QVERIFY(!ut::Plugins::archiveSizeError(-1,0,false).isEmpty());
    }
    void parameterInputsSurviveSelection(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());
        scripts.newDraft("${name:first} ${mode:开=1|关=0}","cmd");scripts.updateDraft("title","first");QVERIFY(scripts.saveDraft());const auto first=scripts.selected()["id"].toString();
        scripts.setParameterValue("name","中文 input");scripts.setParameterValue("mode","0");const auto snapshot=scripts.parameterValues();
        scripts.newDraft("${name:second}","cmd");scripts.updateDraft("title","second");QVERIFY(scripts.saveDraft());const auto second=scripts.selected()["id"].toString();
        QCOMPARE(scripts.parameterValues()["name"].toString(),QString("second"));scripts.setParameterValue("name","");
        scripts.select(first);QCOMPARE(scripts.parameterValues(),snapshot);scripts.toggleFavorite(first);QCOMPARE(scripts.parameterValues(),snapshot);
        scripts.setParameterDefault("name","changed");QCOMPARE(scripts.parameterValues()["name"].toString(),QString("中文 input"));
        scripts.resetParameterValues();QCOMPARE(scripts.parameterValues()["name"].toString(),QString("changed"));QCOMPARE(snapshot["name"].toString(),QString("中文 input"));
        scripts.select(second);QCOMPARE(scripts.parameterValues()["name"].toString(),QString());
        QString error;ut::Parameters::render(scripts.selected()["code"].toString(),scripts.parameterValues(),&error);QVERIFY(!error.isEmpty());
        ut::Scripts restarted(tmp.path());restarted.select(first);QCOMPARE(restarted.parameterValues()["name"].toString(),QString("changed"));
    }
    void parameterFileDrop(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());scripts.newDraft("${文件@file} ${name:old}","cmd");scripts.updateDraft("title","file drop");QVERIFY(scripts.saveDraft());
        const auto id=scripts.selected()["id"].toString();const auto source=scripts.selected()["code"];
        const auto url=QUrl::fromLocalFile(QStringLiteral("C:/中文 folder/100% # file.txt"));
        QVERIFY(scripts.dropParameterFile(QStringLiteral("文件"),{url}));
        const auto values=scripts.parameterValues();QCOMPARE(values[QStringLiteral("文件")].toString(),QStringLiteral("C:\\中文 folder\\100% # file.txt"));
        QVERIFY(!scripts.dropParameterFile("name",{url}));QVERIFY(!scripts.dropParameterFile(QStringLiteral("文件"),{}));
        QVERIFY(!scripts.dropParameterFile(QStringLiteral("文件"),{url,url}));QVERIFY(!scripts.dropParameterFile(QStringLiteral("文件"),{QUrl("https://example.com/test")}));
        QVERIFY(!scripts.dropParameterFile(QStringLiteral("文件"),{QUrl::fromLocalFile("C:/bad\npath")}));QCOMPARE(scripts.parameterValues(),values);
        scripts.toggleFavorite(id);QCOMPARE(scripts.parameterValues(),values);QCOMPARE(scripts.selected()["code"],source);
    }
    void choiceValuesAreValidated(){
        QString error;const auto source=QStringLiteral("Var mode = ${模式:开启=on|关闭=off}\n${mode}");
        QCOMPARE(ut::Parameters::render(source,{{"mode","off"}},&error),QString("off"));QVERIFY(error.isEmpty());
        QVERIFY(ut::Parameters::render(source,{{"mode","invalid"}},&error).isEmpty());QVERIFY(error.contains(QStringLiteral("有效选项")));
        QCOMPARE(ut::Parameters::render(source,{},&error),QString("on"));QVERIFY(error.isEmpty());
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());scripts.newDraft(source,"cmd");scripts.updateDraft("title","choices");QVERIFY(scripts.saveDraft());
        scripts.setParameterValue("mode","off");QSignalSpy errors(&scripts,&ut::Scripts::error);
        scripts.setParameterValue("mode","invalid");QCOMPARE(errors.size(),1);QCOMPARE(scripts.parameterValues()["mode"].toString(),QString("off"));
    }
    void scriptEnvironmentPersistence(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());scripts.newDraft("echo test","cmd");scripts.updateDraft("title","environment");
        QVERIFY(scripts.setDraftEnvironment("SERVICE_VALUE","中文\nline=2"));QVERIFY(!scripts.setDraftEnvironment("service_value","duplicate"));QVERIFY(!scripts.setDraftEnvironment("PYTHONHOME","bad"));
        scripts.updateDraft("outputDirectory","results");QVERIFY(scripts.saveDraft());
        ut::Scripts restored(tmp.path());QCOMPARE(restored.selected()["env"].toMap()["SERVICE_VALUE"].toString(),QString("中文\nline=2"));QCOMPARE(restored.selected()["outputDirectory"].toString(),QString("results"));
        const QString legacy=R"({"id":"custom.legacy-env","title":"legacy","executor":{"kind":"batch","command":"echo test","env":{"LEGACY_VALUE":"retained"}}})";
        QCOMPARE(restored.importText(legacy)["status"].toString(),QString("ok"));QCOMPARE(restored.selected()["env"].toMap()["LEGACY_VALUE"].toString(),QString("retained"));
    }
    void declarationDefaultUpdates(){
        const QString source = "Var VIN = ${车架号:old}\r\nprint('${VIN}')\r\n${车架号:independent}";
        auto updated = ut::Parameters::withDefault(source, "VIN", "new");
        QCOMPARE(updated, QString("Var VIN = ${车架号:new}\r\nprint('${VIN}')\r\n${车架号:independent}"));
        QString error;
        QCOMPARE(ut::Parameters::render(updated, {}, &error), QString("print('new')\r\nindependent"));
        QVERIFY(error.isEmpty());
        updated = ut::Parameters::withDefault(source, "车架号", "other");
        QVERIFY(updated.startsWith("Var VIN = ${车架号:old}"));
        QVERIFY(updated.endsWith("${车架号:other}"));
        const QString file = "pVal input = ${文件@file:C:/old}\n${input}";
        updated = ut::Parameters::withDefault(file, "input", "C:/中文 dir/a.txt");
        QCOMPARE(ut::Parameters::parse(updated).parameters.first().toObject()["kind"].toString(), QString("file"));
        QCOMPARE(ut::Parameters::render(updated, {}, &error), QString("C:/中文 dir/a.txt"));
        const QString choice = "Var mode = ${模式:开=1|关=0}\n${mode}";
        auto changedChoice=ut::Parameters::withDefault(choice,"mode","0");
        QCOMPARE(changedChoice,QString("Var mode = ${模式:关=0|开=1}\n${mode}"));
        QCOMPARE(ut::Parameters::render(changedChoice,{},&error),QString("0"));
        QCOMPARE(ut::Parameters::withDefault(choice,"mode","invalid"),choice);
    }
    void defaultSavePreservesDraft(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());scripts.newDraft("${模式:开=1|关=0}","cmd");scripts.updateDraft("title","options");QVERIFY(scripts.saveDraft());
        scripts.newDraft("unsaved code","python");scripts.updateDraft("title","unsaved draft");const auto draft=scripts.draft();
        scripts.setParameterDefault("模式","0");QCOMPARE(scripts.draft(),draft);QCOMPARE(scripts.parameterValues()["模式"].toString(),QString("0"));
        ut::Scripts restored(tmp.path());QCOMPARE(restored.parameterValues()["模式"].toString(),QString("0"));QCOMPARE(restored.draft(),draft);
        const auto before=scripts.selected();QSignalSpy errors(&scripts,&ut::Scripts::error);scripts.setParameterDefault("模式","not an option");QCOMPARE(errors.size(),1);QCOMPARE(scripts.selected(),before);
    }
    void duplicateChoice(){QVERIFY(!ut::Parameters::parse("${mode:开=1|开=2}").error.isEmpty());}
    void attachmentDirectories(){
        QTemporaryDir temporary;QVERIFY(temporary.isValid());
        QJsonObject script{{"language","python"},{"bundleEntryPoint","main.py"},{"bundledFiles",QJsonObject{{"data/file.txt","eA=="}}},{"bundledDirectories",QJsonArray{"cache/empty","data"}}};
        QString error;QVERIFY2(ut::materializeScriptFiles(script,temporary.path()+"/valid",&error),qPrintable(error));
        QVERIFY(QFileInfo(temporary.path()+"/valid/cache/empty").isDir());
        QVERIFY(QDir(temporary.path()+"/valid/cache/empty").isEmpty());
        QVERIFY(QFileInfo(temporary.path()+"/valid/data/file.txt").isFile());
        const QList<QJsonValue> invalid={QString("cache"),QJsonArray{4},QJsonArray{"../outside"},QJsonArray{"cache","CACHE"},QJsonArray{"main.py"},QJsonArray{"data/file.txt/sub"},QJsonArray{"NUL"}};
        for(const auto &value:invalid){
            script["bundledDirectories"]=value;
            QVERIFY(!ut::materializeScriptFiles(script,temporary.path()+"/invalid",&error));
            QVERIFY(!error.isEmpty());QVERIFY(!QFileInfo::exists(temporary.path()+"/invalid"));
        }
        QJsonArray excessive;for(int index=0;index<1025;++index)excessive.append(QString::number(index));
        script["bundledDirectories"]=excessive;QVERIFY(!ut::scriptFilesError(script).isEmpty());
        script.remove("bundledDirectories");QVERIFY(ut::scriptFilesError(script).isEmpty());
    }
    void attachmentLanguageChange(){
        QTemporaryDir temporary;QVERIFY(temporary.isValid());ut::Scripts scripts(temporary.path());
        const QJsonObject attachment{{"asset.txt",QString::fromLatin1(QByteArray("asset").toBase64())}};
        QJsonObject item{{"id","bundle-language"},{"title","Bundle"},{"language","python"},{"code","print('hello')"},{"bundleEntryPoint","my.script.py"},{"bundledFiles",attachment}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(item).toJson()))["status"].toString(),QString("ok"));
        scripts.select("bundle-language");scripts.editSelected();scripts.updateDraft("language","cmd");scripts.updateDraft("code","echo hello");
        QVERIFY(scripts.saveDraft());
        ut::Scripts reloaded(temporary.path());reloaded.select("bundle-language");
        const auto shared=QJsonDocument::fromJson(reloaded.exportSelected().toUtf8()).object();
        // Export/import is the public persistence contract; a new consumer must accept it.
        ut::Scripts receiver(temporary.path()+"/receiver");
        QCOMPARE(receiver.importText(QString::fromUtf8(QJsonDocument(shared).toJson()))["status"].toString(),QString("ok"));
        const auto persisted=ut::readJson(temporary.path()+"/scripts/bundle-language/definition.json");
        QCOMPARE(persisted["bundleEntryPoint"].toString(),QString("my.script.cmd"));QCOMPARE(persisted["bundledFiles"].toObject(),attachment);
        item["id"]="bundle-collision";item["bundledFiles"]=QJsonObject{{"MY.SCRIPT.CMD",QString::fromLatin1(QByteArray("keep me").toBase64())}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(item).toJson()))["status"].toString(),QString("ok"));
        scripts.select("bundle-collision");scripts.editSelected();scripts.updateDraft("language","cmd");scripts.updateDraft("code","echo hello");
        QVERIFY(!scripts.saveDraft());
        QCOMPARE(ut::readJson(temporary.path()+"/scripts/bundle-collision/definition.json")["language"].toString(),QString("python"));
    }
    void collectionSourceFiles(){
        QTemporaryDir tmp;const auto collection=tmp.path()+"/collection";QVERIFY(QDir().mkpath(collection+"/tools"));QVERIFY(QDir().mkpath(collection+"/sources"));
        QFile source(collection+QStringLiteral("/sources/中文 script.py"));QVERIFY(source.open(QIODevice::WriteOnly));source.write("print('imported source')");source.close();
        auto entry=[](QString id,QString command){return QJsonObject{{"id",id},{"title",id},{"executor",QJsonObject{{"kind","python"},{"command",command}}}};};
        QVERIFY(ut::writeJson(collection+"/tools/good.json",entry("good",QStringLiteral("\"sources/中文 script.py\""))));
        QVERIFY(ut::writeJson(collection+"/tools/missing.json",entry("missing","sources/missing.py")));
        QVERIFY(ut::writeJson(collection+"/tools/inline.json",entry("inline","print('inline')")));
        auto withArgs=entry("with-args",QStringLiteral("\"sources/中文 script.py\" --name '中文 空格' \"\" C:\\path\\value"));
        auto executor=withArgs["executor"].toObject();executor["args"]=QJsonArray{"--tail"};withArgs["executor"]=executor;
        QVERIFY(ut::writeJson(collection+"/tools/args.json",withArgs));
        ut::Scripts scripts(tmp.path()+"/data");const auto report=scripts.importCollection(collection);
        QVERIFY2(scripts.count()==3,qPrintable(report));QCOMPARE(scripts.get("good")["code"].toString(),QString("print('imported source')"));QVERIFY(scripts.get("missing").isEmpty());QVERIFY(report.contains(QStringLiteral("源码文件不存在")));
        QCOMPARE(scripts.get("with-args")["arguments"].toArray(),(QJsonArray{"--name",QStringLiteral("中文 空格"),"","C:\\path\\value","--tail"}));
    }
    void legacyBooleanParameter(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());
        const QJsonArray metadata{QJsonObject{{"id","flag"},{"label","Flag"},{"kind","boolean"},{"required",true}}};
        const QJsonObject old{{"id","boolean"},{"title","boolean"},{"parameters",metadata},{"executor",QJsonObject{{"kind","python"},{"command","print(${flag})"},{"args",QJsonArray{"?flag:--enabled"}}}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()))["status"].toString(),QString("ok"));QCOMPARE(scripts.parameterValues()["flag"].metaType().id(),QMetaType::Bool);QVERIFY(!scripts.parameterValues()["flag"].toBool());
        QString error;QCOMPARE(ut::Parameters::render("${flag}",scripts.parameterValues(),&error,metadata),QString("False"));QVERIFY(error.isEmpty());QVERIFY(ut::Scripts::resolvedArgumentConditions(scripts.get("boolean"),scripts.parameterValues())["arguments"].toArray().isEmpty());
        scripts.setBooleanParameter("flag",true);QCOMPARE(ut::Parameters::render("${flag}",scripts.parameterValues(),&error,metadata),QString("True"));QVERIFY(error.isEmpty());QCOMPARE(ut::Scripts::resolvedArgumentConditions(scripts.get("boolean"),scripts.parameterValues())["arguments"].toArray(),QJsonArray{"--enabled"});
        scripts.setBooleanParameter("flag",false);QSignalSpy errors(&scripts,&ut::Scripts::error);scripts.setParameterValue("flag","false");QCOMPARE(errors.size(),1);QVERIFY(!scripts.parameterValues()["flag"].toBool());
        QVERIFY(ut::Parameters::parse("${flag:0}",metadata).parameters.first().toObject()["default"].toBool());
        ut::Parameters::render("${flag}",{{"flag","false"}},&error,metadata);QVERIFY(!error.isEmpty());
        scripts.editSelected();QVERIFY(scripts.saveDraft());ut::Scripts restored(tmp.path());restored.select("boolean");QCOMPARE(restored.parameterValues()["flag"].metaType().id(),QMetaType::Bool);QVERIFY(!restored.parameterValues()["flag"].toBool());
    }
    void legacyMultilineParameter(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());
        const QJsonArray metadata{QJsonObject{{"id","text"},{"label","Lines"},{"kind","multiline"},{"required",false}}};
        const QJsonObject old{{"id","multiline"},{"title","multiline"},{"parameters",metadata},{"executor",QJsonObject{{"kind","python"},{"command","print(repr('''${text}'''))"}}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()))["status"].toString(),QString("ok"));QCOMPARE(scripts.parameters().first().toMap()["kind"].toString(),QString("multiline"));
        const auto value=QStringLiteral("第一行\r\n\n  第二行\n");scripts.setParameterValue("text",value);const auto snapshot=scripts.parameterValues();
        scripts.newDraft("echo other","cmd");scripts.updateDraft("title","other");QVERIFY(scripts.saveDraft());scripts.select("multiline");QCOMPARE(scripts.parameterValues()["text"].toString(),value);
        QString error;QCOMPARE(ut::Parameters::render("${text}",snapshot,&error,metadata),value);QVERIFY(error.isEmpty());scripts.setParameterValue("text","changed");QCOMPARE(snapshot["text"].toString(),value);
        scripts.editSelected();QVERIFY(scripts.saveDraft());ut::Scripts restored(tmp.path());restored.select("multiline");QCOMPARE(restored.parameters().first().toMap()["kind"].toString(),QString("multiline"));QCOMPARE(restored.parameterValues()["text"].toString(),QString());
    }
    void legacyDirectoryParameter(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path()+"/data");
        const QJsonObject old{{"id","directory"},{"title","directory"},{"parameters",QJsonArray{QJsonObject{{"id","folder"},{"label","Folder"},{"kind","directory"},{"required",false}}}},{"executor",QJsonObject{{"kind","batch"},{"command","echo ${folder}"}}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()))["status"].toString(),QString("ok"));QCOMPARE(scripts.parameters().first().toMap()["kind"].toString(),QString("directory"));
        const auto folder=tmp.path()+QStringLiteral("/中文 空间");QVERIFY(QDir().mkpath(folder));QVERIFY(scripts.dropParameterFile("folder",{QUrl::fromLocalFile(folder)}));QCOMPARE(scripts.parameterValues()["folder"].toString(),QDir::toNativeSeparators(folder));
        QFile file(folder+"/file.txt");QVERIFY(file.open(QIODevice::WriteOnly));file.close();QVERIFY(!scripts.dropParameterFile("folder",{QUrl::fromLocalFile(file.fileName())}));QVERIFY(!scripts.dropParameterFile("folder",{QUrl::fromLocalFile(folder+"/missing")}));QCOMPARE(scripts.parameterValues()["folder"].toString(),QDir::toNativeSeparators(folder));
        scripts.setParameterDefault("folder",folder);ut::Scripts restored(tmp.path()+"/data");restored.select("directory");QCOMPARE(restored.parameters().first().toMap()["kind"].toString(),QString("directory"));QCOMPARE(restored.parameterValues()["folder"].toString(),folder);
    }
    void legacyNumericParameters(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());
        const QJsonArray metadata{QJsonObject{{"id","count"},{"kind","integer"},{"label","Count"},{"required",true}},QJsonObject{{"id","rate"},{"kind","number"},{"label","Rate"},{"required",false}}};
        const QJsonObject old{{"id","numeric"},{"title","numeric"},{"parameters",metadata},{"executor",QJsonObject{{"kind","batch"},{"command","echo ${count:000123} ${rate:1e-20}"}}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()))["status"].toString(),QString("ok"));
        QCOMPARE(scripts.parameters()[0].toMap()["kind"].toString(),QString("integer"));QCOMPARE(scripts.parameters()[1].toMap()["kind"].toString(),QString("number"));
        QString error;const auto large=QString("000123456789012345678901234567890");
        QCOMPARE(ut::Parameters::render("${count} ${rate}",{{"count",large},{"rate","-1.25e-300"}},&error,metadata),large+" -1.25e-300");QVERIFY(error.isEmpty());
        QCOMPARE(ut::Parameters::render("${count} ${rate}",{{"count","0"},{"rate",""}},&error,metadata),QString("0 "));QVERIFY(error.isEmpty());
        ut::Parameters::render("${count}",{{"count",""}},&error,metadata);QVERIFY(error.contains("Count"));
        // Match the old runner: numeric type tags do not coerce input text.
        QCOMPARE(ut::Parameters::render("${count}",{{"count","expression"}},&error,metadata),QString("expression"));QVERIFY(error.isEmpty());
        scripts.setParameterDefault("count",large);ut::Scripts restored(tmp.path());restored.select("numeric");QCOMPARE(restored.parameters()[0].toMap()["kind"].toString(),QString("integer"));QCOMPARE(restored.parameterValues()["count"].toString(),large);
        const auto choice=ut::Parameters::parse("${count:One=1|Two=2}",metadata);QVERIFY(choice.error.isEmpty());QCOMPARE(choice.parameters.first().toObject()["kind"].toString(),QString("choice"));
    }
    void legacyParameterMetadata(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());
        QJsonObject metadata{{"id","name"},{"label",QStringLiteral("显示名称")},{"kind","text"},{"required",false},{"default","stale"},{"placeholder",QStringLiteral("可以留空")}};
        QJsonObject old{{"id","metadata"},{"title","metadata"},{"executor",QJsonObject{{"kind","batch"},{"command","echo ${name}"}}},{"parameters",QJsonArray{metadata}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()))["status"].toString(),QString("ok"));
        auto p=scripts.parameters().first().toMap();QCOMPARE(p["label"].toString(),QStringLiteral("显示名称"));QVERIFY(!p["required"].toBool());QCOMPARE(p["default"].toString(),QString());QCOMPARE(p["placeholder"].toString(),QStringLiteral("可以留空"));
        QString error;QCOMPARE(ut::Parameters::render("echo ${name}",{},&error,QJsonArray{metadata}),QString("echo "));QVERIFY(error.isEmpty());
        metadata["required"]=true;ut::Parameters::render("echo ${name}",{},&error,QJsonArray{metadata});QVERIFY(error.contains(QStringLiteral("显示名称")));metadata["required"]=false;
        const auto declared=ut::Parameters::parse(QStringLiteral("Var name = ${模板名称:default}\necho ${name}"),QJsonArray{metadata});QVERIFY(declared.error.isEmpty());QCOMPARE(declared.parameters.first().toObject()["label"].toString(),QStringLiteral("模板名称"));
        scripts.editSelected();scripts.updateDraft("description","edited");QVERIFY(scripts.saveDraft());scripts.setParameterDefault("name","saved");
        ut::Scripts restored(tmp.path());restored.select("metadata");p=restored.parameters().first().toMap();QVERIFY(!p["required"].toBool());QCOMPARE(p["default"].toString(),QString("saved"));QCOMPARE(p["label"].toString(),QStringLiteral("显示名称"));
        ut::Scripts copied(tmp.path()+"/copy");QCOMPARE(copied.importText(restored.exportSelected())["status"].toString(),QString("ok"));QCOMPARE(copied.parameters(),restored.parameters());
        metadata["kind"]="android_device";old["id"]="unsupported";old["parameters"]=QJsonArray{metadata};const auto rejected=scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()));QCOMPARE(rejected["status"].toString(),QString("error"));QVERIFY(rejected["message"].toString().contains("android_device"));QVERIFY(scripts.get("unsupported").isEmpty());
        metadata["kind"]="text";QVERIFY(!ut::Parameters::parse("${name}",QJsonArray{metadata,metadata}).error.isEmpty());
    }
    void legacyExternalRequirements(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());
        QJsonObject executor{{"kind","powershell"},{"command","git status"},{"requirements",QJsonArray{"git","adb"}}};
        QJsonObject source{{"id","external-tools"},{"title","外部工具"},{"executor",executor}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(source).toJson()))["status"].toString(),QString("ok"));
        QCOMPARE(scripts.selected()["externalRequirements"].toList(),QVariantList({"git","adb"}));
        scripts.editSelected();scripts.updateDraft("title",QStringLiteral("修改标题"));QVERIFY(scripts.saveDraft());
        ut::Scripts restored(tmp.path());restored.select("external-tools");
        QCOMPARE(restored.selected()["externalRequirements"].toList(),QVariantList({"git","adb"}));
        ut::Scripts imported(tmp.path()+"/copy");QCOMPARE(imported.importText(restored.exportSelected())["status"].toString(),QString("ok"));
        QCOMPARE(imported.selected()["externalRequirements"].toList(),QVariantList({"git","adb"}));
        executor["requirements"]=QJsonArray{"android_device"};source["executor"]=executor;source["id"]="needs-device";
        const auto rejected=scripts.importText(QString::fromUtf8(QJsonDocument(source).toJson()));
        QCOMPARE(rejected["status"].toString(),QString("error"));QVERIFY(rejected["message"].toString().contains("android_device"));QVERIFY(scripts.get("needs-device").isEmpty());
        executor["requirements"]=QJsonArray{42};source["executor"]=executor;
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(source).toJson()))["status"].toString(),QString("error"));
    }
    void legacyConditionalArguments(){
        QJsonObject script{{"arguments",QJsonArray{"?flag:--with space","?missing:${unused}","literal","?flag:"}},{"legacyConditionalArguments",true}};
        QCOMPARE(ut::Scripts::resolvedArgumentConditions(script,{{"flag","0"}})["arguments"].toArray(),(QJsonArray{"--with space","literal",""}));
        QCOMPARE(ut::Scripts::resolvedArgumentConditions(script,{})["arguments"].toArray(),(QJsonArray{"literal"}));
        script.remove("legacyConditionalArguments");QCOMPARE(ut::Scripts::resolvedArgumentConditions(script,{}),script);
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());
        QJsonObject old{{"id","conditional"},{"title","conditional"},{"executor",QJsonObject{{"kind","python"},{"command","print('ok')"},{"args",QJsonArray{"?flag:--enabled"}}}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()))["status"].toString(),QString("ok"));
        QVERIFY(scripts.selected()["legacyConditionalArguments"].toBool());
        ut::Scripts restored(tmp.path());restored.select("conditional");QVERIFY(restored.selected()["legacyConditionalArguments"].toBool());
    }
    void repeatedParameterDefinitions(){
        const auto source=QStringLiteral("${mode}\n${mode:开=1|关=0}\n${mode}");
        const auto parsed=ut::Parameters::parse(source);QVERIFY(parsed.error.isEmpty());QCOMPARE(parsed.parameters.size(),1);
        QCOMPARE(parsed.parameters.first().toObject()["kind"].toString(),QString("choice"));
        QString error;QCOMPARE(ut::Parameters::render(source,{},&error),QString("1\n1\n1"));QVERIFY(error.isEmpty());
        QVERIFY(ut::Parameters::render(source,{{"mode","invalid"}},&error).isEmpty());QVERIFY(!error.isEmpty());
        QVERIFY(ut::Parameters::parse("${x:first} ${x:second}").error.contains(QStringLiteral("冲突")));
        QVERIFY(ut::Parameters::parse("${x@file} ${x:text}").error.contains(QStringLiteral("冲突")));
        QVERIFY(ut::Parameters::parse("Var x = ${名称:first}\npVal x = ${名称:second}\n${x}").error.contains(QStringLiteral("冲突")));
        const auto repeated=ut::Parameters::parse("${x:first} ${x:first} ${x}");QVERIFY(repeated.error.isEmpty());QCOMPARE(repeated.parameters.size(),1);
    }
    void legacyPythonArguments(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());
        const QString legacy=R"JSON({"id":"custom.argv","title":"argv","executor":{"kind":"python","command":"import sys\nprint(sys.argv[1:])","args":["--name","${名字:中文 空格}",""]}})JSON";
        QCOMPARE(scripts.importText(legacy)["status"].toString(),QString("ok"));QCOMPARE(scripts.parameters().size(),1);
        QCOMPARE(scripts.selected()["arguments"].toList().size(),3);scripts.setParameterDefault(QStringLiteral("名字"),QStringLiteral("新默认"));
        ut::Scripts restored(tmp.path());QCOMPARE(restored.parameterValues()[QStringLiteral("名字")].toString(),QStringLiteral("新默认"));
        QCOMPARE(restored.selected()["arguments"].toList()[1].toString(),QStringLiteral("${名字:新默认}"));
        restored.editSelected();restored.setDraftArgument(0,"changed");restored.removeDraftArgument(2);QVERIFY(restored.saveDraft());QCOMPARE(restored.selected()["arguments"].toList().size(),2);
        const auto exported=restored.exportSelected();QCOMPARE(restored.importText(exported,true)["status"].toString(),QString("ok"));
        QCOMPARE(restored.selected()["arguments"].toList()[0].toString(),QString("changed"));
        auto invalid=QJsonDocument::fromJson(legacy.toUtf8()).object();auto executor=invalid["executor"].toObject();executor["args"]=QJsonArray{12};invalid["executor"]=executor;
        QCOMPARE(restored.importText(QString::fromUtf8(QJsonDocument(invalid).toJson()),true)["status"].toString(),QString("error"));
    }
    void filteredCustomOrder(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());QStringList ids;
        for(const auto &language:QStringList{"cmd","python","cmd"}){
            scripts.newDraft("echo",language);scripts.updateDraft("title",language);QVERIFY(scripts.saveDraft());ids.append(scripts.selected()["id"].toString());
        }
        scripts.setSortMode("custom");scripts.setLanguageFilter("cmd");QCOMPARE(scripts.rowCount(),2);
        const auto revision=scripts.get(ids[2])["revision"];QVERIFY(scripts.move(ids[2],0));
        QCOMPARE(scripts.customOrder(),(QStringList{ids[2],ids[1],ids[0]}));QCOMPARE(scripts.get(ids[2])["revision"],revision);
        ut::Scripts restored(tmp.path());QCOMPARE(restored.customOrder(),scripts.customOrder());QCOMPARE(restored.sortMode(),QString("custom"));
        QVERIFY(!restored.move("missing",0));QVERIFY(!restored.move(ids[0],99));
    }
    void updateInstallationReceipt(){
        QTemporaryDir tmp;ut::Settings settings(tmp.path());ut::Plugins plugins(tmp.path(),tmp.path());
        const auto path=tmp.path()+"/updates/install-result.json";
        QVERIFY(ut::writeJson(path,{{"version","9.0.0"},{"state","failed"},{"message","SHA-256 failure"}}));
        ut::Updates failed(tmp.path(),&settings,&plugins);QVERIFY(failed.installationStatus().contains("SHA-256 failure"));
        QVERIFY(ut::writeJson(path,{{"version","9.0.0"},{"state","launched"}}));
        ut::Updates launched(tmp.path(),&settings,&plugins);QVERIFY(launched.installationStatus().contains("installer.log"));QVERIFY(!launched.installationStatus().contains(QStringLiteral("更新已完成")));
        QVERIFY(ut::writeJson(path,{{"version","9.0.0"},{"state","installed"},{"installerExitCode",0}}));
        ut::Updates installed(tmp.path(),&settings,&plugins);QVERIFY(installed.installationStatus().contains(QStringLiteral("安装器已成功结束")));QVERIFY(!installed.installationStatus().contains(QStringLiteral("更新已完成")));
        QVERIFY(ut::writeJson(path,{{"version",failed.currentVersion()},{"state","launched"}}));
        ut::Updates complete(tmp.path(),&settings,&plugins);QVERIFY(complete.installationStatus().contains(QStringLiteral("更新已完成")));
    }
    void failedBackupPreservesScript(){
        QTemporaryDir temporary;QVERIFY(temporary.isValid());ut::Scripts scripts(temporary.path());
        scripts.newDraft("echo original","cmd");scripts.updateDraft("title","Original");QVERIFY(scripts.saveDraft());
        const auto original=scripts.selected();const auto directory=temporary.path()+"/scripts/"+original["id"].toString();
        auto read=[](const QString &path){QFile file(path);return file.open(QIODevice::ReadOnly)?file.readAll():QByteArray();};
        const auto definition=read(directory+"/definition.json");QVERIFY(!definition.isEmpty());
        const auto files=QDir(directory).entryList(QDir::Files);
        QFile obstruction(temporary.path()+"/backups");QVERIFY(obstruction.open(QIODevice::WriteOnly));QVERIFY(obstruction.write("occupied")>0);obstruction.close();
        scripts.editSelected();scripts.updateDraft("code","echo edited");QSignalSpy errors(&scripts,&ut::Scripts::error);
        QVERIFY(!scripts.saveDraft());QVERIFY(!errors.isEmpty());QVERIFY(errors.last().first().toString().contains(QStringLiteral("备份")));
        QCOMPARE(read(directory+"/definition.json"),definition);QCOMPARE(QDir(directory).entryList(QDir::Files),files);
        QCOMPARE(scripts.draft()["code"].toString(),QString("echo edited"));
        auto replacement=QJsonObject::fromVariantMap(original);replacement["code"]="echo imported";
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(replacement).toJson()),true)["status"].toString(),QString("error"));
        QCOMPARE(read(directory+"/definition.json"),definition);QCOMPARE(QDir(directory).entryList(QDir::Files),files);
        ut::Scripts reloaded(temporary.path());QCOMPARE(reloaded.selected()["code"].toString(),QString("echo original"));
        QVERIFY(QFile::remove(temporary.path()+"/backups"));QVERIFY(scripts.saveDraft());
        const QDir backupDirectory(temporary.path()+"/backups");const auto backups=backupDirectory.entryList(QDir::Files);QCOMPARE(backups.size(),1);
        QCOMPARE(read(backupDirectory.filePath(backups.first())),definition);
        const auto savedBackup=ut::readJson(backupDirectory.filePath(backups.first()));
        QCOMPARE(read(directory+"/"+savedBackup["sourcePath"].toString()),QByteArray("echo original"));
        ut::Scripts finalState(temporary.path());QCOMPARE(finalState.selected()["code"].toString(),QString("echo edited"));
    }
    void scriptsRoundTrip(){
        QTemporaryDir tmp;ut::Scripts scripts(tmp.path());
        scripts.newDraft("print('${名字:用户}')","python");scripts.updateDraft("title","测试脚本");QVERIFY(scripts.saveDraft());QCOMPARE(scripts.count(),1);
        auto exported=scripts.exportSelected();auto id=scripts.selected()["id"].toString();
        ut::Scripts restored(tmp.path());QCOMPARE(restored.selected()["code"].toString(),QString("print('${名字:用户}')"));
        QCOMPARE(restored.importText(exported)["status"].toString(),QString("duplicate"));
        restored.setRunning(id,true);QVERIFY(!restored.deleteSelected());restored.setRunning(id,false);QVERIFY(restored.deleteSelected());
        QCOMPARE(restored.count(),0);QCOMPARE(restored.importText(exported)["status"].toString(),QString("ok"));
    }
    void settingsPersist(){QTemporaryDir tmp;ut::Settings settings(tmp.path());settings.setConcurrency(12);settings.setThemeMode("dark");settings.setTerminalScheme("light");ut::Settings restored(tmp.path());QCOMPARE(restored.concurrency(),5);QCOMPARE(restored.themeMode(),QString("dark"));QCOMPARE(restored.terminalScheme(),QString("light"));QCOMPARE(restored.terminalBackground(),QColor("#fafafa"));restored.setTerminalScheme("invalid");QCOMPARE(restored.terminalScheme(),QString("light"));}
};
QTEST_GUILESS_MAIN(CoreTests)
#include "core_tests.moc"
