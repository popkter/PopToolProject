#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QTimer>
int main(int argc,char **argv){
    QCoreApplication app(argc,argv);
    if(app.arguments().contains("--wait")){QTimer::singleShot(60000,&app,&QCoreApplication::quit);return app.exec();}
    const auto variable=QFileInfo(app.applicationFilePath()).baseName().contains("relaunch",Qt::CaseInsensitive)?"UTERMINAL_TEST_RELAUNCH_OUTPUT":"UTERMINAL_TEST_INSTALLER_OUTPUT";
    QFile output(qEnvironmentVariable(variable));
    if(!output.open(QIODevice::WriteOnly))return 2;
    const auto bytes=QJsonDocument(QJsonArray::fromStringList(app.arguments())).toJson();
    if(output.write(bytes)!=bytes.size())return 3;
    return qEnvironmentVariableIntValue("UTERMINAL_TEST_INSTALLER_EXIT");
}
