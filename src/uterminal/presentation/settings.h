#pragma once
#include <QObject>
#include <QJsonObject>
#include <QColor>

namespace ut {
class Settings : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY changed)
    Q_PROPERTY(QColor accent READ accent WRITE setAccent NOTIFY changed)
    Q_PROPERTY(bool dark READ dark NOTIFY changed)
    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY changed)
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY changed)
    Q_PROPERTY(QStringList terminalFonts READ terminalFonts CONSTANT)
    Q_PROPERTY(QString terminalScheme READ terminalScheme WRITE setTerminalScheme NOTIFY changed)
    Q_PROPERTY(QColor terminalBackground READ terminalBackground NOTIFY changed)
    Q_PROPERTY(QColor terminalForeground READ terminalForeground NOTIFY changed)
    Q_PROPERTY(int concurrency READ concurrency WRITE setConcurrency NOTIFY changed)
    Q_PROPERTY(QString updatePolicy READ updatePolicy WRITE setUpdatePolicy NOTIFY changed)
    Q_PROPERTY(QString pluginUpdatePolicy READ pluginUpdatePolicy WRITE setPluginUpdatePolicy NOTIFY changed)
    Q_PROPERTY(bool prerelease READ prerelease WRITE setPrerelease NOTIFY changed)
    Q_PROPERTY(bool historyPrediction READ historyPrediction WRITE setHistoryPrediction NOTIFY changed)
    Q_PROPERTY(QString directory READ directory CONSTANT)
public:
    explicit Settings(const QString &directory, QObject *parent = nullptr);
    QString directory() const { return m_directory; }
    QString themeMode() const;
    QColor accent() const;
    bool dark() const;
    int fontSize() const;
    QString fontFamily() const;
    QStringList terminalFonts() const;
    QString terminalScheme() const;
    QColor terminalBackground() const;
    QColor terminalForeground() const;
    void setTerminalScheme(const QString &value);
    int concurrency() const;
    QString updatePolicy() const;
    QString pluginUpdatePolicy() const;
    bool prerelease() const;
    bool historyPrediction() const;
    void setThemeMode(const QString &value);
    void setAccent(const QColor &value);
    void setFontSize(int value);
    void setFontFamily(const QString &value);
    void setConcurrency(int value);
    void setUpdatePolicy(const QString &value);
    void setPluginUpdatePolicy(const QString &value);
    void setPrerelease(bool value);
    void setHistoryPrediction(bool value);
    QJsonValue value(const QString &key) const { return m_data.value(key); }
    void setValue(const QString &key, const QJsonValue &value);
signals:
    void changed();
    void error(const QString &message);
private:
    QString m_directory;
    QJsonObject m_data;
};
}
