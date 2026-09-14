#include <QCoreApplication>
#include <QProcess>
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <QFileInfo>
#include <QLockFile>
#include <Windows.h>
#include "infrastructure/updatepackage.h"
int main(int argc,char **argv){
    SetErrorMode(SEM_FAILCRITICALERRORS|SEM_NOGPFAULTERRORBOX|SEM_NOOPENFILEERRORBOX);
    QCoreApplication app(argc,argv);const auto args=app.arguments();if(args.size()!=5&&args.size()!=6&&args.size()!=7)return 2;
    QLockFile cacheLease(QCoreApplication::applicationDirPath()+"/helper.lock");cacheLease.setStaleLockTime(0);
    const QString receiptPath=args.size()>=6?args[5]:QString();QJsonObject receipt;
    const QString restartPath=args.size()==7?args[6]:QString();
    if(!receiptPath.isEmpty()){QFile previous(receiptPath);if(previous.open(QIODevice::ReadOnly))receipt=QJsonDocument::fromJson(previous.readAll()).object();}
    receipt.remove("installerExitCode");
    auto report=[&](const QString &state,const QString &message){
        if(receiptPath.isEmpty())return true;
        receipt["state"]=state;receipt["message"]=message;receipt["updatedAt"]=QDateTime::currentSecsSinceEpoch();
        QSaveFile file(receiptPath);const auto bytes=QJsonDocument(receipt).toJson();
        return file.open(QIODevice::WriteOnly)&&file.write(bytes)==bytes.size()&&file.commit();
    };
    auto fail=[&](int code,const QString &message){report("failed",message);return code;};
    if(QFileInfo::exists(QCoreApplication::applicationDirPath()+"/helper-cache.json")&&!cacheLease.tryLock(5000))return fail(8,QStringLiteral("更新助手目录正在使用，未启动安装，请稍后重试"));
    bool ok=false;const auto pid=args[1].toUInt(&ok);if(!ok||!pid)return 2;
    if(!report("waiting",QStringLiteral("等待应用退出")))return 6;
    HANDLE parent=OpenProcess(SYNCHRONIZE,FALSE,pid);
    if(parent){const auto result=WaitForSingleObject(parent,120000);CloseHandle(parent);if(result!=WAIT_OBJECT_0)return fail(3,QStringLiteral("等待应用退出超时或失败，未启动安装"));}
    else if(GetLastError()!=ERROR_INVALID_PARAMETER)return fail(3,QStringLiteral("无法确认应用已退出，未启动安装"));
    const auto size=args[3].toLongLong(&ok);if(!ok||!ut::verifyUpdatePackage(args[2],size,args[4]))return fail(4,QStringLiteral("安装包大小或 SHA-256 校验失败，请重新下载"));
    QStringList installerArgs{"/SILENT","/SUPPRESSMSGBOXES","/NORESTART","/NOCLOSEAPPLICATIONS","/NORESTARTAPPLICATIONS"};
    if(!receiptPath.isEmpty())installerArgs.append("/LOG="+QFileInfo(receiptPath).absolutePath()+"/installer.log");
    QProcess installer;installer.setProcessChannelMode(QProcess::ForwardedChannels);installer.start(args[2],installerArgs);
    if(!installer.waitForStarted())return fail(5,QStringLiteral("无法启动安装程序，请检查安装包是否可运行"));
    report("launched",QStringLiteral("安装程序正在运行"));
    if(!installer.waitForFinished(-1))return fail(7,QStringLiteral("无法取得安装程序的退出结果，请查看 installer.log"));
    receipt["installerExitCode"]=installer.exitCode();
    if(installer.exitStatus()!=QProcess::NormalExit||installer.exitCode()!=0)return fail(7,QStringLiteral("安装程序失败或被取消，退出码 %1。请查看 installer.log").arg(installer.exitCode()));
    if(!restartPath.isEmpty()&&!QProcess::startDetached(restartPath,{}))return report("restart_failed",QStringLiteral("更新已安装，但无法自动重新启动 UTerminal"))?9:6;
    return report("installed",restartPath.isEmpty()?QStringLiteral("安装程序成功结束，目标版本将在下次启动时核对"):QStringLiteral("安装程序成功结束，UTerminal 已重新启动"))?0:6;
}
