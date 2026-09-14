#pragma once
#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QProcess>
#include <QProcessEnvironment>
#include <QFile>
#include <QPointer>
#include <QCryptographicHash>
#include <functional>
#include <memory>

namespace ut {
class ProcessRunner;
class Plugins : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList pythonVersions READ pythonVersions NOTIFY changed)
    Q_PROPERTY(QVariantList powerShellVersions READ powerShellVersions NOTIFY changed)
    Q_PROPERTY(QString pythonVersion READ pythonVersion NOTIFY changed)
    Q_PROPERTY(QString powerShellVersion READ powerShellVersion NOTIFY changed)
    Q_PROPERTY(bool pythonReady READ pythonReady NOTIFY changed)
    Q_PROPERTY(bool powerShellReady READ powerShellReady NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(int progress READ progress NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString catalogStatus READ catalogStatus NOTIFY changed)
    Q_PROPERTY(bool catalogRefreshing READ catalogRefreshing NOTIFY changed)
    Q_PROPERTY(QString taskKind READ taskKind NOTIFY changed)
    Q_PROPERTY(QString taskVersion READ taskVersion NOTIFY changed)
    Q_PROPERTY(bool cancellationRequested READ cancellationRequested NOTIFY changed)
public:
    explicit Plugins(QString directory,QString resources,QObject *parent=nullptr,QNetworkAccessManager *network=nullptr);
    ~Plugins() override;
    QVariantList pythonVersions()const;
    QVariantList powerShellVersions()const;
    QString pythonVersion()const{return m_active["python"].toString();}
    QString powerShellVersion()const{return m_active["powershell"].toString();}
    bool pythonReady()const;
    bool powerShellReady()const;
    bool busy()const{return m_busy;}
    int progress()const{return m_progress;}
    QString status()const{return m_status;}
    QString catalogStatus()const{return m_catalogStatus;}
    bool catalogRefreshing()const{return !m_catalogReply.isNull();}
    QString taskKind()const{return m_kind;}
    QString taskVersion()const{return m_version;}
    bool cancellationRequested()const{return m_busy&&m_cancelled;}
    QString executable(const QString &kind,const QString &version=QString())const;
    QString environmentPath(const QString &version=QString())const;
    QProcessEnvironment environment(const QString &pythonVersion=QString())const;
    QString resourcePath(const QString &name)const{return m_resources+"/plugin-bootstrap/"+name;}
    Q_INVOKABLE void install(const QString &kind,const QString &version);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE bool activate(const QString &kind,const QString &version);
    Q_INVOKABLE void refreshCatalog();
    Q_INVOKABLE bool removeVersion(const QString &kind,const QString &version);
    Q_INVOKABLE QString pythonDirectory()const{return environmentPath();}
    void acquire(const QString &kind,const QString &version);
    void release(const QString &kind,const QString &version);
    bool inUse(const QString &kind,const QString &version)const;
    bool reservePython(const QString &version);
    void releasePythonReservation(const QString &version);
    bool pythonReserved(const QString &version=QString())const;
    bool installedVersion(const QString &kind,const QString &version)const{return ready(kind,version);}
    bool commitActivation(const QString &kind,const QString &version);
    static QString archiveSizeError(qint64 expected,qint64 received,bool complete);
signals:
    void changed();
    void error(const QString &message);
    void installed(const QString &kind,const QString &version);
    void leasesChanged();
    void pythonSwitchRequested(const QString &version);
private:
    QVariantList versions(const QString &kind)const;
    QString versionDirectory(const QString &kind,const QString &version)const;
    bool ready(const QString &kind,const QString &version)const;
    void fail(const QString &message);
    void consumeDownload();
    void unpack();
    void prepare();
    void validate();
    void complete();
    void runStep(const QString &program,const QStringList &args,std::function<void()> next);
    QString m_directory,m_resources,m_kind,m_version,m_archive,m_status;
    QString m_downloadError;
    qint64 m_received=0,m_expectedSize=0;
    QJsonObject m_active,m_package;
    QJsonArray m_catalog;
    QHash<QString,int> m_leases;
    QSet<QString> m_pythonReservations;
    QNetworkAccessManager *m_network;
    QPointer<QNetworkReply> m_catalogReply;
    QString m_catalogStatus;
    QPointer<QNetworkReply> m_download;
    QPointer<ProcessRunner> m_process;
    std::unique_ptr<QFile> m_file;
    std::unique_ptr<QCryptographicHash> m_hash;
    std::shared_ptr<void> m_environmentWriteLock;
    bool m_busy=false,m_cancelled=false;
    int m_progress=0;
};
}
