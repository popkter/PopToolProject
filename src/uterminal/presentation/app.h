#pragma once
#include <QObject>
#include <QVariantMap>
#include <QSet>
namespace ut {
class Scripts;class Plugins;class Sessions;class Executions;class PythonEnvironment;class Updates;
class App : public QObject {
    Q_OBJECT
    Q_PROPERTY(int page READ page WRITE setPage NOTIFY pageChanged)
    Q_PROPERTY(QString resources READ resources CONSTANT)
    Q_PROPERTY(QString notice READ notice NOTIFY noticeChanged)
public:
    App(QString resources,Scripts *scripts,Plugins *plugins,Sessions *sessions,Executions *runs,PythonEnvironment *python,Updates *updates,QObject *parent=nullptr);
    int page()const{return m_page;}
    void setPage(int page);
    QString resources()const;
    QString notice()const{return m_notice;}
    Q_INVOKABLE void showNotice(const QString &text);
    Q_INVOKABLE void newScript();
    Q_INVOKABLE void editScript();
    Q_INVOKABLE void shareScript();
    Q_INVOKABLE void importClipboard(bool replace=false);
    Q_INVOKABLE void importCollection();
    Q_INVOKABLE void exportCollection();
    Q_INVOKABLE QString chooseFile();
    Q_INVOKABLE QString chooseDirectory();
    Q_INVOKABLE void copyText(const QString &text);
    Q_INVOKABLE void openDirectory(const QString &path);
    Q_INVOKABLE void showPlugin(const QString &kind);
    Q_INVOKABLE void noteEditorInput();
    Q_INVOKABLE void requestQuit();
    Q_INVOKABLE void quitNow();
signals:
    void pageChanged();
    void noticeChanged();
    void editorRequested();
    void replaceImportRequested();
    void pluginRequested(const QString &kind);
    void quitConfirmationRequested();
private:
    QString m_resources,m_notice,m_import;
    int m_page=0;
    Scripts *m_scripts;Plugins *m_plugins;Sessions *m_sessions;Executions *m_runs;
    PythonEnvironment *m_python;
    Updates *m_updates;
    QSet<QString> m_editorPrompts;
};
}
