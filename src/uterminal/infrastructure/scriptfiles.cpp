#include "scriptfiles.h"
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QRegularExpression>
#include <QSet>

namespace ut {
namespace {
constexpr qint64 maximumBytes=64ll*1024*1024;
constexpr int maximumFiles=1024;
bool safePath(const QString &path){
    if(path.isEmpty()||QDir::isAbsolutePath(path)||path.contains('\\'))return false;
    static const QRegularExpression reserved("^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\\.|$)",QRegularExpression::CaseInsensitiveOption);
    for(const auto &part:path.split('/')){
        if(part.isEmpty()||part=="."||part==".."||part.endsWith('.')||part.endsWith(' ')||reserved.match(part).hasMatch())return false;
        for(const auto ch:part)if(ch.unicode()<32||QStringLiteral(":*?\"<>|").contains(ch))return false;
    }
    return true;
}
QString entrySuffix(const QJsonObject &script){const auto language=script["language"].toString();return language=="python"?"py":language=="cmd"?"cmd":"ps1";}
}
QString scriptFilesError(const QJsonObject &script){
    if(!script.contains("bundledFiles")&&!script.contains("bundleEntryPoint")&&!script.contains("bundledDirectories"))return {};
    const auto entry=script["bundleEntryPoint"].toString();
    const auto suffix=QFileInfo(entry).suffix().toLower();
    if(!safePath(entry)||entry.contains('/')||(suffix!=entrySuffix(script)&&!(script["language"]=="cmd"&&suffix=="bat")))return QStringLiteral("附件主脚本文件名无效");
    if(!script["bundledFiles"].isObject())return QStringLiteral("脚本附件必须是文件映射");
    const auto files=script["bundledFiles"].toObject();if(files.size()>maximumFiles)return QStringLiteral("脚本附件超过 1024 个文件");
    QSet<QString> paths{entry.toCaseFolded()};qint64 bytes=0;
    for(auto it=files.begin();it!=files.end();++it){
        const auto path=it.key().toCaseFolded();
        if(!safePath(it.key())||paths.contains(path))return QStringLiteral("脚本附件路径无效或重复：")+it.key();
        paths.insert(path);
        if(!it.value().isString()||it.value().toString().size()>((maximumBytes+2)/3)*4)return QStringLiteral("脚本附件内容无效或超过 64 MiB");
        const auto decoded=QByteArray::fromBase64Encoding(it.value().toString().toLatin1(),QByteArray::AbortOnBase64DecodingErrors);
        if(!decoded)return QStringLiteral("脚本附件 Base64 无效：")+it.key();
        bytes+=decoded.decoded.size();if(bytes>maximumBytes)return QStringLiteral("脚本附件总大小超过 64 MiB");
    }
    for(const auto &path:paths){auto parent=path;while(parent.contains('/')){parent=parent.left(parent.lastIndexOf('/'));if(paths.contains(parent))return QStringLiteral("脚本附件文件与目录冲突：")+parent;}}
    if(script.contains("bundledDirectories")&&!script["bundledDirectories"].isArray())return QStringLiteral("脚本附件目录必须是数组");
    const auto directories=script["bundledDirectories"].toArray();
    if(directories.size()>maximumFiles)return QStringLiteral("脚本附件超过 1024 个目录");
    QSet<QString> directoryPaths;
    for(const auto &value:directories){
        const auto name=value.toString();const auto path=name.toCaseFolded();
        if(!value.isString()||!safePath(name)||directoryPaths.contains(path))return QStringLiteral("脚本附件目录无效或重复：")+name;
        directoryPaths.insert(path);auto parent=path;
        while(true){if(paths.contains(parent))return QStringLiteral("脚本附件文件与目录冲突：")+parent;if(!parent.contains('/'))break;parent=parent.left(parent.lastIndexOf('/'));}
    }
    return {};
}
bool captureScriptFiles(const QString &source,QJsonObject *script,QString *error){
    const QFileInfo info(source);const QDir root=info.absoluteDir();QJsonObject files;QJsonArray directories;qint64 total=0;
    QDirIterator iterator(root.absolutePath(),QDir::Files|QDir::Dirs|QDir::Hidden|QDir::System|QDir::NoDotAndDotDot,QDirIterator::Subdirectories);
    while(iterator.hasNext()){
        iterator.next();const auto fileInfo=iterator.fileInfo();
        if(fileInfo.isSymLink()||fileInfo.isJunction()){*error=QStringLiteral("不能导入包含链接的脚本附件：")+fileInfo.filePath();return false;}
        if(fileInfo.absoluteFilePath()==info.absoluteFilePath())continue;
        const auto relative=root.relativeFilePath(fileInfo.absoluteFilePath());
        if(!safePath(relative)){*error=QStringLiteral("脚本附件路径无效：")+relative;return false;}
        if(fileInfo.isDir()){
            if(directories.size()>=maximumFiles){*error=QStringLiteral("脚本附件超过 1024 个目录，请整理源码目录后导入");return false;}
            directories.append(relative);continue;
        }
        if(files.size()>=maximumFiles||fileInfo.size()>maximumBytes-total){*error=QStringLiteral("脚本附件超过 1024 文件或 64 MiB，请整理源码目录后导入");return false;}
        QFile file(fileInfo.absoluteFilePath());if(!file.open(QIODevice::ReadOnly)){*error=file.errorString();return false;}
        const auto data=file.read(maximumBytes-total+1);if(file.error()!=QFile::NoError||data.size()>maximumBytes-total){*error=QStringLiteral("无法完整读取脚本附件：")+relative;return false;}
        total+=data.size();files[relative]=QString::fromLatin1(data.toBase64());
    }
    (*script)["bundleEntryPoint"]=info.fileName();(*script)["bundledFiles"]=files;(*script)["bundledDirectories"]=directories;return true;
}
bool materializeScriptFiles(const QJsonObject &script,const QString &directory,QString *error){
    *error=scriptFilesError(script);if(!error->isEmpty())return false;
    for(const auto &value:script["bundledDirectories"].toArray()){
        if(!QDir().mkpath(QDir(directory).filePath(value.toString()))){*error=QStringLiteral("无法创建附件目录：")+value.toString();return false;}
    }
    const auto files=script["bundledFiles"].toObject();
    for(auto it=files.begin();it!=files.end();++it){
        const auto path=QDir(directory).filePath(it.key());
        if(!QDir().mkpath(QFileInfo(path).absolutePath())){*error=QStringLiteral("无法创建附件目录");return false;}
        QFile file(path);const auto data=QByteArray::fromBase64(it.value().toString().toLatin1());
        if(!file.open(QIODevice::WriteOnly|QIODevice::NewOnly)||file.write(data)!=data.size()){*error=file.errorString();return false;}
    }
    return true;
}
}
