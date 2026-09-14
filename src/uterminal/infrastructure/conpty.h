#pragma once
#include <QObject>
#include <QProcessEnvironment>
#include <QTimer>
#include <memory>

namespace ut {
class ConPty : public QObject {
    Q_OBJECT
public:
    explicit ConPty(QObject *parent=nullptr);
    ~ConPty() override;
    bool start(const QString &program,const QStringList &arguments,const QString &directory,
               const QProcessEnvironment &environment,int columns=100,int rows=30);
    void write(const QByteArray &bytes);
    void resize(int columns,int rows);
    void interrupt();
    void close();
    bool running() const;
    static QString quoteArgument(const QString &argument);
signals:
    void output(const QByteArray &data);
    void finished(int code);
    void error(const QString &message);
private:
    struct State;
    std::unique_ptr<State> m_state;
    QTimer m_pump;
    void pump();
};
}
