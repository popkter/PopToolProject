#include <QCoreApplication>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QTimer>
int main(int argc,char **argv){
    QCoreApplication app(argc,argv);
    if(app.arguments().contains("--wait")){QTimer::singleShot(60000,&app,&QCoreApplication::quit);return app.exec();}
    QFile output(qEnvironmentVariable("UTERMINAL_TEST_INSTALLER_OUTPUT"));
    if(!output.open(QIODevice::WriteOnly))return 2;
    const auto bytes=QJsonDocument(QJsonArray::fromStringList(app.arguments())).toJson();
    if(output.write(bytes)!=bytes.size())return 3;
    return qEnvironmentVariableIntValue("UTERMINAL_TEST_INSTALLER_EXIT");
}
