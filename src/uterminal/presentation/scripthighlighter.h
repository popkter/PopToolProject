#pragma once
#include <QSyntaxHighlighter>
#include <QQuickTextDocument>
#include <QPointer>

namespace ut {
class ScriptHighlighter : public QSyntaxHighlighter {
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument* textDocument READ textDocument WRITE setTextDocument NOTIFY textDocumentChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool dark READ dark WRITE setDark NOTIFY darkChanged)
public:
    explicit ScriptHighlighter(QObject *parent = nullptr) : QSyntaxHighlighter(parent) {}
    QQuickTextDocument *textDocument() const { return m_document; }
    void setTextDocument(QQuickTextDocument *document);
    QString language() const { return m_language; }
    void setLanguage(const QString &language);
    bool dark() const { return m_dark; }
    void setDark(bool dark);
signals:
    void textDocumentChanged();
    void languageChanged();
    void darkChanged();
protected:
    void highlightBlock(const QString &text) override;
private:
    QPointer<QQuickTextDocument> m_document;
    QString m_language = "powershell";
    bool m_dark = false;
};
}
