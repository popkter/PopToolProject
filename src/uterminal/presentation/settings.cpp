#include "settings.h"
#include "infrastructure/storage.h"
#include <QGuiApplication>
#include <QStyleHints>
#include <QFontDatabase>

namespace ut {
Settings::Settings(const QString &directory, QObject *parent) : QObject(parent), m_directory(directory) {
    m_data = readJson(directory + "/settings.json");
    if (auto *app = qobject_cast<QGuiApplication *>(QCoreApplication::instance()))
        connect(app->styleHints(), &QStyleHints::colorSchemeChanged, this, &Settings::changed);
}
QString Settings::themeMode() const { return m_data["themeMode"].toString("system"); }
QColor Settings::accent() const { return QColor(m_data["accent"].toString("#0085ff")); }
bool Settings::dark() const {
    const auto *app = qobject_cast<QGuiApplication *>(QCoreApplication::instance());
    return themeMode() == "dark" || (themeMode() == "system" && app && app->styleHints()->colorScheme() == Qt::ColorScheme::Dark);
}
int Settings::fontSize() const { return m_data["fontSize"].toInt(14); }
QStringList Settings::terminalFonts() const {
    static const QStringList fonts=[]{
        QStringList result;
        for(const auto &family:QFontDatabase::families())
            if(!family.startsWith('@')&&QFontDatabase::isFixedPitch(family))result.append(family);
        if(result.isEmpty())result.append(QFontDatabase::systemFont(QFontDatabase::FixedFont).family());
        result.sort(Qt::CaseInsensitive);return result;
    }();
    return fonts;
}
QString Settings::fontFamily() const {
    const auto fonts=terminalFonts();const auto saved=m_data["fontFamily"].toString("Cascadia Mono");
    if(fonts.contains(saved))return saved;
    for(const auto &fallback:QStringList{"Cascadia Mono","Consolas"})if(fonts.contains(fallback))return fallback;
    return fonts.first();
}
QString Settings::terminalScheme() const { const auto value=m_data["terminalScheme"].toString();return QStringList{"slate","light","black"}.contains(value)?value:QStringLiteral("slate"); }
QColor Settings::terminalBackground() const { return QColor(terminalScheme()=="light"?"#fafafa":terminalScheme()=="black"?"#0c0c0c":"#2b313d"); }
QColor Settings::terminalForeground() const { return QColor(terminalScheme()=="light"?"#202020":"#e5e7eb"); }
void Settings::setTerminalScheme(const QString &v) { if(QStringList{"slate","light","black"}.contains(v))setValue("terminalScheme",v); }
int Settings::concurrency() const { return m_data["concurrency"].toInt(3); }
QString Settings::updatePolicy() const { return m_data["updatePolicy"].toString("manual"); }
QString Settings::pluginUpdatePolicy() const { return m_data["pluginUpdatePolicy"].toString("manual"); }
bool Settings::prerelease() const { return m_data["prerelease"].toBool(); }
bool Settings::historyPrediction() const { return m_data["historyPrediction"].toBool(false); }
void Settings::setValue(const QString &key, const QJsonValue &value) {
    auto next = m_data; next[key] = value;
    QString problem;
    if (!writeJson(m_directory + "/settings.json", next, &problem)) { emit error(problem); return; }
    m_data = next; emit changed();
}
void Settings::setThemeMode(const QString &v) { if (QStringList{"system","light","dark"}.contains(v)) setValue("themeMode",v); }
void Settings::setAccent(const QColor &v) { if(v.isValid()) setValue("accent",v.name()); }
void Settings::setFontSize(int v) { setValue("fontSize",qBound(8,v,40)); }
void Settings::setFontFamily(const QString &v) { if(terminalFonts().contains(v)) setValue("fontFamily",v); }
void Settings::setConcurrency(int v) { setValue("concurrency",qBound(1,v,5)); }
void Settings::setUpdatePolicy(const QString &v) { if(QStringList{"manual","startup","daily","weekly"}.contains(v)) setValue("updatePolicy",v); }
void Settings::setPluginUpdatePolicy(const QString &v) { if(QStringList{"manual","daily","weekly"}.contains(v)) setValue("pluginUpdatePolicy",v); }
void Settings::setPrerelease(bool v) { setValue("prerelease",v); }
void Settings::setHistoryPrediction(bool v) { if(v!=historyPrediction())setValue("historyPrediction",v); }
}
