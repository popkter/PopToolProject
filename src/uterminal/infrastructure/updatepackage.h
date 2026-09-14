#pragma once
#include <QString>
namespace ut {
bool verifyUpdatePackage(const QString &path,qint64 size,const QString &sha256);
}
