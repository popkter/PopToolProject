#include "scripthighlighter.h"
#include <QRegularExpression>
#include <QSet>

namespace ut {
void ScriptHighlighter::setTextDocument(QQuickTextDocument *document) {
    if (m_document == document) return;
    if (m_document) disconnect(m_document, nullptr, this, nullptr);
    m_document = document;
    setDocument(document ? document->textDocument() : nullptr);
    if (document) connect(document, &QQuickTextDocument::textDocumentChanged, this, [this] {
        setDocument(m_document ? m_document->textDocument() : nullptr);
    });
    emit textDocumentChanged();
}
void ScriptHighlighter::setLanguage(const QString &language) {
    if (m_language == language) return;
    m_language = language; rehighlight(); emit languageChanged();
}
void ScriptHighlighter::setDark(bool dark) {
    if (m_dark == dark) return;
    m_dark = dark; rehighlight(); emit darkChanged();
}
void ScriptHighlighter::highlightBlock(const QString &text) {
    const bool python = m_language == "python", cmd = m_language == "cmd";
    const QColor keyword(m_dark ? "#c4a7ff" : "#7136a8");
    const QColor string(m_dark ? "#a5d6a7" : "#287137");
    const QColor comment(m_dark ? "#93a4a0" : "#647569");
    const QColor number(m_dark ? "#f2bf80" : "#945408");
    const QColor variable(m_dark ? "#80c9f3" : "#006ca6");
    static const QSet<QString> pyWords = {"and","as","assert","async","await","break","class","continue","def","del","elif","else","except","False","finally","for","from","global","if","import","in","is","lambda","None","nonlocal","not","or","pass","raise","return","True","try","while","with","yield"};
    static const QSet<QString> psWords = {"begin","break","catch","class","continue","data","do","dynamicparam","else","elseif","end","enum","exit","filter","finally","for","foreach","function","if","in","param","process","return","switch","throw","trap","try","until","using","while","workflow"};
    static const QSet<QString> cmdWords = {"call","cd","chdir","copy","del","do","echo","else","endlocal","errorlevel","exist","exit","for","goto","if","in","mkdir","move","not","pause","popd","pushd","set","setlocal","shift","start","type"};
    const auto &words = python ? pyWords : cmd ? cmdWords : psWords;
    int state = previousBlockState() < 0 ? 0 : previousBlockState();
    if (cmd) state = 0;
    setCurrentBlockState(0);
    const int size = int(text.size());
    int i = 0;
    while (i < size) {
        if (state) {
            const QString end = state == 1 ? "'''" : state == 2 ? "\"\"\"" : state == 3 ? "#>" : state == 4 ? "'@" : "\"@";
            int close = (state >= 4) ? (text.startsWith(end) ? 0 : -1) : int(text.indexOf(end, i));
            int finish = close < 0 ? size : close + int(end.size());
            setFormat(i, finish - i, state == 3 ? comment : string);
            i = finish;
            if (close < 0) { setCurrentBlockState(state); return; }
            state = 0; continue;
        }
        const auto tail = QStringView(text).mid(i);
        if (!cmd && tail.startsWith(u"${")) {
            int end = int(text.indexOf('}', i + 2));
            if (end >= 0) { setFormat(i, end - i + 1, variable); i = end + 1; continue; }
        }
        if (!python && !cmd && tail.startsWith(u"<#")) {
            setFormat(i, 2, comment); i += 2; state = 3;
            if (i == size) setCurrentBlockState(state);
            continue;
        }
        if (python && (tail.startsWith(u"'''") || tail.startsWith(u"\"\"\""))) {
            state = tail.startsWith(u"'''") ? 1 : 2; setFormat(i, 3, string); i += 3;
            if (i == size) setCurrentBlockState(state);
            continue;
        }
        if (!python && !cmd && (tail == u"@'" || tail == u"@\"")) {
            setFormat(i, 2, string); setCurrentBlockState(tail == u"@'" ? 4 : 5); return;
        }
        if ((!cmd && text[i] == '#') || (cmd && text.left(i).trimmed().isEmpty() &&
            (tail.startsWith(u"::") || (tail.startsWith(u"rem", Qt::CaseInsensitive) && (tail.size() == 3 || tail[3].isSpace()))))) {
            setFormat(i, size - i, comment); break;
        }
        if (text[i] == '"' || (!cmd && text[i] == '\'')) {
            const auto quote = text[i]; const int start = i++;
            while (i < size) {
                if ((python && text[i] == '\\') || (!python && !cmd && quote == '"' && text[i] == '`')) { i = qMin(i + 2, size); continue; }
                if (text[i++] == quote) {
                    if (!python && !cmd && i < size && text[i] == quote) { ++i; continue; }
                    break;
                }
            }
            setFormat(start, i - start, string); continue;
        }
        if ((!python && !cmd && text[i] == '$') || (cmd && (text[i] == '%' || text[i] == '!'))) {
            const int start = i++; const auto delimiter = text[start];
            if (cmd) {
                int end = int(text.indexOf(delimiter, i));
                if (end >= 0) i = end + 1;
                else while (i < size && (text[i].isLetterOrNumber() || text[i] == '~')) ++i;
            } else while (i < size && (text[i].isLetterOrNumber() || text[i] == '_' || text[i] == ':')) ++i;
            setFormat(start, i - start, variable); continue;
        }
        if (text[i].isLetterOrNumber() || text[i] == '_') {
            const int start = i++;
            while (i < size && (text[i].isLetterOrNumber() || text[i] == '_')) ++i;
            const QString word = text.mid(start, i - start);
            if (words.contains(python ? word : word.toLower())) setFormat(start, i - start, keyword);
            else if (text[start].isDigit()) setFormat(start, i - start, number);
            continue;
        }
        ++i;
    }
}
}
