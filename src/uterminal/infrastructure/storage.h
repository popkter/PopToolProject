#pragma once
#include <QJsonObject>

namespace ut {
QString dataDirectory();
QJsonObject readJson(const QString &path, QString *error = nullptr);
bool writeJson(const QString &path, const QJsonObject &data, QString *error = nullptr);
QString backupFile(const QString &path, const QString &backupDirectory);
}
