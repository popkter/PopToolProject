#include "updatepackage.h"
#include <QFile>
#include <QCryptographicHash>
#include <QRegularExpression>
namespace ut {
bool verifyUpdatePackage(const QString &path,qint64 size,const QString &sha256){
    static const QRegularExpression digest("^[0-9a-fA-F]{64}$");
    if(size<=0||size>512ll*1024*1024||!digest.match(sha256).hasMatch())return false;
    QFile file(path);if(!file.open(QIODevice::ReadOnly)||file.size()!=size)return false;
    QCryptographicHash hash(QCryptographicHash::Sha256);
    return hash.addData(&file)&&QString::fromLatin1(hash.result().toHex())==sha256.toLower();
}
}
