#pragma once
#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QTimer>
#include <QSaveFile>
#include <QCryptographicHash>
class QNetworkReply;
namespace ut {
class Settings;class Plugins;
class Updates : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool downloading READ downloading NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QVariantMap available READ available NOTIFY changed)
    Q_PROPERTY(QVariantMap downloaded READ downloaded NOTIFY changed)
    Q_PROPERTY(int progress READ progress NOTIFY changed)
    Q_PROPERTY(bool installOnExit READ installOnExit WRITE setInstallOnExit NOTIFY changed)
    Q_PROPERTY(QString installationStatus READ installationStatus NOTIFY changed)
public:
    Updates(QString directory,Settings *settings,Plugins *plugins,QObject *parent=nullptr,QNetworkAccessManager *transport=nullptr);
    bool downloading()const{return !m_download.isNull();}
    bool busy()const{return !m_reply.isNull()||!m_download.isNull();}
    QString status()const{return m_status;}
    QString installationStatus()const{return m_installationStatus;}
    QString currentVersion()const;
    QVariantMap available()const{return m_available.toVariantMap();}
    QVariantMap downloaded()const{return m_ready.toVariantMap();}
    int progress()const{return m_progress;}
    bool installOnExit()const{return m_installOnExit;}
    void setInstallOnExit(bool enabled);
    void launchInstallerAfterExit();
    static QString stageHelper(const QString &sourceDirectory,const QString &destination);
    static int cleanupHelperCache(const QString &updatesDirectory);
    Q_INVOKABLE void check();
    Q_INVOKABLE void download();
    Q_INVOKABLE void cancelDownload();
    static QJsonObject selectRelease(const QJsonArray &releases,const QString &current,bool prerelease);
    static bool due(const QString &policy,qint64 last,qint64 now,bool startupUsed);
signals:
    void changed();
private:
    void schedule();
    void select();
    QString readyPath()const;
    bool verifyReady()const;
    void readInstallationReceipt();
    QString m_installationStatus;
    QString m_directory,m_status=QStringLiteral("尚未检查更新");
    Settings *m_settings;Plugins *m_plugins;
    QNetworkAccessManager m_network;
    QNetworkAccessManager *m_transport;
    QPointer<QNetworkReply> m_reply;
    QPointer<QNetworkReply> m_download;
    std::unique_ptr<QSaveFile> m_file;
    std::unique_ptr<QCryptographicHash> m_hash;
    QJsonObject m_downloadPackage,m_ready;
    QString m_downloadPath,m_downloadError;
    qint64 m_received=0;
    int m_progress=0;
    bool m_installOnExit=false,m_downloadCancelled=false;
    QJsonArray m_releases;
    QJsonObject m_available,m_state;
    QTimer m_timer;
    bool m_startupUsed=false;
};
}
