#include "app.h"
#include "scripts.h"
#include "sessions.h"
#include "application/plugins.h"
#include "application/executions.h"
#include "application/pythonenvironment.h"
#include "application/updates.h"
#include <QApplication>
#include <QClipboard>
#include <QDesktopServices>
#include <QFileDialog>
#include <QUrl>
#include <QQuickWindow>
#include <QTimer>
#include <utility>
#include "infrastructure/instance.h"
#include <windows.h>
#include <dwmapi.h>
namespace ut {
App::App(QString resources,Scripts *scripts,Plugins *plugins,Sessions *sessions,Executions *runs,PythonEnvironment *python,Updates *updates,QObject *parent)
    :QObject(parent),m_resources(std::move(resources)),m_scripts(scripts),m_plugins(plugins),m_sessions(sessions),m_runs(runs),m_python(python),m_updates(updates){
    connect(scripts,&Scripts::error,this,&App::showNotice);connect(plugins,&Plugins::error,this,&App::showNotice);
    connect(sessions,&Sessions::error,this,&App::showNotice);connect(runs,&Executions::error,this,&App::showNotice);
    connect(runs,&Executions::pluginRequired,this,&App::showPlugin);connect(sessions,&Sessions::pluginRequired,this,&App::showPlugin);
    connect(sessions,&Sessions::draftRequested,this,[this]{setPage(0);emit editorRequested();});
    connect(runs,&Executions::interactiveStarted,this,[this]{setPage(1);});
}
QString App::resources()const{return QUrl::fromLocalFile(m_resources+'/').toString();}
void App::setPage(int p){if(p<0||p>2)return;bool entering=p!=m_page;m_page=p;emit pageChanged();if(entering&&p==1&&!m_plugins->powerShellReady()&&m_sessions->rowCount()==0)showPlugin("powershell");}
bool App::elevated()const{return processElevated();}
void App::attachWindow(QQuickWindow *window){m_window=window;}
void App::updateTitleBar(QQuickWindow *window,bool dark,const QColor &background,const QColor &text){
    if(!window)return;
    const auto handle=reinterpret_cast<HWND>(window->winId());const BOOL enabled=dark;
    const COLORREF caption=RGB(background.red(),background.green(),background.blue()),foreground=RGB(text.red(),text.green(),text.blue());
    DwmSetWindowAttribute(handle,DWMWA_USE_IMMERSIVE_DARK_MODE,&enabled,sizeof(enabled));
    DwmSetWindowAttribute(handle,DWMWA_CAPTION_COLOR,&caption,sizeof(caption));
    DwmSetWindowAttribute(handle,DWMWA_TEXT_COLOR,&foreground,sizeof(foreground));
    const DWM_WINDOW_CORNER_PREFERENCE corners=DWMWCP_ROUND;
    DwmSetWindowAttribute(handle,DWMWA_WINDOW_CORNER_PREFERENCE,&corners,sizeof(corners));
    RedrawWindow(handle,nullptr,nullptr,RDW_FRAME|RDW_INVALIDATE);
}
bool App::startSystemMove(QQuickWindow *window){return window&&window->startSystemMove();}
void App::activateWindow(){
    if(!m_window)return;
    m_window->setWindowStates(m_window->windowStates()&~Qt::WindowMinimized);m_window->show();m_window->requestActivate();
    QTimer::singleShot(200,this,[this]{if(m_window&&!m_window->isActive())m_window->alert(0);});
}
void App::handleLaunch(const QJsonObject &request){
    if(m_quitting)return;
    activateWindow();
    if(request["operation"].toString()!="openDirectory")return;
    m_externalTerminal=true;
    if(auto *pane=m_sessions->openDirectoryTab(request["directory"].toString(),false,false))m_externalPane=pane;
    if(!m_plugins->powerShellReady())m_deferredPlugin="powershell";
    finishExternalActivation();
}
void App::setModalOpen(QObject *dialog,bool open){
    if(!dialog)return;
    if(open){
        if(m_modals.contains(dialog))return;
        m_modals.insert(dialog,connect(dialog,&QObject::destroyed,this,[this,dialog]{m_modals.remove(dialog);QTimer::singleShot(0,this,&App::finishExternalActivation);}));
    }else if(m_modals.contains(dialog))disconnect(m_modals.take(dialog));
    QTimer::singleShot(0,this,&App::finishExternalActivation);
}
void App::finishExternalActivation(){
    if(m_quitting||!m_modals.isEmpty())return;
    if(m_externalTerminal){
        m_externalTerminal=false;
        // Avoid the ordinary page-entry prompt; a pending runtime prompt is handled below.
        m_page=1;emit pageChanged();
        if(m_externalPane){m_sessions->activatePaneTab(m_externalPane);m_externalPane=nullptr;}
    }
    if(!m_deferredPlugin.isEmpty()){
        const auto kind=std::exchange(m_deferredPlugin,{});
        if((kind=="powershell"&&!m_plugins->powerShellReady())||(kind=="python"&&!m_plugins->pythonReady()))emit pluginRequested(kind);
    }
}
void App::showNotice(const QString &text){m_notice=text;emit noticeChanged();}
void App::newScript(){m_scripts->newDraft();emit editorRequested();}
void App::editScript(){if(m_scripts->selected().isEmpty())return;m_scripts->editSelected();emit editorRequested();}
void App::shareScript(){auto text=m_scripts->exportSelected();if(!text.isEmpty()){copyText(text);showNotice(QStringLiteral("脚本 JSON 已复制"));}}
void App::importClipboard(bool replace){if(!replace)m_import=QApplication::clipboard()->text();auto result=m_scripts->importText(m_import,replace);if(result["status"]=="duplicate")emit replaceImportRequested();else showNotice(result["status"]=="ok"?QStringLiteral("脚本已导入"):result["message"].toString());}
void App::importCollection(){auto dir=chooseDirectory();if(!dir.isEmpty())showNotice(m_scripts->importCollection(dir));}
void App::exportCollection(){auto dir=chooseDirectory();if(!dir.isEmpty()&&m_scripts->exportCollection(dir))showNotice(QStringLiteral("脚本集合已导出"));}
QString App::chooseFile(){QObject modal;setModalOpen(&modal,true);const auto path=QFileDialog::getOpenFileName(nullptr,QStringLiteral("选择文件"));setModalOpen(&modal,false);return path;}
QString App::chooseDirectory(){QObject modal;setModalOpen(&modal,true);const auto path=QFileDialog::getExistingDirectory(nullptr,QStringLiteral("选择目录"));setModalOpen(&modal,false);return path;}
void App::copyText(const QString &text){QApplication::clipboard()->setText(text);}
void App::openDirectory(const QString &path){QDesktopServices::openUrl(QUrl::fromLocalFile(path));}
void App::showPlugin(const QString &kind){if(!m_modals.isEmpty())m_deferredPlugin=kind;else emit pluginRequested(kind);}
void App::noteEditorInput(){
    const auto draft=m_scripts->draft();const auto kind=draft["language"].toString();
    if(draft["code"].toString().isEmpty()||m_editorPrompts.contains(kind))return;
    if((kind=="python"&&!m_plugins->pythonReady())||(kind=="powershell"&&!m_plugins->powerShellReady())){
        m_editorPrompts.insert(kind);emit pluginRequested(kind);
    }
}
void App::requestQuit(){if(m_sessions->anyRunning()||m_runs->runningCount()>0||m_plugins->busy()||m_python->busy()||m_updates->downloading())emit quitConfirmationRequested();else quitNow();}
void App::quitNow(){m_quitting=true;emit quitting();m_deferredPlugin.clear();m_externalPane=nullptr;m_updates->cancelDownload();m_python->cancel();m_plugins->cancel();m_runs->stopAll();m_sessions->closeAll();QApplication::quit();}
}
