#pragma once
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <memory>

namespace ut {
// Every child enters a private Windows Job at creation, before it can spawn descendants.
class ProcessRunner : public QObject {
    Q_OBJECT
public:
    explicit ProcessRunner(QObject *parent=nullptr);
    ~ProcessRunner() override;
    bool start(const QString &program,const QStringList &arguments,const QString &directory,
               const QProcessEnvironment &environment,int timeoutSeconds);
    void stop();
    bool running() const { return m_process.state()!=QProcess::NotRunning; }
signals:
    void output(const QByteArray &bytes);
    void finished(int exitCode,const QString &reason);
private:
    struct State;
    std::unique_ptr<State> m_state;
    QProcess m_process;
    QTimer m_timeout,m_forceStop;
    QString m_reason;
    void killTree();
};
}
