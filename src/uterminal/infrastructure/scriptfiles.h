#pragma once
#include <QJsonObject>
#include <QString>
namespace ut {
QString scriptFilesError(const QJsonObject &script);
bool captureScriptFiles(const QString &source,QJsonObject *script,QString *error);
bool materializeScriptFiles(const QJsonObject &script,const QString &directory,QString *error);
}
