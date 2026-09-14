#include "storage.h"
#include "instance.h"
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUuid>

namespace ut {
QString dataDirectory() {
    const auto overridePath = qEnvironmentVariable("UTERMINAL_DATA_DIR");
    const auto base=overridePath.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) : overridePath;
    return profileDirectory(base,processElevated());
}
QJsonObject readJson(const QString &path, QString *error) {
    QFile f(path);
    if (!f.exists()) return {};
    if (!f.open(QIODevice::ReadOnly)) { if (error) *error = f.errorString(); return {}; }
    QJsonParseError parse;
    auto doc = QJsonDocument::fromJson(f.readAll(), &parse);
    if (parse.error != QJsonParseError::NoError || !doc.isObject()) {
        if (error) *error = QStringLiteral("配置文件无效：") + path + " " + parse.errorString();
        return {};
    }
    return doc.object();
}
bool writeJson(const QString &path, const QJsonObject &data, QString *error) {
    if (!QDir().mkpath(QFileInfo(path).absolutePath())) {
        if (error) *error = QStringLiteral("无法创建目录"); return false;
    }
    QSaveFile f(path);
    auto bytes = QJsonDocument(data).toJson(QJsonDocument::Indented);
    if (!f.open(QIODevice::WriteOnly) || f.write(bytes) != bytes.size() || !f.commit()) {
        if (error) *error = f.errorString(); return false;
    }
    return true;
}
QString backupFile(const QString &path, const QString &directory) {
    if (!QFile::exists(path)) return {};
    QDir().mkpath(directory);
    auto target = directory + "/" + QFileInfo(path).fileName() + "." + QUuid::createUuid().toString(QUuid::Id128);
    return QFile::copy(path, target) ? target : QString();
}
}
