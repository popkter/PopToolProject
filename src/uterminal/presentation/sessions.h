#pragma once
#include <QAbstractListModel>
#include <QQuickItem>
#include <QVariantList>
#include "infrastructure/conpty.h"
#include "terminalitem.h"

namespace ut {
class Plugins;
class Settings;
class Scripts;

// A pane owns its process and painted terminal independently of any QML host.
class Pane : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString id MEMBER id CONSTANT)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(bool running READ running NOTIFY changed)
    Q_PROPERTY(QString runtimeLabel READ runtimeLabel NOTIFY changed)
    Q_PROPERTY(QString stateLabel READ stateLabel NOTIFY changed)
    Q_PROPERTY(TerminalItem *terminal READ terminal CONSTANT)
public:
    explicit Pane(QObject *parent=nullptr);
    ~Pane() override;
    QString id, language="powershell", pythonVersion, powerShellVersion;
    QString title() const { return m_title; }
    bool running() const { return process.running(); }
    TerminalItem *terminal() const { return m_terminal; }
    ConPty process;
    void setTitle(const QString &title);
    void captureRuntime();
    QString runtimeLabel() const { return m_runtimeLabel; }
    QString stateLabel() const { return running()?QStringLiteral("运行中"):m_finished?QStringLiteral("已退出 · %1").arg(m_exitCode):QStringLiteral("未启动"); }
signals:
    void changed();
    void ended(int exitCode,const QString &reason);
private:
    QString m_title="PowerShell";
    QString m_runtimeLabel;
    bool m_finished=false;
    int m_exitCode=0;
    TerminalItem *m_terminal;
};

class PaneHost : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(ut::Pane *pane READ pane WRITE setPane NOTIFY paneChanged)
public:
    explicit PaneHost(QQuickItem *parent=nullptr):QQuickItem(parent){}
    ~PaneHost() override;
    Pane *pane() const { return m_pane; }
    void setPane(Pane *pane);
signals:
    void paneChanged();
protected:
    void geometryChange(const QRectF &now,const QRectF &before) override;
private:
    QPointer<Pane> m_pane;
};

class Sessions : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY changed)
    Q_PROPERTY(QVariantList panes READ panes NOTIFY changed)
    Q_PROPERTY(bool vertical READ vertical NOTIFY changed)
    Q_PROPERTY(bool anyRunning READ anyRunning NOTIFY changed)
    Q_PROPERTY(ut::Pane *focusedPane READ focusedPane NOTIFY focusChanged)
    Q_PROPERTY(QString menuText READ menuText NOTIFY menuChanged)
    Q_PROPERTY(ut::Pane *menuPane READ menuPane NOTIFY menuChanged)
public:
    Sessions(Plugins *plugins,Settings *settings,Scripts *scripts,QObject *parent=nullptr);
    ~Sessions() override;
    int rowCount(const QModelIndex &parent={}) const override;
    QVariant data(const QModelIndex &index,int role) const override;
    QHash<int,QByteArray> roleNames() const override;
    int currentIndex() const { return m_current; }
    void setCurrentIndex(int index);
    QVariantList panes() const;
    bool vertical() const;
    bool anyRunning() const;
    Pane *focusedPane() const { return m_focused; }
    QString menuText() const { return m_menuText; }
    Pane *menuPane() const { return m_menuPane; }
    Q_INVOKABLE void newTab();
    Q_INVOKABLE void openDirectory(const QString &path);
    static QString resolveDirectory(const QString &path);
    Q_INVOKABLE void nextTab();
    Q_INVOKABLE void split(bool vertical);
    Q_INVOKABLE void closeTab(int index);
    Q_INVOKABLE void closeOthers(int index);
    Q_INVOKABLE void closeRight(int index);
    Q_INVOKABLE void renameTab(int index,const QString &title);
    Q_INVOKABLE void closePane(ut::Pane *pane);
    Q_INVOKABLE void focusPane(ut::Pane *pane);
    Q_INVOKABLE void endPane(ut::Pane *pane);
    Q_INVOKABLE void interrupt(ut::Pane *pane);
    Q_INVOKABLE void copyMenuSelection();
    Q_INVOKABLE void draftFromSelection();
    Q_INVOKABLE void acceptPaste();
    Q_INVOKABLE void cancelPaste();
    Q_INVOKABLE void closeAll();
    Pane *startProgram(const QString &program,const QStringList &args,const QString &cwd,
                       const QProcessEnvironment &env,const QString &language,const QString &title);
signals:
    void changed();
    void focusChanged();
    void menuChanged();
    void contextMenuRequested(qreal x,qreal y);
    void pasteConfirmationRequested(const QString &text);
    void draftRequested();
    void pluginRequired(const QString &kind);
    void error(const QString &message);
private:
    struct Tab { QString title; bool renamed=false,vertical=false; QList<Pane*> panes; };
    Pane *makePane();
    bool startShell(Pane *pane,const QString &directory=QString());
    void release(Pane *pane);
    void appendTab(Pane *pane,const QString &title);
    QList<Tab> m_tabs;
    int m_current=-1;
    Plugins *m_plugins;
    Settings *m_settings;
    Scripts *m_scripts;
    QPointer<Pane> m_focused,m_menuPane,m_pastePane;
    QString m_menuText,m_pasteText,m_pendingDirectory;
};
}
