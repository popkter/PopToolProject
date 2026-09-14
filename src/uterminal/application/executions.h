#pragma once
#include <QObject>
#include <QJsonObject>
#include <QVariantMap>
#include <QElapsedTimer>
#include <QStringDecoder>
#include <QTimer>
#include <QPointer>

namespace ut {
class Plugins;class Settings;class Scripts;class Sessions;class ProcessRunner;class Pane;
class Executions : public QObject {
    Q_OBJECT
    Q_PROPERTY(int runningCount READ runningCount NOTIFY changed)
    Q_PROPERTY(QString output READ output NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString outcome READ outcome NOTIFY changed)
    Q_PROPERTY(bool selectedRunning READ selectedRunning NOTIFY changed)
    Q_PROPERTY(bool selectedInteractive READ selectedInteractive NOTIFY changed)
public:
    Executions(QString directory,Plugins *plugins,Settings *settings,Scripts *scripts,Sessions *sessions,QObject *parent=nullptr);
    ~Executions() override;
    int runningCount() const;
    QString output() const;
    QString status() const;
    QString outcome() const;
    bool selectedRunning() const;
    bool selectedInteractive() const;
    Q_INVOKABLE void runSelected(const QVariantMap &parameters,bool interactive=false);
    Q_INVOKABLE void confirmRun();
    Q_INVOKABLE void cancelRun();
    Q_INVOKABLE void stopSelected();
    Q_INVOKABLE void stopAll();
    Q_INVOKABLE void clearOutput();
signals:
    void changed();
    void error(const QString &message);
    void pluginRequired(const QString &kind);
    void confirmationRequested(const QString &message);
    void interactiveStarted();
private:
    struct Run {
        QString id,directory,pythonVersion,powerShellVersion,output,status;
        QPointer<ProcessRunner> process;
        QPointer<Pane> pane;
        QPointer<QTimer> timeout;
        QString stopReason;
        QStringList secrets;
        QElapsedTimer clock;
        QStringDecoder decoder{QStringDecoder::Utf8};
        bool running=false,interactive=false;
        bool succeeded=false;
    };
    void launch(QJsonObject script,QVariantMap parameters,bool interactive);
    void finish(Run *run,int code,const QString &reason);
    void append(Run *run,const QByteArray &bytes);
    void cleanupSource(const QString &directory);
    Run *selected() const;
    QString m_directory;
    Plugins *m_plugins;Settings *m_settings;Scripts *m_scripts;Sessions *m_sessions;
    QHash<QString,Run*> m_runs;
    QJsonObject m_pending;
    QVariantMap m_parameters;
    bool m_interactive=false,m_replace=false,m_dirty=false;
    QPointer<ProcessRunner> m_waitingFor;
    QTimer m_flush;
};
}
