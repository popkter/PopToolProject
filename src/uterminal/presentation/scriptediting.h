#pragma once
#include <QObject>
#include <QVariantMap>
class QQuickTextDocument;
class QTextDocument;
namespace ut {
class ScriptEditing : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE QVariantMap indent(QQuickTextDocument *document, int anchor, int position, bool reverse);
    static QVariantMap indentDocument(QTextDocument *document, int anchor, int position, bool reverse);
};
}
