#include <QCoreApplication>
#include <QFile>
#include <QJsonDocument>
#include <QTimer>
#include "infrastructure/instance.h"
int main(int argc,char **argv){
    QCoreApplication app(argc,argv);const auto args=app.arguments();if(args.size()<4)return 4;
    ut::Instance instance(args[1]);
    auto request=ut::Instance::request(args[2],args[3]);if(args.size()>4)request["id"]=args[4];
    QFile output;output.open(stdout,QIODevice::WriteOnly);
    const auto result=instance.start(request,2000);
    if(result==ut::Instance::Failed){output.write(instance.error().toUtf8());output.flush();return 2;}
    if(result==ut::Instance::Forwarded){output.write("FORWARDED\n");output.flush();return 0;}
    output.write("PRIMARY\n");output.flush();
    QObject::connect(&instance,&ut::Instance::received,&app,[&](const QJsonObject &value){output.write("RECEIVED="+QJsonDocument(value).toJson(QJsonDocument::Compact)+'\n');output.flush();});
    QTimer::singleShot(300,&instance,&ut::Instance::setReady);
    QTimer::singleShot(15000,&app,&QCoreApplication::quit);
    return app.exec();
}
