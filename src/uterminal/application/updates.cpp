#include "updates.h"
#include "plugins.h"
#include "presentation/settings.h"
#include "infrastructure/storage.h"
#include <QCoreApplication>
#include <QDateTime>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QVersionNumber>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QUuid>
#include <QLockFile>
#include <Windows.h>
#include <TlHelp32.h>
#include "infrastructure/updatepackage.h"

namespace ut {
namespace {
bool validVersion(const QString &value){
    static const QRegularExpression re("^(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?$");
    return re.match(value).hasMatch();
}
int compareVersion(const QString &a,const QString &b){
    const int core=QVersionNumber::compare(QVersionNumber::fromString(a),QVersionNumber::fromString(b));if(core)return core;
    const auto ap=a.section('-',1),bp=b.section('-',1);if(ap==bp)return 0;if(ap.isEmpty())return 1;if(bp.isEmpty())return -1;
    const auto aa=ap.split('.'),bb=bp.split('.');static const QRegularExpression numeric("^[0-9]+$");
    for(int i=0;i<qMin(aa.size(),bb.size());++i){
        if(aa[i]==bb[i])continue;bool an=numeric.match(aa[i]).hasMatch(),bn=numeric.match(bb[i]).hasMatch();
        if(an!=bn)return an?-1:1;
        if(an&&aa[i].size()!=bb[i].size())return aa[i].size()<bb[i].size()?-1:1;
        return QString::compare(aa[i],bb[i],Qt::CaseSensitive);
    }
    return aa.size()<bb.size()?-1:1;
}
}
Updates::Updates(QString directory,Settings *settings,Plugins *plugins,QObject *parent,QNetworkAccessManager *transport)
    :QObject(parent),m_directory(std::move(directory)),m_settings(settings),m_plugins(plugins),m_transport(transport?transport:&m_network){
    m_state=readJson(m_directory+"/update-state.json");
    cleanupHelperCache(m_directory+"/updates");
    readInstallationReceipt();
    m_ready=readJson(m_directory+"/updates/pending.json");
    if(!m_ready.isEmpty()&&(!verifyReady()||!validVersion(m_ready["version"].toString())||compareVersion(m_ready["version"].toString(),currentVersion())<=0))m_ready={};
    if(!m_ready.isEmpty())m_status=QStringLiteral("更新包已下载，可稍后或退出后安装");
    connect(settings,&Settings::changed,this,[this]{select();schedule();});
    m_timer.setInterval(60000);connect(&m_timer,&QTimer::timeout,this,&Updates::schedule);m_timer.start();
    QTimer::singleShot(0,this,&Updates::schedule);
}
QString Updates::currentVersion()const{return QCoreApplication::applicationVersion().isEmpty()?QStringLiteral(UTERMINAL_VERSION):QCoreApplication::applicationVersion();}
bool Updates::due(const QString &policy,qint64 last,qint64 now,bool startupUsed){
    if(policy=="manual")return false;if(policy=="startup")return !startupUsed;
    if(policy!="daily"&&policy!="weekly")return false;
    return last<=0||last>now||now-last>=(policy=="daily"?86400:604800);
}
void Updates::schedule(){
    const auto now=QDateTime::currentSecsSinceEpoch();
    if(!busy()&&due(m_settings->updatePolicy(),m_state["lastAttempt"].toInteger(),now,m_startupUsed))check();
    if(!m_plugins->busy()&&due(m_settings->pluginUpdatePolicy(),m_state["pluginAttempt"].toInteger(),now,true)){
        m_state["pluginAttempt"]=now;writeJson(m_directory+"/update-state.json",m_state);m_plugins->refreshCatalog();
    }
}
QJsonObject Updates::selectRelease(const QJsonArray &releases,const QString &current,bool prerelease){
    QJsonObject best;QString highest=current;if(!validVersion(current))return {};
    static const QRegularExpression assetName("^UTerminal-(.+)-win-x64-setup\\.exe$");
    static const QRegularExpression digest("^sha256:[0-9a-fA-F]{64}$");
    for(const auto &entry:releases){
        const auto release=entry.toObject();if(release["draft"].toBool()||(!prerelease&&release["prerelease"].toBool()))continue;
        auto tag=release["tag_name"].toString();if(tag.startsWith("uterminal-v"))tag.remove(0,11);else if(tag.startsWith('v'))tag.remove(0,1);
        if(!validVersion(tag)||(!prerelease&&tag.contains('-'))||compareVersion(tag,highest)<=0)continue;
        for(const auto &assetEntry:release["assets"].toArray()){
            const auto asset=assetEntry.toObject();const auto match=assetName.match(asset["name"].toString());const QUrl url(asset["browser_download_url"].toString());
            if(!match.hasMatch()||match.captured(1)!=tag||!digest.match(asset["digest"].toString()).hasMatch()||url.scheme()!="https"||url.host()!="github.com"||!url.path().startsWith("/popkter/PopToolProject/releases/download/"))continue;
            const qint64 size=asset["size"].toInteger();if(size<=0||size>512ll*1024*1024)continue;
            highest=tag;best={{"version",tag},{"url",url.toString()},{"sha256",asset["digest"].toString().mid(7).toLower()},{"size",size},{"notes",release["body"].toString().left(20000)},{"prerelease",release["prerelease"].toBool()||tag.contains('-')}};
        }
    }
    return best;
}
void Updates::select(){m_available=selectRelease(m_releases,currentVersion(),m_settings->prerelease());emit changed();}
void Updates::check(){
    if(busy())return;m_startupUsed=true;m_state["lastAttempt"]=QDateTime::currentSecsSinceEpoch();writeJson(m_directory+"/update-state.json",m_state);
    QNetworkRequest request(QUrl("https://api.github.com/repos/popkter/PopToolProject/releases?per_page=100"));
    request.setRawHeader("User-Agent","UTerminal/0.1");request.setTransferTimeout(30000);m_reply=m_transport->get(request);m_reply->setReadBufferSize(256*1024);
    m_status=QStringLiteral("正在检查应用更新…");emit changed();
    auto bytes=std::make_shared<QByteArray>();auto oversized=std::make_shared<bool>(false);
    connect(m_reply,&QNetworkReply::readyRead,this,[this,bytes,oversized]{if(!m_reply)return;bytes->append(m_reply->readAll());if(bytes->size()>4*1024*1024){*oversized=true;m_reply->abort();}});
    connect(m_reply,&QNetworkReply::finished,this,[this,bytes,oversized]{
        auto *reply=m_reply.data();m_reply=nullptr;if(!reply)return;reply->deleteLater();
        if(*oversized||reply->error()!=QNetworkReply::NoError){m_status=*oversized?QStringLiteral("更新响应超过大小限制"):QStringLiteral("更新检查失败：")+reply->errorString();emit changed();return;}
        bytes->append(reply->readAll());if(bytes->size()>4*1024*1024){m_status=QStringLiteral("更新响应超过大小限制");emit changed();return;}QJsonParseError error;auto document=QJsonDocument::fromJson(*bytes,&error);
        if(error.error!=QJsonParseError::NoError||!document.isArray()){m_status=QStringLiteral("更新服务返回了无效版本列表");emit changed();return;}
        m_releases=document.array();select();m_state["lastSuccess"]=QDateTime::currentSecsSinceEpoch();writeJson(m_directory+"/update-state.json",m_state);
        m_status=m_available.isEmpty()?QStringLiteral("没有可用的新版 UTerminal 安装包"):QStringLiteral("发现新版本：")+m_available["version"].toString();emit changed();
    });
}
QString Updates::readyPath()const{
    const auto file=m_ready["file"].toString();
    if(file.isEmpty()||QFileInfo(file).fileName()!=file||!file.endsWith(".exe"))return {};
    return m_directory+"/updates/"+file;
}
bool Updates::verifyReady()const{return verifyUpdatePackage(readyPath(),m_ready["size"].toInteger(),m_ready["sha256"].toString());}
void Updates::setInstallOnExit(bool enabled){
    if(enabled&&!verifyReady()){m_installOnExit=false;m_status=QStringLiteral("更新包已损坏或缺失，请重新下载");emit changed();return;}
    m_installOnExit=enabled;emit changed();
}
QString Updates::stageHelper(const QString &sourceDirectory,const QString &destination){
    if(QFileInfo::exists(destination)||!QDir().mkpath(destination))return {};
    QLockFile lease(destination+"/helper.lock");lease.setStaleLockTime(0);
    if(!lease.tryLock())return {};
    if(!writeJson(destination+"/helper-cache.json",{{"format",1},{"createdAt",QDateTime::currentSecsSinceEpoch()},{"creatorPid",QCoreApplication::applicationPid()}})){
        lease.unlock();QDir(destination).removeRecursively();return {};
    }
    const auto helper=destination+"/UTerminalUpdateRunner.exe";
    bool ok=QFile::copy(sourceDirectory+"/UTerminalUpdateRunner.exe",helper);bool core=false;
    const HANDLE snapshot=CreateToolhelp32Snapshot(TH32CS_SNAPMODULE|TH32CS_SNAPMODULE32,GetCurrentProcessId());
    if(snapshot==INVALID_HANDLE_VALUE)ok=false;
    else{
        MODULEENTRY32W entry{};entry.dwSize=sizeof(entry);
        if(Module32FirstW(snapshot,&entry))do{
            const auto name=QString::fromWCharArray(entry.szModule);const auto lower=name.toLower();
            const bool qtCore=lower=="qt6core.dll"||lower=="qt6cored.dll";
            const bool crt=lower.startsWith("msvcp140")||lower.startsWith("vcruntime140")||lower.startsWith("concrt140")||lower=="ucrtbased.dll";
            if(qtCore||crt){core|=qtCore;ok=QFile::copy(QString::fromWCharArray(entry.szExePath),destination+'/'+name)&&ok;}
        }while(Module32NextW(snapshot,&entry));
        CloseHandle(snapshot);
    }
    if(!ok||!core){lease.unlock();QDir(destination).removeRecursively();return {};}
    return helper;
}
int Updates::cleanupHelperCache(const QString &updatesDirectory){
    // Only direct, marked cache directories created by this version are eligible.
    // Unknown files and reparse points are preserved; this is not a general recursive cleanup.
    const auto plain=[](const QString &path){
        const DWORD attributes=GetFileAttributesW(reinterpret_cast<LPCWSTR>(path.utf16()));
        return attributes!=INVALID_FILE_ATTRIBUTES&&!(attributes&FILE_ATTRIBUTE_REPARSE_POINT);
    };
    if(!plain(updatesDirectory))return 0;
    static const QRegularExpression folder("^helper-[0-9a-f]{32}$");
    static const QRegularExpression binary("^(UTerminalUpdateRunner\\.exe|Qt6Core[d]?\\.dll|(?:msvcp140|vcruntime140|concrt140)[a-z0-9_]*\\.dll|ucrtbased\\.dll)$",QRegularExpression::CaseInsensitiveOption);
    int removed=0;const auto now=QDateTime::currentSecsSinceEpoch();
    const QDir root(updatesDirectory);
    for(const auto &entry:root.entryInfoList(QDir::Dirs|QDir::NoDotAndDotDot|QDir::Hidden|QDir::System)){
        const auto path=entry.absoluteFilePath();if(!folder.match(entry.fileName()).hasMatch()||!plain(path))continue;
        if(!plain(path+"/helper-cache.json"))continue;
        const auto marker=readJson(path+"/helper-cache.json");const auto created=marker["createdAt"].toInteger();
        const auto pid=marker["creatorPid"].toInteger();
        // Allow the detached process time to load and acquire its lease after the app exits.
        if(marker["format"].toInt()!=1||created<=0||created>now-3600||pid<=0||pid>MAXDWORD)continue;
        HANDLE creator=OpenProcess(SYNCHRONIZE,FALSE,DWORD(pid));
        if(creator){const auto state=WaitForSingleObject(creator,0);CloseHandle(creator);if(state!=WAIT_OBJECT_0)continue;}
        else if(GetLastError()!=ERROR_INVALID_PARAMETER)continue;
        const auto lockPath=path+"/helper.lock";
        if(QFileInfo::exists(lockPath)&&!plain(lockPath))continue;
        QLockFile lease(lockPath);lease.setStaleLockTime(0);if(!lease.tryLock())continue;
        const auto files=QDir(path).entryInfoList(QDir::AllEntries|QDir::NoDotAndDotDot|QDir::Hidden|QDir::System);
        bool owned=true;
        for(const auto &file:files){
            if(!file.isFile()||!plain(file.absoluteFilePath())||(file.fileName()!="helper-cache.json"&&file.fileName()!="helper.lock"&&!binary.match(file.fileName()).hasMatch())){owned=false;break;}
        }
        if(!owned)continue;
        bool ok=true;
        for(const auto &file:files){
            if(file.fileName()!="helper-cache.json"&&file.fileName()!="helper.lock")ok=QFile::remove(file.absoluteFilePath())&&ok;
        }
        // Keep the marker after partial removal so a later start can retry a locked file.
        if(ok)ok=QFile::remove(path+"/helper-cache.json");
        lease.unlock();
        if(ok&&root.rmdir(entry.fileName()))++removed;
    }
    return removed;
}
void Updates::launchInstallerAfterExit(){
    if(!m_installOnExit)return;
    const auto receiptPath=m_directory+"/updates/install-result.json";
    QJsonObject receipt{{"version",m_ready["version"]},{"state","requested"},{"updatedAt",QDateTime::currentSecsSinceEpoch()}};
    if(!verifyReady()){receipt["state"]="failed";receipt["message"]=QStringLiteral("退出时发现安装包已损坏或缺失，请重新下载");writeJson(receiptPath,receipt);return;}
    if(!writeJson(receiptPath,receipt)){qWarning("Unable to save UTerminal update receipt; installation not started");return;}
    const auto helper=stageHelper(QCoreApplication::applicationDirPath(),m_directory+"/updates/helper-"+QUuid::createUuid().toString(QUuid::Id128));
    if(helper.isEmpty()){receipt["state"]="failed";receipt["message"]=QStringLiteral("无法准备独立更新助手，未启动安装");writeJson(receiptPath,receipt);return;}
    if(!QProcess::startDetached(helper,{QString::number(QCoreApplication::applicationPid()),readyPath(),QString::number(m_ready["size"].toInteger()),m_ready["sha256"].toString(),receiptPath})){
        receipt["state"]="failed";receipt["message"]=QStringLiteral("无法启动更新助手，请重新安装应用或手动运行已下载的安装包");writeJson(receiptPath,receipt);
    }
}
void Updates::readInstallationReceipt(){
    const auto receipt=readJson(m_directory+"/updates/install-result.json");if(receipt.isEmpty())return;
    const auto version=receipt["version"].toString();const auto state=receipt["state"].toString();
    if(validVersion(version)&&compareVersion(currentVersion(),version)>=0)m_installationStatus=QStringLiteral("更新已完成，当前版本：")+currentVersion();
    else if(state=="failed")m_installationStatus=QStringLiteral("上次更新未能安装：")+receipt["message"].toString().left(500);
    else if(state=="installed")m_installationStatus=QStringLiteral("安装器已成功结束，但当前仍为 %1。请确认启动的是安装目录中的版本；目标版本：%2").arg(currentVersion(),version);
    else if(state=="launched")m_installationStatus=QStringLiteral("上次安装程序已启动，但当前仍为 %1。若安装未完成，请查看更新目录中的 installer.log。目标版本：%2").arg(currentVersion(),version);
    else m_installationStatus=QStringLiteral("上次更新尚未确认启动安装程序，可能仍在等待旧进程退出。请稍后重试或检查更新助手。");
}
void Updates::cancelDownload(){if(m_download){m_downloadCancelled=true;m_download->abort();}}
void Updates::download(){
    if(busy()||m_available.isEmpty())return;
    m_downloadPackage=m_available;m_downloadCancelled=false;m_downloadError.clear();m_received=0;m_progress=0;m_installOnExit=false;
    const auto directory=m_directory+"/updates";if(!QDir().mkpath(directory)){m_status=QStringLiteral("无法创建更新目录");emit changed();return;}
    m_downloadPath=directory+"/"+QUuid::createUuid().toString(QUuid::WithoutBraces)+".exe";
    m_file=std::make_unique<QSaveFile>(m_downloadPath);if(!m_file->open(QIODevice::WriteOnly)){m_status=m_file->errorString();m_file.reset();emit changed();return;}
    m_hash=std::make_unique<QCryptographicHash>(QCryptographicHash::Sha256);
    QNetworkRequest request(QUrl(m_downloadPackage["url"].toString()));request.setTransferTimeout(60000);request.setRawHeader("User-Agent","UTerminal/0.1");
    m_download=m_transport->get(request);m_download->setReadBufferSize(256*1024);m_status=QStringLiteral("正在下载应用更新…");emit changed();
    auto consume=[this]{
        if(!m_download||!m_file||!m_downloadError.isEmpty())return;
        while(m_download->bytesAvailable()>0){
            const auto bytes=m_download->read(64*1024);if(bytes.isEmpty())break;
            if(m_received+bytes.size()>m_downloadPackage["size"].toInteger()){m_downloadError=QStringLiteral("更新包超过声明大小");m_download->abort();return;}
            if(m_file->write(bytes)!=bytes.size()){m_downloadError=m_file->errorString();m_download->abort();return;}
            m_received+=bytes.size();m_hash->addData(bytes);
        }
        m_progress=int(m_received*100/m_downloadPackage["size"].toInteger());emit changed();
    };
    connect(m_download,&QNetworkReply::readyRead,this,consume);
    connect(m_download,&QNetworkReply::finished,this,[this,consume]{
        auto *reply=m_download.data();if(!reply)return;if(reply->error()==QNetworkReply::NoError)consume();m_download=nullptr;reply->deleteLater();
        QString problem=m_downloadError;
        if(m_downloadCancelled)problem=QStringLiteral("更新下载已取消");
        else if(problem.isEmpty()&&reply->error()!=QNetworkReply::NoError)problem=reply->errorString();
        if(problem.isEmpty()&&(m_received!=m_downloadPackage["size"].toInteger()||QString::fromLatin1(m_hash->result().toHex())!=m_downloadPackage["sha256"].toString()))problem=QStringLiteral("更新包大小或 SHA-256 校验失败");
        if(problem.isEmpty()&&!m_file->commit())problem=m_file->errorString();
        if(problem.isEmpty()){
            auto ready=m_downloadPackage;ready["file"]=QFileInfo(m_downloadPath).fileName();
            if(writeJson(m_directory+"/updates/pending.json",ready,&problem)){m_ready=ready;m_status=QStringLiteral("更新已下载并校验，可稍后安装或选择退出后安装");}
            else QFile::remove(m_downloadPath);
        }
        if(!problem.isEmpty())m_status=problem;
        m_file.reset();m_hash.reset();emit changed();
    });
}
}
