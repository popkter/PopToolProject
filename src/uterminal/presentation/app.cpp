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
#include <QQuickItem>
#include <QTimer>
#include <utility>
#include "infrastructure/instance.h"
#include <windows.h>
#include <windowsx.h>
#include <dwmapi.h>
namespace ut {
App::App(QString resources,Scripts *scripts,Plugins *plugins,Sessions *sessions,Executions *runs,PythonEnvironment *python,Updates *updates,QObject *parent)
    :QObject(parent),m_resources(std::move(resources)),m_scripts(scripts),m_plugins(plugins),m_sessions(sessions),m_runs(runs),m_python(python),m_updates(updates){
    connect(scripts,&Scripts::error,this,&App::showNotice);connect(plugins,&Plugins::error,this,&App::showNotice);
    connect(sessions,&Sessions::error,this,&App::showNotice);connect(runs,&Executions::error,this,&App::showNotice);
    connect(runs,&Executions::pluginRequired,this,&App::showPlugin);connect(sessions,&Sessions::pluginRequired,this,&App::showPlugin);
    connect(sessions,&Sessions::draftRequested,this,[this]{setPage(0);emit editorRequested();});
    connect(runs,&Executions::interactiveStarted,this,[this]{setPage(1);});
    if(auto *application=QCoreApplication::instance())application->installNativeEventFilter(this);
}
App::~App(){if(auto *application=QCoreApplication::instance())application->removeNativeEventFilter(this);}
QString App::resources()const{return QUrl::fromLocalFile(m_resources+'/').toString();}
void App::setPage(int p){if(p<0||p>2)return;bool entering=p!=m_page;m_page=p;emit pageChanged();if(entering&&p==1&&!m_plugins->powerShellReady()&&m_sessions->rowCount()==0)showPlugin("powershell");}
bool App::elevated()const{return processElevated();}
void App::attachWindow(QQuickWindow *window){
    m_window=window;m_windowHandle=window?window->winId():0;
    if(!m_windowHandle)return;
    const auto handle=reinterpret_cast<HWND>(m_windowHandle);
    const DWMNCRENDERINGPOLICY policy=DWMNCRP_ENABLED;
    DwmSetWindowAttribute(handle,DWMWA_NCRENDERING_POLICY,&policy,sizeof(policy));
    const MARGINS margins{0,0,qRound(42*window->devicePixelRatio()),0};
    DwmExtendFrameIntoClientArea(handle,&margins);
    SetWindowPos(handle,nullptr,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_FRAMECHANGED);
    refreshCaptionMetrics();
}
void App::updateTitleBar(QQuickWindow *window,bool dark,const QColor &background,const QColor &text){
    if(!window)return;
    const auto handle=reinterpret_cast<HWND>(window->winId());const BOOL enabled=dark;
    const COLORREF caption=RGB(background.red(),background.green(),background.blue());
    DwmSetWindowAttribute(handle,DWMWA_USE_IMMERSIVE_DARK_MODE,&enabled,sizeof(enabled));
    DwmSetWindowAttribute(handle,DWMWA_CAPTION_COLOR,&caption,sizeof(caption));
    // Leave caption glyph colors under DWM control so their hover and pressed
    // states always contrast with the system-provided button background.
    const COLORREF automatic=DWMWA_COLOR_DEFAULT;
    DwmSetWindowAttribute(handle,DWMWA_TEXT_COLOR,&automatic,sizeof(automatic));
    const DWM_WINDOW_CORNER_PREFERENCE corners=DWMWCP_ROUND;
    DwmSetWindowAttribute(handle,DWMWA_WINDOW_CORNER_PREFERENCE,&corners,sizeof(corners));
    RedrawWindow(handle,nullptr,nullptr,RDW_FRAME|RDW_INVALIDATE);
    Q_UNUSED(text);
}
bool App::startSystemMove(QQuickWindow *window){return window&&window->startSystemMove();}
void App::registerCaptionItem(QQuickItem *item){if(item&&!m_captionItems.contains(item))m_captionItems.append(item);}
void App::refreshCaptionMetrics(){
    if(!m_windowHandle||!m_window)return;
    RECT bounds{},frame{},client{};const auto handle=reinterpret_cast<HWND>(m_windowHandle);
    if(!IsWindowVisible(handle)||IsIconic(handle))return;
    if(DwmGetWindowAttribute(handle,DWMWA_CAPTION_BUTTON_BOUNDS,&bounds,sizeof(bounds))!=S_OK||bounds.bottom<=bounds.top)return;
    POINT origin{};
    if(!GetWindowRect(handle,&frame)||!GetClientRect(handle,&client)||!ClientToScreen(handle,&origin))return;
    // DWM returns window-relative physical pixels; QML lays out in client-relative
    // logical pixels. Keep the frame offset, especially when maximized.
    const auto scale=m_window->devicePixelRatio();
    const bool nativeButtons=bounds.right>bounds.left;
    const auto top=nativeButtons?qMax(0.0,qreal(frame.top+bounds.top-origin.y)/scale):0.0;
    // Qt's expanded titlebar can draw its own buttons, leaving a zero-width
    // DWM rectangle. Its safe-area margin is used by QML in that case.
    const auto inset=nativeButtons?qreal(client.right-(frame.left+bounds.left-origin.x))/scale:138.0;
    if(inset<=0)return;
    if(qAbs(top-m_captionTop)<0.01&&qAbs(inset-m_captionInset)<0.01)return;
    m_captionTop=top;m_captionInset=inset;emit captionMetricsChanged();
}
int App::captionButtonHitTest(quintptr windowHandle,qintptr position)const{
    const auto window=reinterpret_cast<HWND>(windowHandle);
    RECT buttons{},frame{};
    if(DwmGetWindowAttribute(window,DWMWA_CAPTION_BUTTON_BOUNDS,&buttons,sizeof(buttons))!=S_OK||
       !GetWindowRect(window,&frame)||buttons.right<=buttons.left||buttons.bottom<=buttons.top)return HTNOWHERE;
    const POINT point{GET_X_LPARAM(position)-frame.left,GET_Y_LPARAM(position)-frame.top};
    if(point.x<buttons.left||point.x>=buttons.right||point.y<buttons.top||point.y>=buttons.bottom)return HTNOWHERE;
    const auto width=qMax<LONG>(1,(buttons.right-buttons.left)/3);
    if(point.x>=buttons.right-width)return HTCLOSE;
    if(point.x>=buttons.right-2*width)return HTMAXBUTTON;
    return HTMINBUTTON;
}
bool App::nativeEventFilter(const QByteArray &,void *nativeMessage,qintptr *result){
    const auto *message=static_cast<MSG*>(nativeMessage);
    if(!message||!m_window||message->hwnd!=reinterpret_cast<HWND>(m_windowHandle))return false;
    if(message->message==WM_NCMOUSEMOVE||message->message==WM_NCMOUSELEAVE||
       message->message==WM_NCLBUTTONDOWN||message->message==WM_NCLBUTTONUP||
       message->message==WM_NCLBUTTONDBLCLK){
        LRESULT nativeResult=0;
        if(DwmDefWindowProc(message->hwnd,message->message,message->wParam,message->lParam,&nativeResult)){
            if(result)*result=nativeResult;
            return true;
        }
        if(message->wParam==HTMINBUTTON||message->wParam==HTMAXBUTTON||message->wParam==HTCLOSE){
            nativeResult=DefWindowProcW(message->hwnd,message->message,message->wParam,message->lParam);
            if(result)*result=nativeResult;
            return true;
        }
    }
    if(message->message==WM_NCPAINT||message->message==WM_NCACTIVATE){
        const auto nativeResult=DefWindowProcW(message->hwnd,message->message,message->wParam,message->lParam);
        if(result)*result=nativeResult;return true;
    }
    if(message->message==WM_NCCALCSIZE&&message->wParam){
        auto *params=reinterpret_cast<NCCALCSIZE_PARAMS*>(message->lParam);
        const auto dpi=GetDpiForWindow(message->hwnd);
        const int borderX=GetSystemMetricsForDpi(SM_CXSIZEFRAME,dpi)+GetSystemMetricsForDpi(SM_CXPADDEDBORDER,dpi);
        const int borderY=GetSystemMetricsForDpi(SM_CYSIZEFRAME,dpi)+GetSystemMetricsForDpi(SM_CXPADDEDBORDER,dpi);
        params->rgrc[0].left+=borderX;params->rgrc[0].right-=borderX;params->rgrc[0].bottom-=borderY;
        if(IsZoomed(message->hwnd))params->rgrc[0].top+=borderY;
        if(result)*result=0;return true;
    }
    if(message->message==WM_NCHITTEST){
        LRESULT dwmResult=HTNOWHERE;
        if(DwmDefWindowProc(message->hwnd,message->message,message->wParam,message->lParam,&dwmResult)&&
           (dwmResult==HTMINBUTTON||dwmResult==HTMAXBUTTON||dwmResult==HTCLOSE)){
            if(result)*result=dwmResult;return true;
        }
        const auto button=captionButtonHitTest(reinterpret_cast<quintptr>(message->hwnd),message->lParam);
        if(button!=HTNOWHERE){if(result)*result=button;return true;}
        POINT point{GET_X_LPARAM(message->lParam),GET_Y_LPARAM(message->lParam)};
        if(ScreenToClient(message->hwnd,&point)){
            const auto dpi=GetDpiForWindow(message->hwnd);
            if(!IsZoomed(message->hwnd)&&point.y>=0&&point.y<GetSystemMetricsForDpi(SM_CYSIZEFRAME,dpi)){
                if(result)*result=HTTOP;return true;
            }
            const auto scale=m_window->devicePixelRatio();const QPointF scene(point.x/scale,point.y/scale);
            for(const auto &item:m_captionItems)if(item&&item->isVisible()&&item->contains(item->mapFromScene(scene))){
                if(result)*result=HTCAPTION;return true;
            }
        }
        return false;
    }
    if((message->message==WM_NCRBUTTONDOWN||message->message==WM_NCRBUTTONUP)&&message->wParam==HTCAPTION){
        if(result)*result=0;return true;
    }
    if(message->message==WM_SYSCOMMAND&&(message->wParam&0xfff0)==SC_MINIMIZE){
        // Frameless extended-client windows are not minimized reliably by every
        // taskbar path. Honor the native system command explicitly.
        ShowWindow(message->hwnd,SW_MINIMIZE);
        if(result)*result=0;
        return true;
    }
    if(message->message==WM_DPICHANGED){
        const MARGINS margins{0,0,MulDiv(42,HIWORD(message->wParam),96),0};
        DwmExtendFrameIntoClientArea(message->hwnd,&margins);
    }
    if(message->message==WM_DPICHANGED||message->message==WM_WINDOWPOSCHANGED)QTimer::singleShot(0,this,&App::refreshCaptionMetrics);
    return false;
}
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
