#include "plugins.h"
#include "infrastructure/processrunner.h"
#include "infrastructure/storage.h"
#include <QCoreApplication>
#include <QDir>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QTimer>
#include <QVersionNumber>
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>

namespace ut {
namespace {
std::shared_ptr<void> environmentWriteLock(const QString &directory,const QString &version){
    const auto root=directory+"/plugins/python/.locks";if(!QDir().mkpath(root))return {};
    const auto path=root+"/"+version+"-x64.lock";
    HANDLE handle=CreateFileW(reinterpret_cast<LPCWSTR>(path.utf16()),GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(handle==INVALID_HANDLE_VALUE)return {};
    OVERLAPPED overlapped{};
    if(!LockFileEx(handle,LOCKFILE_EXCLUSIVE_LOCK|LOCKFILE_FAIL_IMMEDIATELY,0,1,0,&overlapped)){CloseHandle(handle);return {};}
    return std::shared_ptr<void>(handle,[](void *value){CloseHandle(value);});
}
}
namespace {bool validVersion(const QString&v){static QRegularExpression re("^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[A-Za-z0-9.]+)?$");return re.match(v).hasMatch();}}
Plugins::Plugins(QString directory,QString resources,QObject*parent,QNetworkAccessManager *network):QObject(parent),m_directory(std::move(directory)),m_resources(std::move(resources)),m_network(network?network:new QNetworkAccessManager(this)){
    m_active=readJson(m_directory+"/plugins/active.json");
    auto cached=readJson(m_directory+"/plugins/catalog-cache.json");
    m_catalog=readJson(m_resources+"/plugin-catalog.json")["packages"].toArray();
    QSet<QString> urls;for(const auto &entry:m_catalog)urls.insert(entry.toObject()["url"].toString());
    for(const auto &entry:cached["packages"].toArray())if(!urls.contains(entry.toObject()["url"].toString()))m_catalog.append(entry);
}
Plugins::~Plugins(){
    if(m_catalogReply){disconnect(m_catalogReply,nullptr,this,nullptr);m_catalogReply->abort();m_catalogReply->deleteLater();}
    cancel();if(m_process){disconnect(m_process,nullptr,this,nullptr);delete m_process.data();}
}
QString Plugins::versionDirectory(const QString&kind,const QString&v)const{return m_directory+"/plugins/"+kind+"/"+v+"-x64";}
QString Plugins::executable(const QString&kind,const QString&version)const{
    auto v=version.isEmpty()?m_active[kind].toString():version;
    if(v.isEmpty())return {};return versionDirectory(kind,v)+"/runtime/"+(kind=="python"?"python.exe":"pwsh.exe");
}
QString Plugins::environmentPath(const QString&version)const{auto v=version.isEmpty()?pythonVersion():version;return v.isEmpty()?QString():versionDirectory("python",v)+"/env";}
bool Plugins::ready(const QString&kind,const QString&v)const{
    if(v.isEmpty()||!validVersion(v))return false;
    if(QFileInfo::exists(versionDirectory(kind,v)+"/installing.json"))return false;
    auto meta=readJson(versionDirectory(kind,v)+"/installed.json");
    return meta["version"].toString()==v&&meta["kind"].toString()==kind&&QFile::exists(executable(kind,v))&&(kind!="python"||QFile::exists(environmentPath(v)+"/Scripts/python.exe"));
}
bool Plugins::pythonReady()const{return ready("python",pythonVersion());}
bool Plugins::powerShellReady()const{return ready("powershell",powerShellVersion());}
QVariantList Plugins::versions(const QString&kind)const{
    QVariantList result;QSet<QString> seen;
    for(const auto&value:m_catalog){auto p=value.toObject();if(p["kind"].toString()!=kind||p["architecture"].toString()!="x64")continue;auto v=p["version"].toString();if(seen.contains(v))continue;seen.insert(v);result.append(QVariantMap{{"version",v},{"installed",ready(kind,v)},{"active",m_active[kind].toString()==v}});}
    QDir installed(m_directory+"/plugins/"+kind);
    for(const auto&name:installed.entryList(QDir::Dirs|QDir::NoDotAndDotDot)){auto v=name;v.chop(4);if(!seen.contains(v)&&ready(kind,v))result.append(QVariantMap{{"version",v},{"installed",true},{"active",m_active[kind].toString()==v}});}
    std::sort(result.begin(),result.end(),[](const QVariant&a,const QVariant&b){return QVersionNumber::fromString(a.toMap()["version"].toString())>QVersionNumber::fromString(b.toMap()["version"].toString());});return result;
}
QVariantList Plugins::pythonVersions()const{return versions("python");}
QVariantList Plugins::powerShellVersions()const{return versions("powershell");}
QProcessEnvironment Plugins::environment(const QString &version)const{
    auto env=QProcessEnvironment::systemEnvironment();
    for(const auto&key:env.keys())if(key.startsWith("PYTHON",Qt::CaseInsensitive)||key.startsWith("UTERMINAL_PYTHON",Qt::CaseInsensitive)||key.compare("UTERMINAL_PIP",Qt::CaseInsensitive)==0||key.compare("VIRTUAL_ENV",Qt::CaseInsensitive)==0)env.remove(key);
    env.insert("PYTHONNOUSERSITE","1");env.insert("PYTHONUTF8","1");env.insert("PYTHONIOENCODING","utf-8");env.insert("PYTHONUNBUFFERED","1");
    auto v=version.isEmpty()?pythonVersion():version;
    if(ready("python",v)){
        auto ep=environmentPath(v);env.insert("UTERMINAL_PYTHON",executable("python",v));env.insert("UTERMINAL_PIP",ep+"/Scripts/python.exe");
        env.insert("VIRTUAL_ENV",ep);env.insert("UTERMINAL_PYTHON_SITE_PACKAGES",ep+"/Lib/site-packages");env.insert("PYTHONPATH",m_resources+"/plugin-bootstrap");
        env.insert("PATH",ep+"/Scripts;"+QFileInfo(executable("python",v)).absolutePath()+";"+env.value("PATH"));
    }else{env.remove("UTERMINAL_PYTHON");env.remove("UTERMINAL_PIP");}
    return env;
}
void Plugins::install(const QString&kind,const QString&version){
    if(m_busy)return;if((kind!="python"&&kind!="powershell")||!validVersion(version)){emit error(QStringLiteral("插件版本无效"));return;}
    if(ready(kind,version)){activate(kind,version);return;}
    if(inUse(kind,version)){emit error(QStringLiteral("该插件正在使用，无法修复"));return;}
    m_package={};for(const auto&p:m_catalog){auto entry=p.toObject();if(entry["kind"]==kind&&entry["version"]==version&&entry["architecture"]=="x64")m_package=entry;}
    QUrl url(m_package["url"].toString());auto digest=m_package["sha256"].toString();
    static const QRegularExpression sha256("^[0-9a-fA-F]{64}$");
    if(!url.isValid()||url.scheme()!="https"||!sha256.match(digest).hasMatch()){emit error(QStringLiteral("没有经过校验的插件包"));return;}
    m_expectedSize=m_package["size"].toInteger();m_received=0;m_downloadError.clear();
    const auto sizeProblem=archiveSizeError(m_expectedSize,0,false);if(!sizeProblem.isEmpty()){emit error(sizeProblem);return;}
    if(kind=="python"){
        m_environmentWriteLock=environmentWriteLock(m_directory,version);
        if(!m_environmentWriteLock){emit error(QStringLiteral("该 Python 环境正在被其他进程使用，无法安装或修复"));return;}
    }
    m_kind=kind;m_version=version;m_busy=true;m_cancelled=false;m_progress=0;m_status=QStringLiteral("正在下载插件…");
    QDir().mkpath(m_directory+"/staging");m_archive=m_directory+"/staging/"+kind+"-"+version+".zip";
    m_file=std::make_unique<QFile>(m_archive);if(!m_file->open(QIODevice::WriteOnly)){fail(m_file->errorString());return;}
    m_hash=std::make_unique<QCryptographicHash>(QCryptographicHash::Sha256);
    QNetworkRequest request(url);request.setTransferTimeout(60000);request.setRawHeader("User-Agent","UTerminal/0.1");m_download=m_network->get(request);
    m_download->setReadBufferSize(256*1024);
    connect(m_download,&QNetworkReply::readyRead,this,&Plugins::consumeDownload);
    connect(m_download,&QNetworkReply::downloadProgress,this,[this](qint64 n,qint64 total){m_progress=total>0?int(n*80/total):0;emit changed();});
    connect(m_download,&QNetworkReply::finished,this,[this]{auto*r=m_download.data();if(!r)return;
        if(r->error()==QNetworkReply::NoError)consumeDownload();
        m_download=nullptr;auto error=r->error();auto message=r->errorString();r->deleteLater();if(m_file){if(!m_file->flush()&&m_downloadError.isEmpty())m_downloadError=m_file->errorString();m_file->close();m_file.reset();}
        if(!m_downloadError.isEmpty()){fail(m_downloadError);return;}
        if(m_cancelled){fail(QStringLiteral("安装已取消"));return;}if(error!=QNetworkReply::NoError){fail(message);return;}
        const auto problem=archiveSizeError(m_expectedSize,m_received,true);if(!problem.isEmpty()){fail(problem);return;}
        if(QString::fromLatin1(m_hash->result().toHex())!=m_package["sha256"].toString().toLower()){fail(QStringLiteral("插件 SHA-256 校验失败"));return;}unpack();});emit changed();
}
QString Plugins::archiveSizeError(qint64 expected,qint64 received,bool complete){
    constexpr qint64 limit=512ll*1024*1024;
    if(expected<0||expected>limit)return QStringLiteral("插件包声明大小超出支持范围");
    if(received<0||received>limit||(expected>0&&received>expected))return QStringLiteral("插件下载超过预期大小");
    if(complete&&(received==0||(expected>0&&received!=expected)))return QStringLiteral("插件下载不完整，大小与版本目录不一致");
    return {};
}
void Plugins::consumeDownload(){
    if(!m_file||!m_download||!m_downloadError.isEmpty())return;
    while(m_download->bytesAvailable()>0){
        const auto bytes=m_download->read(64*1024);if(bytes.isEmpty())break;
        m_downloadError=archiveSizeError(m_expectedSize,m_received+bytes.size(),false);
        if(!m_downloadError.isEmpty()){m_download->abort();return;}
        if(m_file->write(bytes)!=bytes.size()){m_downloadError=QStringLiteral("写入插件包失败：")+m_file->errorString();m_download->abort();return;}
        m_received+=bytes.size();m_hash->addData(bytes);
    }
}
void Plugins::runStep(const QString&program,const QStringList&args,std::function<void()>next){
    if(m_cancelled){fail(QStringLiteral("安装已取消"));return;}
    auto*p=new ProcessRunner(this);m_process=p;
    auto clean=QProcessEnvironment::systemEnvironment();
    for(const auto &key:clean.keys())if(key.startsWith("PYTHON",Qt::CaseInsensitive)||key.startsWith("UTERMINAL_PYTHON",Qt::CaseInsensitive)||key.compare("UTERMINAL_PIP",Qt::CaseInsensitive)==0||key.compare("VIRTUAL_ENV",Qt::CaseInsensitive)==0)clean.remove(key);
    clean.insert("PYTHONNOUSERSITE","1");clean.insert("PYTHONUTF8","1");
    auto output=std::make_shared<QByteArray>();connect(p,&ProcessRunner::output,this,[output](const QByteArray &bytes){output->append(bytes);if(output->size()>65536)output->remove(0,output->size()-65536);});
    connect(p,&ProcessRunner::finished,this,[this,p,next,output](int code,const QString &reason){m_process=nullptr;p->deleteLater();if(m_cancelled){fail(QStringLiteral("安装已取消"));return;}if(code||!reason.isEmpty()){fail(reason.isEmpty()?QString::fromUtf8(*output):reason+"\n"+QString::fromUtf8(*output));return;}next();});
    p->start(program,args,m_directory,clean,0);
}
void Plugins::unpack(){
    // A repaired version may still have its old completion record. Persist
    // the incomplete state before touching runtime files so a crash cannot
    // make partially extracted files appear ready on the next launch.
    QString problem;
    if(!writeJson(versionDirectory(m_kind,m_version)+"/installing.json",
        {{"kind",m_kind},{"version",m_version},{"sha256",m_package["sha256"]}},&problem)){fail(problem);return;}
    m_progress=82;m_status=QStringLiteral("正在解压到插件目录…");emit changed();
    auto target=versionDirectory(m_kind,m_version)+"/runtime";
    QStringList args{"-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",resourcePath("install-archive.ps1"),"-Archive",m_archive,"-Destination",target};
    if(!m_package["prefix"].toString().isEmpty())args<<"-Prefix"<<m_package["prefix"].toString();
    runStep(qEnvironmentVariable("SystemRoot")+"/System32/WindowsPowerShell/v1.0/powershell.exe",args,[this]{prepare();});
}
void Plugins::prepare(){
    m_progress=90;m_status=QStringLiteral("正在准备运行环境…");emit changed();
    if(m_kind=="python")runStep(executable(m_kind,m_version),{"-m","venv",environmentPath(m_version)},[this]{validate();});else validate();
}
void Plugins::validate(){
    m_progress=96;m_status=QStringLiteral("正在验证插件…");emit changed();
    if(m_kind=="python")runStep(environmentPath(m_version)+"/Scripts/python.exe",{"-m","pip","--version"},[this]{complete();});
    else {
        auto profile=resourcePath("terminal-profile.ps1");profile.replace("'","''");
        auto command="if ($PSVersionTable.PSVersion.ToString() -ne '"+m_version+"') { exit 1 }; . '"+profile+"'; if (!(Get-Command python -CommandType Function -ErrorAction SilentlyContinue) -or !(Get-Command pip -CommandType Function -ErrorAction SilentlyContinue)) { exit 2 }";
        runStep(executable(m_kind,m_version),{"-NoProfile","-NonInteractive","-Command",command},[this]{complete();});
    }
}
void Plugins::complete(){
    if(m_cancelled){fail(QStringLiteral("安装已取消"));return;}
    QString problem;if(!writeJson(versionDirectory(m_kind,m_version)+"/installed.json",{{"kind",m_kind},{"version",m_version},{"sha256",m_package["sha256"]},{"archiveSize",m_received},{"architecture","x64"}},&problem)){fail(problem);return;}
    if(!QFile::remove(versionDirectory(m_kind,m_version)+"/installing.json")){fail(QStringLiteral("无法提交插件安装记录，请重新安装此版本"));return;}
    const bool awaitingSelection=m_kind=="powershell"&&powerShellReady()&&powerShellVersion()!=m_version;
    m_busy=false;m_environmentWriteLock.reset();m_progress=100;QFile::remove(m_archive);
    m_status=awaitingSelection?QStringLiteral("新版本已安装。点击“使用此版本”后，新会话将使用该版本。"):QStringLiteral("插件安装完成");
    if(!awaitingSelection)activate(m_kind,m_version);
    emit changed();emit installed(m_kind,m_version);
}
void Plugins::fail(const QString&message){m_busy=false;m_environmentWriteLock.reset();m_status=message;m_progress=0;if(m_file){m_file->close();m_file.reset();}QFile::remove(m_archive);emit changed();emit error(message);}
void Plugins::cancel(){if(!m_busy||m_cancelled)return;m_cancelled=true;m_status=QStringLiteral("正在取消安装…");emit changed();if(m_download)m_download->abort();if(m_process)m_process->stop();}
bool Plugins::activate(const QString&kind,const QString&version){
    if(!ready(kind,version)){emit error(QStringLiteral("该版本未安装或已损坏"));return false;}
    if(kind=="python"&&pythonReady()&&version!=pythonVersion()){emit pythonSwitchRequested(version);return false;}
    return commitActivation(kind,version);
}
bool Plugins::commitActivation(const QString&kind,const QString&version){if(!ready(kind,version))return false;auto next=m_active;next[kind]=version;QString problem;if(!writeJson(m_directory+"/plugins/active.json",next,&problem)){emit error(problem);return false;}m_active=next;emit changed();return true;}
void Plugins::acquire(const QString&kind,const QString&v){if(!v.isEmpty()){++m_leases[kind+":"+v];emit leasesChanged();}}
void Plugins::release(const QString&kind,const QString&v){auto key=kind+":"+v;m_leases[key]=qMax(0,m_leases.value(key)-1);emit leasesChanged();}
bool Plugins::reservePython(const QString &v){if(v.isEmpty()||m_pythonReservations.contains(v))return false;m_pythonReservations.insert(v);emit leasesChanged();return true;}
void Plugins::releasePythonReservation(const QString &v){m_pythonReservations.remove(v);emit leasesChanged();}
bool Plugins::pythonReserved(const QString &v)const{return m_pythonReservations.contains(v.isEmpty()?pythonVersion():v);}
bool Plugins::inUse(const QString&kind,const QString&v)const{return m_leases.value(kind+":"+v)>0;}
bool Plugins::removeVersion(const QString&kind,const QString&v){
    if(!validVersion(v)||(kind!="python"&&kind!="powershell")||m_busy||inUse(kind,v)||(kind=="python"&&pythonReserved(v))||m_active[kind].toString()==v){emit error(QStringLiteral("不能移除活动版本或正在使用的版本"));return false;}
    auto lock=kind=="python"?environmentWriteLock(m_directory,v):std::shared_ptr<void>();
    if(kind=="python"&&!lock){emit error(QStringLiteral("该 Python 环境正在被其他进程使用，无法移除"));return false;}
    bool ok=QDir(versionDirectory(kind,v)).removeRecursively();emit changed();return ok;
}
void Plugins::refreshCatalog(){
    if(m_catalogReply)return;
    QNetworkRequest request(QUrl("https://api.github.com/repos/PowerShell/PowerShell/releases?per_page=10"));request.setRawHeader("User-Agent","UTerminal/0.1");request.setTransferTimeout(30000);
    auto*r=m_network->get(request);m_catalogReply=r;m_catalogStatus=QStringLiteral("正在刷新插件版本…");emit changed();
    connect(r,&QNetworkReply::finished,this,[this,r]{r->deleteLater();m_catalogReply.clear();
        auto failed=[this](const QString &reason){m_catalogStatus=QStringLiteral("版本列表刷新失败：")+reason;emit changed();emit error(m_catalogStatus);};
        if(r->error()!=QNetworkReply::NoError){failed(r->errorString());return;}
        QJsonParseError parseError;const auto document=QJsonDocument::fromJson(r->readAll(),&parseError);
        if(parseError.error!=QJsonParseError::NoError||!document.isArray()){failed(QStringLiteral("服务器返回了无效的版本列表"));return;}
        const auto releases=document.array();QSet<QString>known;for(const auto&p:m_catalog)known.insert(p.toObject()["url"].toString());
        for(const auto&value:releases){auto rel=value.toObject();if(rel["prerelease"].toBool()||rel["draft"].toBool())continue;auto v=rel["tag_name"].toString();if(v.startsWith('v'))v.remove(0,1);if(!validVersion(v)||!v.startsWith("7."))continue;
            for(const auto&a:rel["assets"].toArray()){auto asset=a.toObject();if(asset["name"].toString()!="PowerShell-"+v+"-win-x64.zip")continue;auto hash=asset["digest"].toString();auto url=asset["browser_download_url"].toString();if(!hash.startsWith("sha256:")||hash.size()!=71||known.contains(url))continue;
                m_catalog.append(QJsonObject{{"kind","powershell"},{"version",v},{"architecture","x64"},{"url",url},{"sha256",hash.mid(7)},{"size",asset["size"]},{"prefix",""}});
            }}
        if(!writeJson(m_directory+"/plugins/catalog-cache.json",{{"packages",m_catalog}})){failed(QStringLiteral("无法保存版本列表缓存"));return;}
        m_catalogStatus=QStringLiteral("插件版本列表已更新");emit changed();});
}
}
