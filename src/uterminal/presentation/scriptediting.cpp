#include "scriptediting.h"
#include <QQuickTextDocument>
#include <QTextDocument>
#include <QTextCursor>
#include <QTextBlock>

namespace ut {
QVariantMap ScriptEditing::indent(QQuickTextDocument *document, int anchor, int position, bool reverse) {
    return indentDocument(document ? document->textDocument() : nullptr, anchor, position, reverse);
}
QVariantMap ScriptEditing::indentDocument(QTextDocument *document, int anchor, int position, bool reverse) {
    if (!document) return {{"anchor", anchor}, {"position", position}};
    const int last = document->characterCount() - 1;
    anchor = qBound(0, anchor, last); position = qBound(0, position, last);
    const bool selected = anchor != position;
    const int start = qMin(anchor, position), end = qMax(anchor, position);
    QTextCursor edit(document);
    edit.beginEditBlock();
    if (!selected && !reverse) {
        const auto block = document->findBlock(position);
        int column = 0;
        for (auto ch : block.text().left(position - block.position())) column += ch == '\t' ? 4 - column % 4 : 1;
        const int count = 4 - column % 4;
        edit.setPosition(position); edit.insertText(QString(count, ' '));
        anchor = position = position + count;
    } else {
        const auto firstBlock = document->findBlock(start);
        // An endpoint at the next line's beginning does not select that line.
        const auto lastBlock = document->findBlock(selected ? end - 1 : end);
        struct Change { int position; int remove; };
        QList<Change> changes;
        for (auto block = firstBlock; block.isValid(); block = block.next()) {
            int remove = 0;
            const auto line = block.text();
            if (reverse) {
                if (line.startsWith('\t')) remove = 1;
                else while (remove < qMin(4, int(line.size())) && line[remove] == ' ') ++remove;
            }
            changes.append({block.position(), remove});
            if (block == lastBlock) break;
        }
        int newStart = firstBlock.position(), newEnd = end;
        auto transform = [](int value, int at, int removed, int inserted) {
            return value < at ? value : qMax(at, value - removed) + inserted;
        };
        for (auto it = changes.crbegin(); it != changes.crend(); ++it) {
            edit.setPosition(it->position);
            if (reverse) {
                edit.setPosition(it->position + it->remove, QTextCursor::KeepAnchor);
                edit.removeSelectedText();
            } else edit.insertText("    ");
            newEnd = transform(newEnd, it->position, it->remove, reverse ? 0 : 4);
            if (!selected) position = transform(position, it->position, it->remove, reverse ? 0 : 4);
        }
        if (selected) {
            if (anchor <= position) { anchor = newStart; position = newEnd; }
            else { anchor = newEnd; position = newStart; }
        } else anchor = position;
    }
    edit.endEditBlock();
    return {{"anchor", anchor}, {"position", position}};
}
}
