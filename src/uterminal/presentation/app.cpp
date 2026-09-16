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
#include <QPlatformSurfaceEvent>
#include <QScopedValueRollback>
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
    if(m_window!=window){
        if(m_window)m_window->removeEventFilter(this);
        m_window=window;m_windowHandle=0;
        if(m_window)m_window->installEventFilter(this);
    }
    if(!m_window)return;
    const auto flags=(m_window->flags()|Qt::FramelessWindowHint)&~Qt::WindowTitleHint;
    if(flags!=m_window->flags())m_window->setFlags(flags);
    initializeNativeWindow();
}
bool App::eventFilter(QObject *object,QEvent *event){
    if(object==m_window){
        if(event->type()==QEvent::PlatformSurface){
            auto *surface=static_cast<QPlatformSurfaceEvent*>(event);
            if(surface->surfaceEventType()==QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed){
                m_windowHandle=0;m_maximizePressed=false;setMaximizeButtonState(false,false);
            }else initializeNativeWindow();
        }else if(event->type()==QEvent::Show)initializeNativeWindow();
    }
    return QObject::eventFilter(object,event);
}
void App::initializeNativeWindow(){
    if(!m_window||m_initializingWindow)return;
    QScopedValueRollback<bool> initializing(m_initializingWindow,true);
    const auto id=m_window->winId();
    if(!id||id==m_windowHandle)return;
    m_windowHandle=id;
    const auto handle=reinterpret_cast<HWND>(id);
    const auto style=GetWindowLongPtrW(handle,GWL_STYLE);
    const auto desired=(style|WS_THICKFRAME|WS_SYSMENU|WS_MINIMIZEBOX|WS_MAXIMIZEBOX)&~WS_CAPTION;
    if(style!=desired)SetWindowLongPtrW(handle,GWL_STYLE,desired);
    // DWM owns the outside shadow and corners; QML owns the entire titlebar.
    const DWMNCRENDERINGPOLICY policy=DWMNCRP_ENABLED;
    DwmSetWindowAttribute(handle,DWMWA_NCRENDERING_POLICY,&policy,sizeof(policy));
    const MARGINS margins{1,1,1,1};
    DwmExtendFrameIntoClientArea(handle,&margins);
    updateWindowAppearance(m_darkWindow);
    SetWindowPos(handle,nullptr,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE|SWP_FRAMECHANGED);
}
void App::updateWindowAppearance(bool dark){
    m_darkWindow=dark;
    if(!m_windowHandle)return;
    const auto handle=reinterpret_cast<HWND>(m_windowHandle);const BOOL enabled=dark;
    DwmSetWindowAttribute(handle,DWMWA_USE_IMMERSIVE_DARK_MODE,&enabled,sizeof(enabled));
    const DWM_WINDOW_CORNER_PREFERENCE corners=DWMWCP_ROUND;
    DwmSetWindowAttribute(handle,DWMWA_WINDOW_CORNER_PREFERENCE,&corners,sizeof(corners));
}
bool App::startSystemMove(QQuickWindow *window){return window&&window->startSystemMove();}
void App::registerCaptionItem(QQuickItem *item){if(item&&!m_captionItems.contains(item))m_captionItems.append(item);}
void App::registerCaptionControls(QQuickItem *item){
    m_captionControls=item;

}
bool App::maximizeButtonContains(const QPointF &scene)const{
    if(!m_captionControls||!m_modals.isEmpty())return false;
    auto *button=qvariant_cast<QQuickItem*>(m_captionControls->property("maximizeButton"));
    return button&&button->isVisible()&&button->isEnabled()&&button->contains(button->mapFromScene(scene));
}
void App::setMaximizeButtonState(bool hovered,bool pressed){
    if(!m_captionControls)return;
    m_captionControls->setProperty("nativeMaximizeHovered",hovered);
    m_captionControls->setProperty("nativeMaximizePressed",pressed);
}
bool App::nativeEventFilter(const QByteArray &,void *nativeMessage,qintptr *result){
    const auto *message=static_cast<MSG*>(nativeMessage);
    if(!message||!m_window||message->hwnd!=reinterpret_cast<HWND>(m_windowHandle))return false;
    if(m_captionControls){
        const auto type=message->message;
        if(type==WM_NCMOUSEMOVE){
            setMaximizeButtonState(message->wParam==HTMAXBUTTON,m_maximizePressed);
            TRACKMOUSEEVENT tracking{sizeof(TRACKMOUSEEVENT),TME_LEAVE|TME_NONCLIENT,message->hwnd,0};
            TrackMouseEvent(&tracking);
            // Continue to DwmDefWindowProc/DefWindowProc so Windows can show
            // its Snap Layouts flyout for this HTMAXBUTTON region.
        }else if((type==WM_NCLBUTTONDOWN||type==WM_NCLBUTTONDBLCLK)&&message->wParam==HTMAXBUTTON){
            m_maximizePressed=true;setMaximizeButtonState(true,true);
            SetCapture(message->hwnd);
            if(result)*result=0;return true;
        }else if(m_maximizePressed&&(type==WM_MOUSEMOVE||type==WM_LBUTTONUP)){
            const auto scale=m_window->devicePixelRatio();
            const bool inside=maximizeButtonContains(QPointF(GET_X_LPARAM(message->lParam)/scale,GET_Y_LPARAM(message->lParam)/scale));
            if(type==WM_LBUTTONUP){
                m_maximizePressed=false;
                ReleaseCapture();setMaximizeButtonState(inside,false);
                if(inside){if(m_window->windowStates()&Qt::WindowMaximized)m_window->showNormal();else m_window->showMaximized();}
            }else setMaximizeButtonState(inside,inside);
            if(result)*result=0;return true;
        }else if(type==WM_CAPTURECHANGED||type==WM_CANCELMODE){
            m_maximizePressed=false;setMaximizeButtonState(false,false);
        }else if(type==WM_NCMOUSELEAVE||type==WM_MOUSEMOVE){
            setMaximizeButtonState(false,m_maximizePressed);
        }
    }
    if(message->message==WM_STYLECHANGING&&message->wParam==WPARAM(GWL_STYLE)){
        auto *style=reinterpret_cast<STYLESTRUCT*>(message->lParam);
        style->styleNew=(style->styleNew|WS_THICKFRAME|WS_SYSMENU|WS_MINIMIZEBOX|WS_MAXIMIZEBOX)&~WS_CAPTION;
        if(result)*result=0;return true;
    }
    if(message->message==WM_NCLBUTTONDOWN&&
       (message->wParam==HTCAPTION||(message->wParam>=HTLEFT&&message->wParam<=HTBOTTOMRIGHT))){
        // Qt's frameless path does not start native move/size tracking itself.
        const auto nativeResult=DefWindowProcW(message->hwnd,message->message,message->wParam,message->lParam);
        if(result)*result=nativeResult;
        return true;
    }
    if(message->message==WM_NCLBUTTONDBLCLK&&message->wParam==HTCAPTION){
        if(m_window->windowStates()&Qt::WindowMaximized)m_window->showNormal();else m_window->showMaximized();
        if(result)*result=0;return true;
    }
    if(message->message==WM_NCMOUSEMOVE||message->message==WM_NCMOUSELEAVE){
        LRESULT nativeResult=0;
        if(DwmDefWindowProc(message->hwnd,message->message,message->wParam,message->lParam,&nativeResult)){
            if(result)*result=nativeResult;return true;
        }
        if(message->message==WM_NCMOUSEMOVE&&message->wParam==HTMAXBUTTON){
            const auto nativeResult=DefWindowProcW(message->hwnd,message->message,message->wParam,message->lParam);
            if(result)*result=nativeResult;
            return true;
        }
    }
    if(message->message==WM_NCPAINT){if(result)*result=0;return true;}
    if(message->message==WM_NCACTIVATE){
        // Preserve native activation bookkeeping without painting a classic caption.
        const auto nativeResult=DefWindowProcW(message->hwnd,message->message,message->wParam,-1);
        if(result)*result=nativeResult;
        return true;
    }
    if(message->message==WM_NCCALCSIZE){
        auto *client=message->wParam?&reinterpret_cast<NCCALCSIZE_PARAMS*>(message->lParam)->rgrc[0]
                                   :reinterpret_cast<RECT*>(message->lParam);
        if(IsZoomed(message->hwnd)){
            MONITORINFO monitor{sizeof(MONITORINFO)};
            if(GetMonitorInfoW(MonitorFromWindow(message->hwnd,MONITOR_DEFAULTTONEAREST),&monitor))*client=monitor.rcWork;
        }
        if(result)*result=0;return true;
    }
    if(message->message==WM_GETMINMAXINFO){
        auto *limits=reinterpret_cast<MINMAXINFO*>(message->lParam);
        MONITORINFO monitor{sizeof(MONITORINFO)};
        if(GetMonitorInfoW(MonitorFromWindow(message->hwnd,MONITOR_DEFAULTTONEAREST),&monitor)){
            limits->ptMaxPosition={monitor.rcWork.left-monitor.rcMonitor.left,monitor.rcWork.top-monitor.rcMonitor.top};
            limits->ptMaxSize={monitor.rcWork.right-monitor.rcWork.left,monitor.rcWork.bottom-monitor.rcWork.top};
        }
        const auto scale=m_window->devicePixelRatio();
        limits->ptMinTrackSize={qRound(m_window->minimumWidth()*scale),qRound(m_window->minimumHeight()*scale)};
        const auto dpi=GetDpiForWindow(message->hwnd);
        limits->ptMaxTrackSize.x=qMin(GetSystemMetricsForDpi(SM_CXMAXTRACK,dpi),qRound(m_window->maximumWidth()*scale));
        limits->ptMaxTrackSize.y=qMin(GetSystemMetricsForDpi(SM_CYMAXTRACK,dpi),qRound(m_window->maximumHeight()*scale));
        if(result)*result=0;return true;
    }
    if(message->message==WM_NCHITTEST){
        POINT point{GET_X_LPARAM(message->lParam),GET_Y_LPARAM(message->lParam)};
        if(!ScreenToClient(message->hwnd,&point))return false;
        RECT client{};GetClientRect(message->hwnd,&client);
        const auto dpi=GetDpiForWindow(message->hwnd);
        const int borderX=GetSystemMetricsForDpi(SM_CXSIZEFRAME,dpi)+GetSystemMetricsForDpi(SM_CXPADDEDBORDER,dpi);
        const int borderY=GetSystemMetricsForDpi(SM_CYSIZEFRAME,dpi)+GetSystemMetricsForDpi(SM_CXPADDEDBORDER,dpi);
        const bool resizable=!IsZoomed(message->hwnd)&&!(m_window->windowStates()&(Qt::WindowMaximized|Qt::WindowFullScreen));
        const bool left=resizable&&point.x<borderX,right=resizable&&point.x>=client.right-borderX;
        const bool top=resizable&&point.y<borderY,bottom=resizable&&point.y>=client.bottom-borderY;
        const auto scale=m_window->devicePixelRatio();const QPointF scene(point.x/scale,point.y/scale);
        int hit=HTCLIENT;
        if(top&&(left||right))hit=left?HTTOPLEFT:HTTOPRIGHT;
        else if(bottom&&(left||right))hit=left?HTBOTTOMLEFT:HTBOTTOMRIGHT;
        else if(m_captionControls&&m_captionControls->contains(m_captionControls->mapFromScene(scene)))hit=maximizeButtonContains(scene)?HTMAXBUTTON:HTCLIENT;
        else if(left)hit=HTLEFT;else if(right)hit=HTRIGHT;else if(top)hit=HTTOP;else if(bottom)hit=HTBOTTOM;
        else if(m_modals.isEmpty()){
            for(const auto &item:m_captionItems)if(item&&item->isVisible()&&item->contains(item->mapFromScene(scene))){hit=HTCAPTION;break;}
        }
        if(result)*result=hit;return true;
    }    if((message->message==WM_NCRBUTTONDOWN||message->message==WM_NCRBUTTONUP)&&message->wParam==HTCAPTION){
        if(result)*result=0;return true;
    }
    if(message->message==WM_SYSCOMMAND&&(message->wParam&0xfff0)==SC_MINIMIZE){
        // Frameless extended-client windows are not minimized reliably by every
        // taskbar path. Honor the native system command explicitly.
        ShowWindow(message->hwnd,SW_MINIMIZE);
        if(result)*result=0;
        return true;
    }
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
