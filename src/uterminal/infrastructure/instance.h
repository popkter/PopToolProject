#pragma once
#include <QObject>
#include <QJsonObject>
#include <QLocalServer>
#include <QLockFile>
#include <QQueue>
#include <QHash>
#include <memory>

namespace ut {
bool processElevated();
QString profileDirectory(const QString &base,bool elevated);

class Instance : public QObject {
    Q_OBJECT
public:
    enum Result { Primary, Forwarded, Failed };
    explicit Instance(const QString &directory,QObject *parent=nullptr);
    Result start(const QJsonObject &request,int timeoutMs=8000);
    void setReady();
    void stopAccepting();
    QString error() const { return m_error; }
    QString serverName() const { return m_name; }
    QString lockPath() const { return m_lock->fileName(); }
    static QJsonObject request(const QString &operation,const QString &directory={});
signals:
    void received(const QJsonObject &request);
private:
    void acceptConnections();
    bool enqueue(const QJsonObject &request);
    void dispatch();
    QLocalServer m_server;
    std::unique_ptr<QLockFile> m_lock;
    QString m_name,m_error;
    QQueue<QJsonObject> m_pending;
    QQueue<QString> m_order;
    QHash<QString,QJsonObject> m_seen;
    bool m_ready=false,m_stopping=false;
    int m_connections=0;
};
}
