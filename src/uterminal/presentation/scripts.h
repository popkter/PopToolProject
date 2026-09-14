#pragma once
#include <QAbstractListModel>
#include <QJsonObject>
#include <QVariantMap>
#include <QUrl>

namespace ut {
class Scripts : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QVariantMap selected READ selected NOTIFY selectionChanged)
    Q_PROPERTY(QVariantMap draft READ draft NOTIFY draftChanged)
    Q_PROPERTY(QVariantList draftEnvironment READ draftEnvironment NOTIFY draftChanged)
    Q_PROPERTY(QVariantList parameters READ parameters NOTIFY selectionChanged)
    Q_PROPERTY(QVariantMap parameterValues READ parameterValues NOTIFY parameterValuesChanged)
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY filterChanged)
    Q_PROPERTY(QString languageFilter READ languageFilter WRITE setLanguageFilter NOTIFY filterChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY filterChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Roles { IdRole=Qt::UserRole+1,TitleRole,DescriptionRole,LanguageRole,IconRole,SelectedRole,RunningRole,FavoriteRole };
    explicit Scripts(const QString &directory, QObject *parent=nullptr);
    int rowCount(const QModelIndex &parent={}) const override;
    QVariant data(const QModelIndex &index,int role) const override;
    QHash<int,QByteArray> roleNames() const override;
    int count() const { return m_items.size(); }
    QVariantMap selected() const;
    QVariantMap draft() const { return m_draft.toVariantMap(); }
    QVariantList draftEnvironment() const;
    static QString environmentError(const QJsonValue &environment);
    static QString argumentError(const QJsonObject &script);
    static QString parameterSource(const QJsonObject &script);
    static QJsonObject resolvedArgumentConditions(QJsonObject script,const QVariantMap &values);
    Q_INVOKABLE bool setDraftArguments(const QString &json);
    Q_INVOKABLE void setDraftArgument(int index,const QString &value);
    Q_INVOKABLE void removeDraftArgument(int index);
    Q_INVOKABLE bool setDraftEnvironment(const QString &name,const QString &value);
    Q_INVOKABLE void removeDraftEnvironment(const QString &name);
    QVariantList parameters() const;
    QVariantMap parameterValues() const;
    Q_INVOKABLE void setParameterValue(const QString &id,const QString &value);
    Q_INVOKABLE void setBooleanParameter(const QString &id,bool value);
    Q_INVOKABLE bool dropParameterFile(const QString &id,const QList<QUrl> &urls);
    Q_INVOKABLE void resetParameterValues();
    QString query() const { return m_query; }
    QString languageFilter() const { return m_filter; }
    QString sortMode() const { return m_sort; }
    void setQuery(const QString &v);
    void setLanguageFilter(const QString &v);
    void setSortMode(const QString &v);
    Q_INVOKABLE void select(const QString &id);
    Q_INVOKABLE void newDraft(const QString &code=QString(), const QString &language=QStringLiteral("powershell"));
    Q_INVOKABLE void editSelected();
    Q_INVOKABLE void updateDraft(const QString &key,const QVariant &value);
    Q_INVOKABLE bool saveDraft();
    Q_INVOKABLE bool deleteSelected();
    Q_INVOKABLE void toggleFavorite(const QString &id);
    Q_INVOKABLE bool move(const QString &id,int index);
    QStringList customOrder() const;
    Q_INVOKABLE QString exportSelected() const;
    Q_INVOKABLE QVariantMap importText(const QString &text,bool replace=false);
    Q_INVOKABLE bool exportCollection(const QString &directory);
    Q_INVOKABLE QString importCollection(const QString &directory);
    Q_INVOKABLE void setParameterDefault(const QString &id,const QString &value);
    QJsonObject get(const QString &id) const;
    void setRunning(const QString &id,bool running);
    void recordUse(const QString &id);
signals:
    void parameterValuesChanged();
    void selectionChanged();
    void draftChanged();
    void filterChanged();
    void countChanged();
    void error(const QString &message);
    void saved();
private:
    bool persist(QJsonObject item);
    void reload();
    void rebuild();
    void saveState();
    QString m_directory,m_selected,m_query,m_filter="all",m_sort="added_time";
    QJsonObject m_draft,m_state;
    QList<QJsonObject> m_items,m_visible;
    QSet<QString> m_running;
    QHash<QString,QVariantMap> m_parameterInputs;
};
}
