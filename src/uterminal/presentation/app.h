#pragma once
#include <QObject>
#include <QVariantMap>
#include <QSet>
#include <QPointer>
#include <QJsonObject>
#include <QColor>
#include <QAbstractNativeEventFilter>
#include <QRect>
class QQuickWindow;
class QQuickItem;
namespace ut {
class Scripts;class Plugins;class Sessions;class Executions;class PythonEnvironment;class Updates;class Pane;
class App : public QObject, public QAbstractNativeEventFilter {
    Q_OBJECT
    Q_PROPERTY(int page READ page WRITE setPage NOTIFY pageChanged)
    Q_PROPERTY(QString resources READ resources CONSTANT)
    Q_PROPERTY(QString notice READ notice NOTIFY noticeChanged)
    Q_PROPERTY(bool elevated READ elevated CONSTANT)
    Q_PROPERTY(qreal captionHeight READ captionHeight NOTIFY captionMetricsChanged)
    Q_PROPERTY(qreal captionTop READ captionTop NOTIFY captionMetricsChanged)
    Q_PROPERTY(qreal captionInset READ captionInset NOTIFY captionMetricsChanged)
public:
    App(QString resources,Scripts *scripts,Plugins *plugins,Sessions *sessions,Executions *runs,PythonEnvironment *python,Updates *updates,QObject *parent=nullptr);
    ~App() override;
    int page()const{return m_page;}
    void setPage(int page);
    QString resources()const;
    QString notice()const{return m_notice;}
    bool elevated()const;
    qreal captionHeight()const{return m_captionHeight;}
    qreal captionTop()const{return m_captionTop;}
    qreal captionInset()const{return m_captionInset;}
    void attachWindow(QQuickWindow *window);
    Q_INVOKABLE void updateTitleBar(QQuickWindow *window,bool dark,const QColor &background,const QColor &text);
    Q_INVOKABLE bool startSystemMove(QQuickWindow *window);
    Q_INVOKABLE void registerCaptionItem(QQuickItem *item);
    void handleLaunch(const QJsonObject &request);
    Q_INVOKABLE void setModalOpen(QObject *dialog,bool open);
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
    bool nativeEventFilter(const QByteArray &eventType,void *message,qintptr *result) override;
signals:
    void pageChanged();
    void noticeChanged();
    void editorRequested();
    void replaceImportRequested();
    void pluginRequested(const QString &kind);
    void quitConfirmationRequested();
    void quitting();
    void captionMetricsChanged();
private:
    void finishExternalActivation();
    void activateWindow();
    void refreshCaptionMetrics();
    int captionButtonHitTest(quintptr window,qintptr position) const;
    QPointer<QQuickWindow> m_window;
    quintptr m_windowHandle=0;
    QList<QPointer<QQuickItem>> m_captionItems;
    qreal m_captionHeight=32;
    qreal m_captionTop=0,m_captionInset=138;
    QPointer<Pane> m_externalPane;
    QHash<QObject*,QMetaObject::Connection> m_modals;
    QString m_deferredPlugin;
    bool m_externalTerminal=false,m_quitting=false;
    QString m_resources,m_notice,m_import;
    int m_page=1;
    Scripts *m_scripts;Plugins *m_plugins;Sessions *m_sessions;Executions *m_runs;
    PythonEnvironment *m_python;
    Updates *m_updates;
    QSet<QString> m_editorPrompts;
};
}
