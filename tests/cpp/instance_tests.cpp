#include <QtTest>
#include <QProcess>
#include <QLocalSocket>
#include <QJsonDocument>
#include <QFile>
#include "infrastructure/instance.h"

class InstanceTests:public QObject {
    Q_OBJECT
    QString fixture()const{return QCoreApplication::applicationDirPath()+"/uterminal_instance_fixture.exe";}
private slots:
    void queuedUntilReadyAndRetryDeduplicated(){
        QTemporaryDir temporary;ut::Instance primary(temporary.path());
        const auto initial=ut::Instance::request("activate");QSignalSpy received(&primary,&ut::Instance::received);
        QCOMPARE(primary.start(initial),ut::Instance::Primary);
        const QString id=QUuid::createUuid().toString(QUuid::WithoutBraces);
        for(int attempt=0;attempt<2;++attempt){
            QProcess client;client.start(fixture(),{temporary.path(),"openDirectory",QStringLiteral("D:/中文 path"),id});
            QTRY_COMPARE_WITH_TIMEOUT(client.state(),QProcess::NotRunning,5000);
            QCOMPARE(client.exitCode(),0);QVERIFY(client.readAllStandardOutput().contains("FORWARDED"));
        }
        QCOMPARE(received.count(),0);primary.setReady();QTRY_COMPARE(received.count(),2);
        QCOMPARE(received[1][0].toJsonObject()["directory"].toString(),QStringLiteral("D:/中文 path"));
        QProcess newClick;newClick.start(fixture(),{temporary.path(),"openDirectory",QStringLiteral("D:/中文 path")});
        QTRY_COMPARE_WITH_TIMEOUT(newClick.state(),QProcess::NotRunning,5000);QCOMPARE(newClick.exitCode(),0);QTRY_COMPARE(received.count(),3);
    }
    void concurrentColdStarts(){
        QTemporaryDir temporary;QList<std::shared_ptr<QProcess>> processes;QList<QByteArray> outputs;
        for(int i=0;i<8;++i){auto p=std::make_shared<QProcess>();p->start(fixture(),{temporary.path(),"openDirectory",QString::number(i)});processes.append(p);outputs.append(QByteArray());}
        const auto cleanup=qScopeGuard([&]{for(auto &p:processes)if(p->state()!=QProcess::NotRunning){p->kill();p->waitForFinished();}});
        auto complete=[&]{int forwarded=0,primary=0,requests=0;for(int i=0;i<processes.size();++i){outputs[i]+=processes[i]->readAllStandardOutput();forwarded+=outputs[i].count("FORWARDED");primary+=outputs[i].count("PRIMARY");requests+=outputs[i].count("RECEIVED=");}return forwarded==7&&primary==1&&requests==8;};
        QTRY_VERIFY_WITH_TIMEOUT(complete(),8000);
    }
    void liveUnresponsiveOwnerIsNotReplaced(){
        QTemporaryDir temporary;ut::Instance primary(temporary.path());QCOMPARE(primary.start(ut::Instance::request("activate")),ut::Instance::Primary);
        QProcess client;client.start(fixture(),{temporary.path(),"activate",""});
        // Deliberately block this server's event loop to reproduce a live, hung owner.
        QVERIFY(client.waitForFinished(5000));QCOMPARE(client.exitCode(),2);
        QVERIFY(QFile::exists(primary.lockPath()));
    }
    void crashedOwnerCanBeReplaced(){
        QTemporaryDir temporary;QProcess first;first.start(fixture(),{temporary.path(),"activate",""});
        QVERIFY(first.waitForReadyRead(5000));QVERIFY(first.readAllStandardOutput().contains("PRIMARY"));first.kill();QVERIFY(first.waitForFinished());
        ut::Instance replacement(temporary.path());QCOMPARE(replacement.start(ut::Instance::request("activate")),ut::Instance::Primary);
    }
    void profileIsolationAndMalformedRequest(){
        QTemporaryDir temporary;
        const auto normal=ut::profileDirectory(temporary.path(),false),admin=ut::profileDirectory(temporary.path(),true);
        QCOMPARE(normal,temporary.path());QVERIFY(normal!=admin);
        ut::Instance a(normal),b(admin);QCOMPARE(a.start(ut::Instance::request("activate")),ut::Instance::Primary);QCOMPARE(b.start(ut::Instance::request("activate")),ut::Instance::Primary);
        QVERIFY(a.serverName()!=b.serverName());QSignalSpy received(&a,&ut::Instance::received);a.setReady();QTRY_COMPARE(received.count(),1);
        QLocalSocket socket;socket.connectToServer(a.serverName());QVERIFY(socket.waitForConnected(1000));socket.write("{\"version\":99}\n");socket.flush();
        QTRY_VERIFY(socket.bytesAvailable()>0);const auto ack=QJsonDocument::fromJson(socket.readAll().trimmed()).object();QVERIFY(!ack["accepted"].toBool());QCOMPARE(received.count(),1);
        a.stopAccepting();
    }
};
QTEST_GUILESS_MAIN(InstanceTests)
#include "instance_tests.moc"
