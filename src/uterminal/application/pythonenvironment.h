#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QPointer>
#include <QJsonObject>
#include <QJsonArray>
#include <QStringDecoder>
#include <functional>
namespace ut {
class Plugins;class ProcessRunner;
class PythonEnvironment : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool queued READ queued NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString log READ log NOTIFY changed)
    Q_PROPERTY(QVariantList packages READ packages NOTIFY changed)
    Q_PROPERTY(QVariantMap diagnostics READ diagnostics NOTIFY changed)
    Q_PROPERTY(QVariantMap information READ information NOTIFY changed)
    Q_PROPERTY(QString migrationTarget READ migrationTarget NOTIFY changed)
    Q_PROPERTY(QString requirements READ requirements NOTIFY changed)
public:
    PythonEnvironment(QString directory,Plugins *plugins,QObject *parent=nullptr);
    ~PythonEnvironment() override;
    bool busy()const{return m_busy;}
    bool queued()const{return m_queued;}
    QString status()const{return m_status;}
    QString log()const{return m_log;}
    QVariantList packages()const{return m_info["packages"].toArray().toVariantList();}
    QVariantMap diagnostics()const{return m_diagnostics.toVariantMap();}
    QVariantMap information()const{return m_info.toVariantMap();}
    QString migrationTarget()const{return m_target;}
    QString requirements()const{return m_requirements;}
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void probe(const QString &source,const QString &directory=QString());
    Q_INVOKABLE void installPackages(const QString &packages);
    Q_INVOKABLE void installSuggested();
    Q_INVOKABLE void requestSwitch(const QString &version);
    Q_INVOKABLE void confirmSwitch(bool migrate);
    Q_INVOKABLE void cancel();
    static QStringList packageArguments(const QString &input,QString *error);
signals:
    void changed();
    void error(const QString &message);
    void switchConfirmationRequested();
private:
    void inspect(const QJsonObject &request);
    void run(const QString &program,const QStringList &args,const QString &version,std::function<void()> success);
    void fail(const QString &message);
    void releaseLocks();
    void tryQueued();
    void validateAndActivate();
    QString m_directory,m_version,m_target,m_status,m_log,m_requirements,m_temp,m_output,m_readLease;
    QJsonObject m_info,m_diagnostics;
    Plugins *m_plugins;
    QPointer<ProcessRunner> m_process;
    QStringList m_locks,m_args;
    QByteArray m_captured;
    QStringDecoder m_decoder{QStringDecoder::Utf8};
    std::function<void()> m_whenIdle;
    bool m_busy=false,m_queued=false,m_cancelled=false,m_confirming=false;
};
}
