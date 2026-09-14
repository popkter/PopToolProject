#pragma once
#include <QJsonArray>
#include <QVariantMap>

namespace ut {
struct ParameterResult {
    QJsonArray parameters;
    QString error;
};
class Parameters {
public:
    static ParameterResult parse(const QString &source, const QJsonArray &metadata = {});
    static QString render(const QString &source, const QVariantMap &values, QString *error, const QJsonArray &metadata = {});
    static QString withDefault(const QString &source, const QString &id, const QString &value);
};
}
