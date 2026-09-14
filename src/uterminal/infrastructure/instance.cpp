#include "instance.h"
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QLocalSocket>
#include <QElapsedTimer>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <windows.h>
#include <sddl.h>

namespace ut {
namespace {
struct Identity { QString user; DWORD session=0; bool elevated=false,valid=false; };
Identity identity(DWORD pid){
    Identity result;HANDLE process=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,FALSE,pid),token=nullptr;
    if(!process)return result;
    if(OpenProcessToken(process,TOKEN_QUERY,&token)){
        DWORD size=0;GetTokenInformation(token,TokenUser,nullptr,0,&size);
        QByteArray user(int(size),Qt::Uninitialized);TOKEN_ELEVATION elevation{};
        if(size&&GetTokenInformation(token,TokenUser,user.data(),size,&size)&&
           GetTokenInformation(token,TokenElevation,&elevation,sizeof(elevation),&size)&&ProcessIdToSessionId(pid,&result.session)){
            LPWSTR sid=nullptr;
            if(ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(user.data())->User.Sid,&sid)){
                result.user=QString::fromWCharArray(sid);LocalFree(sid);
                result.elevated=elevation.TokenIsElevated!=0;result.valid=true;
            }
        }
        CloseHandle(token);
    }
    CloseHandle(process);return result;
}
bool peer(QLocalSocket *socket,bool client,DWORD *peerPid=nullptr){
    ULONG pid=0;const auto pipe=reinterpret_cast<HANDLE>(socket->socketDescriptor());
    if(!(client?GetNamedPipeServerProcessId(pipe,&pid):GetNamedPipeClientProcessId(pipe,&pid)))return false;
    const auto own=identity(GetCurrentProcessId()),other=identity(pid);
    if(!own.valid||!other.valid||own.user!=other.user||own.session!=other.session||own.elevated!=other.elevated)return false;
    if(peerPid)*peerPid=pid;return true;
}
bool alive(qint64 pid){
    if(pid<=0||pid>MAXDWORD)return true;
    HANDLE process=OpenProcess(SYNCHRONIZE,FALSE,DWORD(pid));
    if(!process)return GetLastError()!=ERROR_INVALID_PARAMETER;
    const bool running=WaitForSingleObject(process,0)!=WAIT_OBJECT_0;CloseHandle(process);return running;
}
QByteArray wire(const QJsonObject &value){return QJsonDocument(value).toJson(QJsonDocument::Compact)+'\n';}
}
bool processElevated(){return identity(GetCurrentProcessId()).elevated;}
QString profileDirectory(const QString &base,bool elevated){return QDir::cleanPath(elevated?base+"/administrator":base);}
Instance::Instance(const QString &directory,QObject *parent):QObject(parent){
    QDir().mkpath(directory);const auto own=identity(GetCurrentProcessId());
    const QString canonical=QFileInfo(directory).canonicalFilePath();
    const auto key=own.user+'|'+QString::number(own.session)+'|'+QString::number(own.elevated)+'|'+canonical.toCaseFolded();
    m_name="UTerminal-"+QString::fromLatin1(QCryptographicHash::hash(key.toUtf8(),QCryptographicHash::Sha256).toHex());
    m_lock=std::make_unique<QLockFile>(directory+"/"+m_name+".lock");m_lock->setStaleLockTime(0);
    if(!own.valid||canonical.isEmpty())m_error=QStringLiteral("无法确定当前用户或应用数据目录。");
    m_server.setSocketOptions(QLocalServer::UserAccessOption);
    connect(&m_server,&QLocalServer::newConnection,this,&Instance::acceptConnections);
}
QJsonObject Instance::request(const QString &operation,const QString &directory){
    return {{"version",1},{"id",QUuid::createUuid().toString(QUuid::WithoutBraces)},{"operation",operation},{"directory",directory}};
}
Instance::Result Instance::start(const QJsonObject &request,int timeoutMs){
    if(!m_error.isEmpty())return Failed;
    if(wire(request).size()>65536){m_error=QStringLiteral("启动请求过长。");return Failed;}
    QElapsedTimer timer;timer.start();
    while(timer.elapsed()<timeoutMs){
        qint64 owner=0;QString host,application;
        const bool liveOwner=m_lock->getLockInfo(&owner,&host,&application)&&alive(owner);
        if(!liveOwner&&m_lock->tryLock(0)){
            if(!m_server.listen(m_name)){m_lock->unlock();m_error=QStringLiteral("无法创建本机启动通道：")+m_server.errorString();return Failed;}
            if(!enqueue(request)){m_server.close();m_lock->unlock();return Failed;}
            return Primary;
        }
        if(m_lock->error()==QLockFile::PermissionError){m_error=QStringLiteral("无法访问应用实例锁。");return Failed;}
        QLocalSocket socket;socket.connectToServer(m_name);
        if(socket.waitForConnected(qMin(300,qMax(1,timeoutMs-int(timer.elapsed()))))){
            DWORD pid=0;if(!peer(&socket,true,&pid)){m_error=QStringLiteral("启动通道的用户、会话或权限不匹配。");return Failed;}
            AllowSetForegroundWindow(pid);
            socket.write(wire(request));socket.flush();
            QByteArray response;
            while(timer.elapsed()<timeoutMs&&response.size()<=65536){
                response+=socket.readAll();
                if(response.contains('\n'))break;
                if(socket.state()==QLocalSocket::UnconnectedState)break;
                socket.waitForReadyRead(qMin(300,qMax(1,timeoutMs-int(timer.elapsed()))));
            }
            const auto ack=QJsonDocument::fromJson(response.trimmed()).object();
            if(ack["id"]==request["id"]&&ack["version"].toInt()==1){
                if(ack["accepted"].toBool())return Forwarded;
                m_error=ack["error"].toString(QStringLiteral("已有应用暂时无法接收请求。"));return Failed;
            }
        }
        QThread::msleep(50);
    }
    m_error=QStringLiteral("已有 UTerminal 正在启动、退出或未响应，请稍后重试。未启动第二个窗口。");return Failed;
}
bool Instance::enqueue(const QJsonObject &value){
    const auto id=value["id"].toString(),operation=value["operation"].toString();
    if(value["version"].toInt()!=1||QUuid(id).isNull()||
       (operation!="activate"&&operation!="openDirectory")||!value["directory"].isString()||value["directory"].toString().contains(QChar::Null)){
        m_error=QStringLiteral("不支持的启动请求。");return false;
    }
    if(m_seen.contains(id)){
        if(m_seen[id]==value)return true;
        m_error=QStringLiteral("请求 ID 已被其他启动请求使用。");return false;
    }
    if(m_stopping||m_pending.size()>=128){m_error=QStringLiteral("应用正在退出或启动请求过多，请稍后重试。");return false;}
    m_seen.insert(id,value);m_order.enqueue(id);if(m_order.size()>4096)m_seen.remove(m_order.dequeue());
    m_pending.enqueue(value);QTimer::singleShot(0,this,&Instance::dispatch);return true;
}
void Instance::acceptConnections(){
    while(auto *socket=m_server.nextPendingConnection()){
        if(m_connections>=32||!peer(socket,false)){socket->abort();socket->deleteLater();continue;}
        ++m_connections;socket->setReadBufferSize(65537);
        connect(socket,&QLocalSocket::disconnected,this,[this,socket]{--m_connections;socket->deleteLater();});
        QTimer::singleShot(3000,socket,[socket]{socket->abort();});
        auto consume=[this,socket]{
            if(socket->property("answered").toBool())return;
            auto bytes=socket->property("requestBytes").toByteArray()+socket->readAll();
            if(bytes.size()>65536){socket->abort();return;}
            if(!bytes.contains('\n')){socket->setProperty("requestBytes",bytes);return;}
            socket->setProperty("answered",true);
            const auto value=QJsonDocument::fromJson(bytes.trimmed()).object();const bool accepted=enqueue(value);
            socket->write(wire({{"version",1},{"id",value["id"]},{"accepted",accepted},{"error",accepted?QString():m_error}}));
            socket->flush();socket->disconnectFromServer();
        };
        connect(socket,&QLocalSocket::readyRead,this,consume);consume();
    }
}
void Instance::dispatch(){while(m_ready&&!m_stopping&&!m_pending.isEmpty())emit received(m_pending.dequeue());}
void Instance::setReady(){m_ready=true;QTimer::singleShot(0,this,&Instance::dispatch);}
void Instance::stopAccepting(){m_stopping=true;m_pending.clear();m_server.close();}
}
