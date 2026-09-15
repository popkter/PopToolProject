#include <QtTest>
#include <QClipboard>
#include <QGuiApplication>
#include <QMouseEvent>
#include <QMimeData>
#include <QDragEnterEvent>
#include <QDropEvent>
#include <QPainter>
#include <QQuickWindow>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include "infrastructure/conpty.h"
#include "infrastructure/processrunner.h"
#include "presentation/sessions.h"
#include "presentation/scripts.h"
#include "presentation/settings.h"
#include "presentation/app.h"
#include "infrastructure/instance.h"
#include "application/plugins.h"
#include "application/executions.h"
#include "application/updates.h"
#include "presentation/scripthighlighter.h"
#include "presentation/scriptediting.h"
#include <QTextBlock>
#include <QTextLayout>
#include <windows.h>
#include <dwmapi.h>
#include <QJsonDocument>
#include <QCryptographicHash>
#include <QScreen>
#include <QScopeGuard>
#include "infrastructure/storage.h"

class CatalogTestReply:public QNetworkReply {
    QByteArray body;
    qint64 offset=0;
public:
    CatalogTestReply(const QNetworkRequest &request,QObject *parent):QNetworkReply(parent){setRequest(request);setUrl(request.url());open(QIODevice::ReadOnly);}
    void finish(const QByteArray &data,NetworkError failure=NoError){
        body=data;if(failure!=NoError)setError(failure,QStringLiteral("测试网络错误"));
        setFinished(true);if(!body.isEmpty())emit readyRead();emit finished();
    }
    void abort()override{if(!isFinished())finish({},OperationCanceledError);}
    qint64 bytesAvailable()const override{return body.size()-offset+QNetworkReply::bytesAvailable();}
protected:
    qint64 readData(char *data,qint64 maximum)override{
        const auto count=qMin(maximum,qint64(body.size())-offset);if(count<=0)return -1;
        memcpy(data,body.constData()+offset,size_t(count));offset+=count;return count;
    }
};
class CatalogTestNetwork:public QNetworkAccessManager {
public:
    QList<QPointer<CatalogTestReply>> requests;
protected:
    QNetworkReply *createRequest(Operation,const QNetworkRequest &request,QIODevice*)override{
        auto *reply=new CatalogTestReply(request,this);requests.append(reply);return reply;
    }
};

class RuntimeTests:public QObject {
    Q_OBJECT
private slots:
    void terminalPrivateShellControl(){
        TerminalItem item;item.setSessionId("control");item.setSize({500,200});QSignalSpy controls(&item,&TerminalItem::shellControlReceived);
        item.feedBytes("visible-before\r\n\x1b]6973;prompt:");item.feedBytes("ready\x07visible-after\r\n");
        QCOMPARE(controls.count(),1);QCOMPARE(controls[0][0].toString(),QString("control"));QCOMPARE(controls[0][1].toString(),QString("prompt:ready"));
        item.selectAll();const auto text=item.selectionText();QVERIFY(text.contains("visible-before"));QVERIFY(text.contains("visible-after"));QVERIFY(!text.contains("6973"));QVERIFY(!text.contains("prompt:ready"));
    }
    void historyPredictionSettingPersists(){
        QTemporaryDir temporary;ut::Settings settings(temporary.path());QVERIFY(!settings.historyPrediction());
        settings.setHistoryPrediction(true);QVERIFY(settings.historyPrediction());
        ut::Settings restored(temporary.path());QVERIFY(restored.historyPrediction());restored.setHistoryPrediction(false);
        ut::Settings disabled(temporary.path());QVERIFY(!disabled.historyPrediction());
    }
    void historyPredictionMenuLabel(){
        QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Plugins plugins(temporary.path(),temporary.path());ut::Sessions sessions(&plugins,&settings,&scripts);
        qmlRegisterUncreatableType<TerminalItem>("UTerminal",1,0,"TerminalItem","Owned by Sessions");qmlRegisterUncreatableType<ut::Pane>("UTerminal",1,0,"Pane","Owned by Sessions");qmlRegisterType<ut::PaneHost>("UTerminal",1,0,"PaneHost");
        QQmlEngine engine;engine.rootContext()->setContextProperty("Settings",&settings);engine.rootContext()->setContextProperty("Sessions",&sessions);engine.rootContext()->setContextProperty("Plugins",&plugins);
        QQmlComponent component(&engine,QUrl::fromLocalFile(QStringLiteral(UTERMINAL_TEST_SOURCE_DIR "/resources/qml/TerminalPage.qml")));
        QScopedPointer<QObject> object(component.create());QVERIFY2(object,qPrintable(component.errorString()));auto *action=object->findChild<QObject*>("historyPredictionMenuItem");QVERIFY(action);
        QCOMPARE(action->property("text").toString(),QStringLiteral("显示历史"));sessions.toggleHistoryPrediction();QTRY_COMPARE(action->property("text").toString(),QStringLiteral("关闭历史"));
    }
    void terminalControlShortcuts(){
        struct KeyTerminal:TerminalItem {using TerminalItem::keyPressEvent;};
        KeyTerminal item;item.setSessionId("keys");item.setSize({500,200});
        QSignalSpy input(&item,&TerminalItem::inputGenerated);
        for(const auto &text:QStringList{QString(QChar(3)),"c",QString()}){
            QKeyEvent key(QEvent::KeyPress,Qt::Key_C,Qt::ControlModifier,text);item.keyPressEvent(&key);
            QCOMPARE(input.takeLast()[1].toString(),QString(QChar(3)));
        }
        item.feedBytes("copy this");item.selectAll();const auto selected=item.selectionText();
        QKeyEvent copy(QEvent::KeyPress,Qt::Key_C,Qt::ControlModifier,QString(QChar(3)));item.keyPressEvent(&copy);
        QCOMPARE(input.count(),0);QCOMPARE(QGuiApplication::clipboard()->text(),selected);
        QKeyEvent clear(QEvent::KeyPress,Qt::Key_L,Qt::ControlModifier,QString(QChar(12)));item.keyPressEvent(&clear);
        QCOMPARE(input.count(),0);QVERIFY(!item.hasSelection());item.selectAll();QVERIFY(!item.selectionText().contains("copy this"));
        QCOMPARE(item.sessionId(),QString("keys"));item.feedBytes("still alive");item.selectAll();QVERIFY(item.selectionText().contains("still alive"));
    }
    void terminalCtrlCInterruptsProcess(){
        struct KeyTerminal:TerminalItem {using TerminalItem::keyPressEvent;};
        KeyTerminal item;item.setSessionId("interrupt");ut::ConPty process;QByteArray output;
        connect(&item,&TerminalItem::inputGenerated,&process,[&](const QString &,const QString &text){process.write(text.toUtf8());});
        connect(&process,&ut::ConPty::output,this,[&](const QByteArray &bytes){output+=bytes;});
        QSignalSpy finished(&process,&ut::ConPty::finished);
        QVERIFY(process.start(qEnvironmentVariable("SystemRoot")+"/System32/WindowsPowerShell/v1.0/powershell.exe",{"-NoLogo","-NoProfile","-Command","Write-Output 'interrupt-ready'; Start-Sleep -Seconds 60; Write-Output 'unexpected-completion'"},QDir::tempPath(),QProcessEnvironment::systemEnvironment()));
        QTRY_VERIFY_WITH_TIMEOUT(output.contains("interrupt-ready"),10000);
        QKeyEvent key(QEvent::KeyPress,Qt::Key_C,Qt::ControlModifier,QString(QChar(3)));item.keyPressEvent(&key);
        QTRY_COMPARE_WITH_TIMEOUT(finished.count(),1,7000);QVERIFY(!output.contains("unexpected-completion"));process.close();
    }
    void nativeTitleBarTheme(){
        QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Plugins plugins(temporary.path(),temporary.path());
        ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(temporary.path(),&plugins,&settings,&scripts,&sessions);
        QQuickWindow window;ut::App app(temporary.path(),&scripts,&plugins,&sessions,&runs,nullptr,nullptr);
        if(!QGuiApplication::platformName().startsWith("windows"))QSKIP("Requires native Windows window");
        for(bool dark:{true,false,true,false}){
            const QColor background(dark?"#222833":"#ffffff"),text(dark?"#eef1f6":"#111827");
            app.updateTitleBar(&window,dark,background,text);BOOL enabled=FALSE;
            const auto handle=reinterpret_cast<HWND>(window.winId());
            QCOMPARE(DwmGetWindowAttribute(handle,DWMWA_USE_IMMERSIVE_DARK_MODE,&enabled,sizeof(enabled)),S_OK);QCOMPARE(bool(enabled),dark);
            DWM_WINDOW_CORNER_PREFERENCE corners=DWMWCP_DEFAULT;
            QCOMPARE(DwmGetWindowAttribute(handle,DWMWA_WINDOW_CORNER_PREFERENCE,&corners,sizeof(corners)),S_OK);
            QCOMPARE(corners,DWMWCP_ROUND);
        }
    }
    void nativeMinimizeSystemCommand(){
        if(!QGuiApplication::platformName().startsWith("windows"))QSKIP("Requires native Windows window");
        QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Plugins plugins(temporary.path(),temporary.path());
        ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(temporary.path(),&plugins,&settings,&scripts,&sessions);
        ut::App app(temporary.path(),&scripts,&plugins,&sessions,&runs,nullptr,nullptr);QQuickWindow window;
        window.setFlags(Qt::Window|Qt::CustomizeWindowHint|Qt::WindowTitleHint|Qt::WindowSystemMenuHint|Qt::WindowMinimizeButtonHint|Qt::WindowMaximizeButtonHint|Qt::WindowCloseButtonHint);
        window.setTitle("Caption layout test");
        window.resize(900,600);const auto handle=reinterpret_cast<HWND>(window.winId());app.attachWindow(&window);
        window.show();QVERIFY(QTest::qWaitForWindowExposed(&window));QTest::qWait(200);const auto style=GetWindowLongPtrW(handle,GWL_STYLE);
        QVERIFY(style&WS_SYSMENU);QVERIFY(style&WS_MINIMIZEBOX);
        QQuickItem caption(window.contentItem());caption.setPosition({0,0});caption.setSize({900,100});app.registerCaptionItem(&caption);
        POINT dragPoint{180,30};QVERIFY(ClientToScreen(handle,&dragPoint));
        POINT mapped=dragPoint;QVERIFY(ScreenToClient(handle,&mapped));const auto scale=window.devicePixelRatio();
        QVERIFY(caption.isVisible());QVERIFY(caption.contains(caption.mapFromScene(QPointF(mapped.x/scale,mapped.y/scale))));
        const auto dragHit=SendMessageW(handle,WM_NCHITTEST,0,MAKELPARAM(dragPoint.x,dragPoint.y));QCOMPARE(dragHit,LRESULT(HTCAPTION));
        MSG rightClick{};rightClick.hwnd=handle;rightClick.message=WM_NCRBUTTONUP;rightClick.wParam=HTCAPTION;qintptr menuResult=-1;
        QVERIFY(app.nativeEventFilter({},&rightClick,&menuResult));QCOMPARE(menuResult,qintptr(0));
        RECT buttons{},frame{};QVERIFY(DwmGetWindowAttribute(handle,DWMWA_CAPTION_BUTTON_BOUNDS,&buttons,sizeof(buttons))==S_OK);QVERIFY(GetWindowRect(handle,&frame));
        const auto buttonWidth=(buttons.right-buttons.left)/3;const POINT maximizePoint{frame.left+buttons.right-buttonWidth-buttonWidth/2,frame.top+(buttons.top+buttons.bottom)/2};
        const auto maximizeHit=SendMessageW(handle,WM_NCHITTEST,0,MAKELPARAM(maximizePoint.x,maximizePoint.y));QCOMPARE(maximizeHit,LRESULT(HTMAXBUTTON));
        const auto layoutHandle=reinterpret_cast<HWND>(window.winId());
        for(bool maximized:{false,true,false}){
            if(maximized)window.showMaximized();else window.showNormal();
            QTest::qWait(100);
            QVERIFY(DwmGetWindowAttribute(layoutHandle,DWMWA_CAPTION_BUTTON_BOUNDS,&buttons,sizeof(buttons))==S_OK);
            QVERIFY(GetWindowRect(layoutHandle,&frame));POINT origin{};RECT client{};
            QVERIFY(ClientToScreen(layoutHandle,&origin));QVERIFY(GetClientRect(layoutHandle,&client));
            const auto dpr=window.devicePixelRatio();
            const bool nativeButtons=buttons.right>buttons.left;
            QVERIFY(nativeButtons); // Real DWM buttons, not Qt's synthetic titlebar.
            const auto expectedHeight=42.0;
            const auto expectedTop=nativeButtons?qMax(0.0,(frame.top+buttons.top-origin.y)/dpr):0.0;
            QTRY_VERIFY(qAbs(app.captionHeight()-expectedHeight)<0.01);
            QVERIFY(qAbs(app.captionTop()-expectedTop)<0.01);
            const auto expectedInset=buttons.right>buttons.left?(client.right-frame.left-buttons.left+origin.x)/dpr:138.0;
            QVERIFY(qAbs(app.captionInset()-expectedInset)<0.01);
            for(int index=0;index<3;++index){
                const auto width=(buttons.right-buttons.left)/3;
                const POINT center{frame.left+buttons.left+width*index+width/2,frame.top+(buttons.top+buttons.bottom)/2};
                const LRESULT expected[]={HTMINBUTTON,HTMAXBUTTON,HTCLOSE};
                QCOMPARE(SendMessageW(layoutHandle,WM_NCHITTEST,0,MAKELPARAM(center.x,center.y)),expected[index]);
            }
        }
        SendMessageW(layoutHandle,WM_SYSCOMMAND,SC_MINIMIZE,0);
        QTRY_VERIFY(IsIconic(layoutHandle));
    }
    void nativeCaptionHoverReadability(){
        if(!QGuiApplication::platformName().startsWith("windows"))QSKIP("Requires Windows desktop");
        QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
        QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Plugins plugins(temporary.path(),temporary.path());
        ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(temporary.path(),&plugins,&settings,&scripts,&sessions);
        ut::App app(temporary.path(),&scripts,&plugins,&sessions,&runs,nullptr,nullptr);
        QQuickWindow window;auto format=window.requestedFormat();format.setAlphaBufferSize(8);window.setFormat(format);window.setColor(Qt::transparent);
        window.setFlags(Qt::Window|Qt::CustomizeWindowHint|Qt::WindowTitleHint|Qt::WindowSystemMenuHint|Qt::WindowMinimizeButtonHint|Qt::WindowMaximizeButtonHint|Qt::WindowCloseButtonHint);
        window.setTitle("Native caption hover regression");window.resize(640,360);app.attachWindow(&window);window.show();app.attachWindow(&window);
        QVERIFY(QTest::qWaitForWindowExposed(&window));
        const auto handle=reinterpret_cast<HWND>(window.winId());SetForegroundWindow(handle);
        POINT oldCursor{};GetCursorPos(&oldCursor);const auto restoreCursor=qScopeGuard([&]{SetCursorPos(oldCursor.x,oldCursor.y);});
        for(bool dark:{true,false,true}){
            app.updateTitleBar(&window,dark,QColor(dark?"#202020":"#f3f3f3"),QColor(dark?"white":"black"));
            QTest::qWait(100);
            RECT buttons{},frame{};POINT origin{};
            QCOMPARE(DwmGetWindowAttribute(handle,DWMWA_CAPTION_BUTTON_BOUNDS,&buttons,sizeof(buttons)),S_OK);
            QVERIFY(GetWindowRect(handle,&frame));QVERIFY(ClientToScreen(handle,&origin));
            QVERIFY(buttons.right>buttons.left);
            const auto width=(buttons.right-buttons.left)/3;
            for(int button=0;button<3;++button){
                const int x=frame.left+buttons.left+width*button+width/2,y=frame.top+(buttons.top+buttons.bottom)/2;
                QVERIFY(SetCursorPos(x,y));QTest::qWait(180);DwmFlush();
                const auto capture=window.screen()->grabWindow(window.winId()).toImage();QVERIFY(!capture.isNull());
                const int cx=x-origin.x,cy=y-origin.y,r=qRound(9*window.devicePixelRatio());
                const auto area=QRect(cx-r,cy-r,2*r,2*r).intersected(capture.rect());QVERIFY(!area.isEmpty());
                int darkest=255,lightest=0;
                for(int py=area.top();py<=area.bottom();++py)for(int px=area.left();px<=area.right();++px){
                    const int value=qGray(capture.pixel(px,py));darkest=qMin(darkest,value);lightest=qMax(lightest,value);
                }
                const auto captureDirectory=qEnvironmentVariable("UTERMINAL_CHROME_CAPTURE_DIR");
                if(!captureDirectory.isEmpty())capture.save(captureDirectory+QString("/caption-%1-%2.png").arg(dark?"dark":"light").arg(button));
                QVERIFY2(lightest-darkest>80,qPrintable(QString("Unreadable native button %1, dark=%2, luminance range=%3").arg(button).arg(dark).arg(lightest-darkest)));
            }
        }
    }
    void terminalIsDefaultPage(){
        QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Plugins plugins(temporary.path(),temporary.path());
        ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(temporary.path(),&plugins,&settings,&scripts,&sessions);
        ut::App app(temporary.path(),&scripts,&plugins,&sessions,&runs,nullptr,nullptr);QCOMPARE(app.page(),1);
    }
    void ensureTabCoalescesEmptyTerminalRequests(){
        QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Plugins plugins(temporary.path(),temporary.path());ut::Sessions sessions(&plugins,&settings,&scripts);
        QSignalSpy prompts(&sessions,&ut::Sessions::pluginRequired);sessions.ensureTab();sessions.ensureTab();
        QCOMPARE(sessions.rowCount(),0);QCOMPARE(sessions.pendingDirectoryCount(),1);QCOMPARE(prompts.count(),2);
    }
    void externalLaunchPreservesModalFocus(){
        QTemporaryDir temporary;const auto runtime=temporary.path()+"/plugins/powershell/7.0.0-x64";
        QVERIFY(QDir().mkpath(runtime+"/runtime"));
        // A tiny process fixture exercises session creation without downloading a shell.
        QVERIFY(QFile::copy(QCoreApplication::applicationDirPath()+"/uterminal_update_fixture.exe",runtime+"/runtime/pwsh.exe"));
        QVERIFY(ut::writeJson(runtime+"/installed.json",{{"kind","powershell"},{"version","7.0.0"}}));
        QVERIFY(ut::writeJson(temporary.path()+"/plugins/active.json",{{"powershell","7.0.0"}}));
        ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Plugins plugins(temporary.path(),temporary.path());
        ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(temporary.path(),&plugins,&settings,&scripts,&sessions);
        ut::App app(temporary.path(),&scripts,&plugins,&sessions,&runs,nullptr,nullptr);
        app.setPage(0);
        QQuickWindow window;window.resize(1000,700);app.attachWindow(&window);
        QQmlEngine engine;engine.rootContext()->setContextProperty("App",&app);engine.rootContext()->setContextProperty("Settings",&settings);
        QQmlComponent component(&engine);component.setData(R"(
            import QtQuick
            import QtQuick.Controls
            import "."
            Item {
                width: 1000; height: 700
                AppDialog { id: editor; objectName: "testEditor"; modal: true; width: 500; height: 300
                    standardButtons: Dialog.Close
                    contentItem: TextField { id: field; objectName: "draftInput"; text: "unsaved draft" }
                    onOpened: field.forceActiveFocus()
                }

            })",QUrl::fromLocalFile(QStringLiteral(UTERMINAL_TEST_SOURCE_DIR "/resources/qml/LaunchTest.qml")));
        QScopedPointer<QObject> object(component.create());QVERIFY2(object,qPrintable(component.errorString()));
        auto *page=qobject_cast<QQuickItem*>(object.data());QVERIFY(page);page->setParentItem(window.contentItem());
        window.show();QVERIFY(QTest::qWaitForWindowExposed(&window));
        auto *editor=object->findChild<QObject*>("testEditor");auto *field=object->findChild<QQuickItem*>("draftInput");QVERIFY(editor);QVERIFY(field);
        QVERIFY(QMetaObject::invokeMethod(editor,"open"));QTRY_VERIFY(field->hasActiveFocus());
        const auto request=ut::Instance::request("openDirectory",temporary.path());
        app.handleLaunch(request);app.handleLaunch(request); // Each delivered event represents a distinct accepted launch.
        QCOMPARE(sessions.rowCount(),2);QCOMPARE(sessions.currentIndex(),-1);QCOMPARE(app.page(),0);
        QVERIFY(editor->property("visible").toBool());QVERIFY(field->hasActiveFocus());QCOMPARE(field->property("text").toString(),QString("unsaved draft"));
        QObject confirmation;app.setModalOpen(&confirmation,true);
        QVERIFY(QMetaObject::invokeMethod(editor,"close"));QTest::qWait(30);QCOMPARE(sessions.currentIndex(),-1);QCOMPARE(app.page(),0);
        app.setModalOpen(&confirmation,false);QTRY_COMPARE(sessions.currentIndex(),1);QCOMPARE(app.page(),1);
        app.setPage(0);app.handleLaunch(ut::Instance::request("activate"));QCOMPARE(app.page(),0);QCOMPARE(sessions.rowCount(),2);
        window.showMinimized();app.handleLaunch(ut::Instance::request("activate"));QVERIFY(!(window.windowStates()&Qt::WindowMinimized));QCOMPARE(app.page(),0);
        app.handleLaunch(ut::Instance::request("openDirectory",temporary.path()));QCOMPARE(sessions.rowCount(),3);QCOMPARE(sessions.currentIndex(),2);QCOMPARE(app.page(),1);
        sessions.closeAll();
    }
    void externalDirectoriesWaitForRuntime(){
        QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Plugins plugins(temporary.path(),temporary.path());
        ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(temporary.path(),&plugins,&settings,&scripts,&sessions);
        ut::App app(temporary.path(),&scripts,&plugins,&sessions,&runs,nullptr,nullptr);
        QObject editor;app.setModalOpen(&editor,true);QSignalSpy prompts(&app,&ut::App::pluginRequested);
        app.handleLaunch(ut::Instance::request("openDirectory",temporary.path()));app.handleLaunch(ut::Instance::request("openDirectory",temporary.path()+"/missing"));
        QCOMPARE(prompts.count(),0);QCOMPARE(sessions.pendingDirectoryCount(),2);QCOMPARE(sessions.rowCount(),0);
        app.setModalOpen(&editor,false);QTRY_COMPARE(prompts.count(),1);QCOMPARE(app.page(),1);
        sessions.newTab();QCOMPARE(sessions.pendingDirectoryCount(),2);QCOMPARE(sessions.rowCount(),0);
        const auto runtime=temporary.path()+"/plugins/powershell/7.0.0-x64";QVERIFY(QDir().mkpath(runtime+"/runtime"));
        QVERIFY(QFile::copy(QCoreApplication::applicationDirPath()+"/uterminal_update_fixture.exe",runtime+"/runtime/pwsh.exe"));
        QVERIFY(ut::writeJson(runtime+"/installed.json",{{"kind","powershell"},{"version","7.0.0"}}));
        QVERIFY(plugins.activate("powershell","7.0.0"));QVERIFY(plugins.powerShellReady());
        QCOMPARE(sessions.rowCount(),0);QCOMPARE(sessions.pendingDirectoryCount(),2);
        sessions.newTab();QCOMPARE(sessions.rowCount(),2);QCOMPARE(sessions.pendingDirectoryCount(),0);QCOMPARE(sessions.currentIndex(),1);
        sessions.closeAll();
    }
    void scriptSelectionKeepsScrollPosition(){
        QTemporaryDir temporary;QVERIFY(temporary.isValid());
        ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());
        ut::Plugins plugins(temporary.path(),temporary.path());ut::Sessions sessions(&plugins,&settings,&scripts);
        ut::Executions runs(temporary.path(),&plugins,&settings,&scripts,&sessions);
        for(int i=0;i<45;++i){
            scripts.newDraft("echo test","cmd");scripts.updateDraft("title",QString("Script %1").arg(i));QVERIFY(scripts.saveDraft());
        }
        scripts.select(scripts.data(scripts.index(0),ut::Scripts::IdRole).toString());
        QQmlEngine engine;engine.rootContext()->setContextProperty("Scripts",&scripts);
        engine.rootContext()->setContextProperty("Settings",&settings);engine.rootContext()->setContextProperty("Runs",&runs);
        QQmlComponent component(&engine,QUrl::fromLocalFile(QStringLiteral(UTERMINAL_TEST_SOURCE_DIR "/resources/qml/ScriptsPage.qml")));
        QScopedPointer<QObject> object(component.create());QVERIFY2(object,qPrintable(component.errorString()));
        QQuickWindow window;window.resize(1100,900);
        auto *page=qobject_cast<QQuickItem*>(object.data());QVERIFY(page);page->setParentItem(window.contentItem());page->setSize(window.size());
        window.show();QVERIFY(QTest::qWaitForWindowExposed(&window));
        auto findItem=[](auto &&self,QQuickItem *parent,const QString &name)->QQuickItem*{
            if(parent->objectName()==name)return parent;
            for(auto *child:parent->childItems())if(auto *found=self(self,child,name))return found;
            return nullptr;
        };
        auto *list=findItem(findItem,page,"scriptList");QVERIFY(list);QTRY_VERIFY(list->height()>0);
        list->setProperty("contentY",30*43);QTest::qWait(100);
        QSignalSpy resets(&scripts,&QAbstractItemModel::modelReset);
        QSignalSpy selections(&scripts,&ut::Scripts::selectionChanged);
        for(const int row:{32,34,32}){
            auto *item=findItem(findItem,list,QString("scriptRow_%1").arg(row));QVERIFY(item);
            const auto offset=list->property("contentY").toReal();QVERIFY(offset>list->height());
            const auto point=item->mapToScene(QPointF(item->width()/2,item->height()/2));
            const auto local=list->mapFromScene(point);QVERIFY(local.y()>0&&local.y()<list->height());
            const auto id=scripts.data(scripts.index(row),ut::Scripts::IdRole).toString();
            QTest::mouseClick(&window,Qt::LeftButton,Qt::NoModifier,point.toPoint());
            QTRY_COMPARE(scripts.selected()["id"].toString(),id);QTest::qWait(50);
            QCOMPARE(list->property("contentY").toReal(),offset);QCOMPARE(resets.count(),0);
            QVERIFY(scripts.data(scripts.index(row),ut::Scripts::SelectedRole).toBool());
        }
        QCOMPARE(selections.count(),3);
        scripts.select(scripts.selected()["id"].toString());scripts.select("missing-script");
        QCOMPARE(selections.count(),3);QCOMPARE(resets.count(),0);
    }
    void scriptFavoriteButtonUsesRoundedStyle(){
        QTemporaryDir temporary;QVERIFY(temporary.isValid());
        ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());
        ut::Plugins plugins(temporary.path(),temporary.path());ut::Sessions sessions(&plugins,&settings,&scripts);
        ut::Executions runs(temporary.path(),&plugins,&settings,&scripts,&sessions);
        QQmlEngine engine;engine.rootContext()->setContextProperty("Scripts",&scripts);
        engine.rootContext()->setContextProperty("Settings",&settings);engine.rootContext()->setContextProperty("Runs",&runs);
        QQmlComponent component(&engine,QUrl::fromLocalFile(QStringLiteral(UTERMINAL_TEST_SOURCE_DIR "/resources/qml/ScriptsPage.qml")));
        QScopedPointer<QObject> object(component.create());QVERIFY2(object,qPrintable(component.errorString()));
        auto *button=object->findChild<QObject*>("scriptFavoriteButton");QVERIFY(button);
        QCOMPARE(button->property("implicitWidth").toReal(),32.0);QCOMPARE(button->property("implicitHeight").toReal(),32.0);
        auto *background=qvariant_cast<QObject*>(button->property("background"));QVERIFY(background);QCOMPARE(background->property("radius").toReal(),7.0);
    }
    void powerShellUpgradeWaitsForSelection(){
        QTemporaryDir tmp;CatalogTestNetwork network;const auto data=tmp.path()+"/data";
        const auto previous=data+"/plugins/powershell/7.0.0-x64";
        QVERIFY(QDir().mkpath(previous+"/runtime"));QFile oldExecutable(previous+"/runtime/pwsh.exe");QVERIFY(oldExecutable.open(QIODevice::WriteOnly));oldExecutable.close();
        QVERIFY(ut::writeJson(previous+"/installed.json",{{"kind","powershell"},{"version","7.0.0"}}));
        QVERIFY(ut::writeJson(data+"/plugins/active.json",{{"powershell","7.0.0"}}));
        const QByteArray archive="state transition fixture";
        const QJsonObject package{{"kind","powershell"},{"version","7.1.0"},{"architecture","x64"},{"url","https://example.invalid/runtime.zip"},{"sha256",QString::fromLatin1(QCryptographicHash::hash(archive,QCryptographicHash::Sha256).toHex())},{"size",archive.size()}};
        QVERIFY(ut::writeJson(tmp.path()+"/plugin-catalog.json",{{"packages",QJsonArray{package}}}));
        // The small helper stands in for a successfully validated runtime;
        // this test exercises activation state, not PowerShell compatibility.
        auto helper=QCoreApplication::applicationDirPath()+"/uterminal_update_fixture.exe";helper.replace("'","''");
        QVERIFY(QDir().mkpath(tmp.path()+"/plugin-bootstrap"));QFile extractor(tmp.path()+"/plugin-bootstrap/install-archive.ps1");QVERIFY(extractor.open(QIODevice::WriteOnly));
        extractor.write(("param($Archive,$Destination)\nNew-Item -ItemType Directory -Path $Destination -Force | Out-Null\nCopy-Item -LiteralPath '"+helper+"' -Destination (Join-Path $Destination 'pwsh.exe')\n").toUtf8());extractor.close();
        const auto oldOutput=qgetenv("UTERMINAL_TEST_INSTALLER_OUTPUT"),oldExit=qgetenv("UTERMINAL_TEST_INSTALLER_EXIT");
        const auto restore=qScopeGuard([&]{if(oldOutput.isNull())qunsetenv("UTERMINAL_TEST_INSTALLER_OUTPUT");else qputenv("UTERMINAL_TEST_INSTALLER_OUTPUT",oldOutput);if(oldExit.isNull())qunsetenv("UTERMINAL_TEST_INSTALLER_EXIT");else qputenv("UTERMINAL_TEST_INSTALLER_EXIT",oldExit);});
        qputenv("UTERMINAL_TEST_INSTALLER_OUTPUT",(tmp.path()+"/probe.json").toUtf8());qputenv("UTERMINAL_TEST_INSTALLER_EXIT","0");
        ut::Plugins plugins(data,tmp.path(),nullptr,&network);plugins.acquire("powershell","7.0.0");
        plugins.install("powershell","7.1.0");network.requests[0]->finish(archive);
        QTRY_VERIFY_WITH_TIMEOUT(!plugins.busy(),15000);
        QVERIFY2(plugins.installedVersion("powershell","7.1.0"),qPrintable(plugins.status()));
        QCOMPARE(plugins.powerShellVersion(),QString("7.0.0"));QCOMPARE(ut::readJson(data+"/plugins/active.json")["powershell"].toString(),QString("7.0.0"));
        QVERIFY(plugins.inUse("powershell","7.0.0"));
        plugins.install("powershell","7.1.0"); // Same action as the explicit "Use this version" button.
        QCOMPARE(plugins.powerShellVersion(),QString("7.1.0"));QVERIFY(plugins.inUse("powershell","7.0.0"));
        QCOMPARE(network.requests.size(),1);plugins.release("powershell","7.0.0");
    }
    void terminalInputMethodComposition(){
        struct InputTerminal:TerminalItem {using TerminalItem::inputMethodEvent;using TerminalItem::inputMethodQuery;using TerminalItem::focusOutEvent;};
        InputTerminal item;item.setSessionId("ime");item.setSize({600,300});item.feedBytes("\x1b[3;5H");
        const auto base=item.inputMethodQuery(Qt::ImCursorRectangle).toRectF();QVERIFY(base.width()>0);
        QSignalSpy input(&item,&TerminalItem::inputGenerated);
        QTextCharFormat format;format.setForeground(Qt::yellow);format.setBackground(Qt::red);format.setFontUnderline(true);
        QInputMethodEvent preedit(QStringLiteral("中🙂文"),{{QInputMethodEvent::Cursor,1,1,{}},{QInputMethodEvent::TextFormat,0,1,QVariant::fromValue(QTextFormat(format))}});
        item.inputMethodEvent(&preedit);QVERIFY(input.isEmpty());
        const auto composed=item.inputMethodQuery(Qt::ImCursorRectangle).toRectF();
        QVERIFY(composed.left()>base.left());QCOMPARE(composed.top(),base.top());
        QImage image(600,300,QImage::Format_ARGB32_Premultiplied);image.fill(Qt::black);
        {QPainter painter(&image);item.paint(&painter);}
        int redPixels=0;for(int y=int(base.top());y<int(base.bottom());++y)for(int x=int(base.left());x<int(composed.left());++x)if(image.pixelColor(x,y)==QColor(Qt::red))++redPixels;
        QVERIFY(redPixels>0); // Input method's highlighted segment is actually painted.
        item.feedBytes("\x1b[3;70H");
        QInputMethodEvent longPreedit(QString(200,QChar('w')),{{QInputMethodEvent::Cursor,200,1,{}}});item.inputMethodEvent(&longPreedit);
        QVERIFY(item.inputMethodQuery(Qt::ImCursorRectangle).toRectF().right()<=item.width()+1);
        QInputMethodEvent commit;commit.setCommitString(QStringLiteral("中文🙂"));item.inputMethodEvent(&commit);
        QString committed;for(const auto &entry:input)committed+=entry[1].toString();QCOMPARE(committed,QStringLiteral("中文🙂"));
        item.feedBytes("\x1b[3;5H");item.inputMethodEvent(&preedit);
        QFocusEvent focusOut(QEvent::FocusOut);item.focusOutEvent(&focusOut);
        QCOMPARE(item.inputMethodQuery(Qt::ImCursorRectangle).toRectF(),base);
        item.setFontSize(22);QVERIFY(item.inputMethodQuery(Qt::ImCursorRectangle).toRectF().height()>base.height());
    }
    void interruptedRepairIsNotReady(){
        QTemporaryDir tmp;CatalogTestNetwork network;const auto data=tmp.path()+"/data";
        const auto version=data+"/plugins/powershell/7.0.0-x64";
        const QByteArray archive="invalid archive fixture";
        const QJsonObject package{{"kind","powershell"},{"version","7.0.0"},{"architecture","x64"},{"url","https://example.invalid/runtime.zip"},{"sha256",QString::fromLatin1(QCryptographicHash::hash(archive,QCryptographicHash::Sha256).toHex())},{"size",archive.size()}};
        QVERIFY(ut::writeJson(tmp.path()+"/plugin-catalog.json",{{"packages",QJsonArray{package}}}));
        QVERIFY(ut::writeJson(version+"/installed.json",package)); // Previous installation lost its executable.
        ut::Plugins plugins(data,tmp.path(),nullptr,&network);QVERIFY(!plugins.installedVersion("powershell","7.0.0"));
        plugins.install("powershell","7.0.0");network.requests[0]->finish(archive);
        QVERIFY(QFileInfo::exists(version+"/installing.json"));
        QVERIFY(QDir().mkpath(version+"/runtime"));QFile partial(version+"/runtime/pwsh.exe");QVERIFY(partial.open(QIODevice::WriteOnly));partial.write("partial");partial.close();
        QVERIFY(!plugins.installedVersion("powershell","7.0.0"));
        QTRY_VERIFY_WITH_TIMEOUT(!plugins.busy(),15000); // Missing extractor fails; no fixture executable is run.
        ut::Plugins restarted(data,tmp.path());QVERIFY(!restarted.installedVersion("powershell","7.0.0"));
        QVERIFY(!restarted.activate("powershell","7.0.0"));
        QVERIFY(QFileInfo::exists(version+"/installing.json"));
    }
    void catalogRefreshPreservesInstallationState(){
        QTemporaryDir tmp;CatalogTestNetwork network;
        const QJsonObject package{{"kind","powershell"},{"version","7.0.0"},{"architecture","x64"},{"url","https://example.invalid/runtime.zip"},{"sha256",QString(64,'0')},{"size",1}};
        QVERIFY(ut::writeJson(tmp.path()+"/plugin-catalog.json",{{"packages",QJsonArray{package}}}));
        ut::Plugins plugins(tmp.path()+"/data",tmp.path(),nullptr,&network);
        plugins.refreshCatalog();QVERIFY(plugins.catalogRefreshing());plugins.refreshCatalog();QCOMPARE(network.requests.size(),1);
        plugins.install("powershell","7.0.0");QVERIFY(plugins.busy());QCOMPARE(network.requests.size(),2);
        const auto installing=plugins.status();
        const QJsonObject asset{{"name","PowerShell-7.1.0-win-x64.zip"},{"digest","sha256:"+QString(64,'1')},{"browser_download_url","https://example.invalid/new-runtime.zip"},{"size",10}};
        network.requests[0]->finish(QJsonDocument(QJsonArray{QJsonObject{{"tag_name","v7.1.0"},{"assets",QJsonArray{asset}}}}).toJson());
        QVERIFY(!plugins.catalogRefreshing());QVERIFY(plugins.busy());QCOMPARE(plugins.status(),installing);
        QCOMPARE(plugins.powerShellVersions().size(),2);
        QVERIFY(plugins.catalogStatus().contains(QStringLiteral("已更新")));
        plugins.refreshCatalog();plugins.cancel();QVERIFY(!plugins.busy());const auto cancelled=plugins.status();
        network.requests[2]->finish("{}");
        QVERIFY(!plugins.catalogRefreshing());QCOMPARE(plugins.status(),cancelled);
        QVERIFY(plugins.catalogStatus().contains(QStringLiteral("失败")));
        plugins.refreshCatalog();network.requests[3]->finish({},QNetworkReply::TimeoutError);
        QVERIFY(!plugins.catalogRefreshing());QCOMPARE(plugins.status(),cancelled);
        QVERIFY(plugins.catalogStatus().contains(QStringLiteral("测试网络错误")));
    }
    void catalogRefreshStopsWithOwner(){
        QTemporaryDir tmp;CatalogTestNetwork network;
        auto plugins=std::make_unique<ut::Plugins>(tmp.path(),tmp.path(),nullptr,&network);
        plugins->refreshCatalog();auto reply=network.requests[0];QVERIFY(reply);QVERIFY(!reply->isFinished());
        plugins.reset();QVERIFY(reply->isFinished());QCOMPARE(reply->error(),QNetworkReply::OperationCanceledError);
    }
    void pluginCancellationState(){
        QTemporaryDir tmp;
        const QJsonObject package{{"kind","powershell"},{"version","7.0.0"},{"architecture","x64"},{"url","https://127.0.0.1:1/not-downloaded.zip"},{"sha256",QString(64,'0')},{"size",1}};
        QVERIFY(ut::writeJson(tmp.path()+"/plugin-catalog.json",{{"packages",QJsonArray{package}}}));
        ut::Plugins plugins(tmp.path()+"/data",tmp.path());bool cancellingObserved=false;
        connect(&plugins,&ut::Plugins::changed,this,[&]{cancellingObserved|=plugins.cancellationRequested();});
        plugins.install("powershell","7.0.0");QVERIFY(plugins.busy());
        QCOMPARE(plugins.taskKind(),QString("powershell"));QCOMPARE(plugins.taskVersion(),QString("7.0.0"));
        // Abort before the event loop can connect: this test never downloads a runtime.
        plugins.cancel();QTRY_VERIFY(!plugins.busy());QVERIFY(cancellingObserved);QVERIFY(!plugins.cancellationRequested());
        QVERIFY(plugins.status().contains(QStringLiteral("取消")));
        QVERIFY(!QFileInfo::exists(tmp.path()+"/data/staging/powershell-7.0.0.zip"));
        const auto status=plugins.status();plugins.cancel();QCOMPARE(plugins.status(),status);
    }
    void updateHelperCacheLifecycle(){
        QTemporaryDir tmp;const auto cache=tmp.path()+"/updates";
        const auto directory=cache+"/helper-0123456789abcdef0123456789abcdef";
        const auto helper=ut::Updates::stageHelper(QCoreApplication::applicationDirPath(),directory);QVERIFY(!helper.isEmpty());
        auto marker=ut::readJson(directory+"/helper-cache.json");QCOMPARE(marker["format"].toInt(),1);
        marker["creatorPid"]=qint64(4294967294);QVERIFY(ut::writeJson(directory+"/helper-cache.json",marker));
        QCOMPARE(ut::Updates::cleanupHelperCache(cache),0);QVERIFY(QFileInfo::exists(helper)); // Handoff grace period.
        marker["createdAt"]=QDateTime::currentSecsSinceEpoch()-7200;marker["creatorPid"]=QCoreApplication::applicationPid();
        QVERIFY(ut::writeJson(directory+"/helper-cache.json",marker));QCOMPARE(ut::Updates::cleanupHelperCache(cache),0); // Staging app alive.
        marker["creatorPid"]=qint64(4294967294);QVERIFY(ut::writeJson(directory+"/helper-cache.json",marker));
        const auto fixture=QCoreApplication::applicationDirPath()+"/uterminal_update_fixture.exe";
        QProcess parentProcess;parentProcess.start(fixture,{"--wait"});QVERIFY(parentProcess.waitForStarted());
        const auto receipt=tmp.path()+"/receipt.json";
        QProcess worker;worker.start(helper,{QString::number(parentProcess.processId()),fixture,"1",QString(64,'0'),receipt});QVERIFY(worker.waitForStarted());
        QTRY_COMPARE(ut::readJson(receipt)["state"].toString(),QString("waiting"));
        QCOMPARE(ut::Updates::cleanupHelperCache(cache),0);QVERIFY(QFileInfo::exists(helper)); // Helper holds lease even after creator exits.
        worker.kill();QVERIFY(worker.waitForFinished());parentProcess.kill();QVERIFY(parentProcess.waitForFinished());
        QFile note(directory+"/user-note.txt");QVERIFY(note.open(QIODevice::WriteOnly));QCOMPARE(note.write("keep"),4);note.close();
        QCOMPARE(ut::Updates::cleanupHelperCache(cache),0);QVERIFY(QFileInfo::exists(helper)); // Never remove unrecognized content.
        QVERIFY(note.remove());
        const auto unmarked=cache+"/helper-abcdef0123456789abcdef0123456789";QVERIFY(QDir().mkpath(unmarked));
        QCOMPARE(ut::Updates::cleanupHelperCache(cache),1); // Dead helper's lock is recoverable.
        QVERIFY(!QFileInfo::exists(directory));QVERIFY(QFileInfo::exists(unmarked));
        QCOMPARE(ut::Updates::cleanupHelperCache(cache),0);
    }
    void stagedUpdateHelperResult(){
        QTemporaryDir tmp;const auto directory=tmp.path()+"/helper";
        const auto helper=ut::Updates::stageHelper(QCoreApplication::applicationDirPath(),directory);QVERIFY(!helper.isEmpty());
        QVERIFY(ut::Updates::stageHelper(QCoreApplication::applicationDirPath(),directory).isEmpty());
        const auto fixture=directory+"/fixture.exe";QVERIFY(QFile::copy(QCoreApplication::applicationDirPath()+"/uterminal_update_fixture.exe",fixture));
        QFile binary(fixture);QVERIFY(binary.open(QIODevice::ReadOnly));const auto bytes=binary.readAll();binary.close();
        const auto receipt=tmp.path()+"/receipt.json";QVERIFY(ut::writeJson(receipt,{{"version","9.0.0"}}));
        auto env=QProcessEnvironment::systemEnvironment();env.insert("PATH",qEnvironmentVariable("SystemRoot")+"/System32");env.insert("UTERMINAL_TEST_INSTALLER_OUTPUT",tmp.path()+"/called.json");env.insert("UTERMINAL_TEST_INSTALLER_EXIT","2");
        QProcess process;process.setProcessEnvironment(env);process.start(helper,{"4294967294",fixture,QString::number(bytes.size()),QString::fromLatin1(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex()),receipt});
        QVERIFY(process.waitForFinished(10000));QCOMPARE(process.exitCode(),7);const auto result=ut::readJson(receipt);QCOMPARE(result["state"].toString(),QString("failed"));QCOMPARE(result["installerExitCode"].toInt(),2);
    }
    void legacyOptionalParameterExecution(){
        QTemporaryDir tmp;const auto data=tmp.path();ut::Plugins plugins(data,data);ut::Settings settings(data);ut::Scripts scripts(data);ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(data,&plugins,&settings,&scripts,&sessions);
        const QJsonObject old{{"id","optional"},{"title","optional"},{"executor",QJsonObject{{"kind","batch"},{"command","@echo before${name}after"}}},{"parameters",QJsonArray{QJsonObject{{"id","name"},{"label","Optional name"},{"kind","text"},{"required",false}}}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()))["status"].toString(),QString("ok"));
        QSignalSpy errors(&runs,&ut::Executions::error);runs.runSelected({});QTRY_VERIFY_WITH_TIMEOUT(!runs.selectedRunning(),10000);QVERIFY(errors.isEmpty());QVERIFY2(runs.output().contains("beforeafter"),qPrintable(runs.output()));
    }
    void paneRuntimeStatus(){
        ut::Pane pane;pane.language="powershell";pane.powerShellVersion="7.6.3";pane.pythonVersion="3.13.14";pane.captureRuntime();
        const auto label=pane.runtimeLabel();QVERIFY(label.contains("7.6.3"));QVERIFY(label.contains("3.13.14"));
        pane.powerShellVersion.clear();pane.pythonVersion.clear();QCOMPARE(pane.runtimeLabel(),label);
        QVERIFY(pane.process.start(qEnvironmentVariable("SystemRoot")+"/System32/cmd.exe",{"/D","/Q","/C","exit 7"},QDir::tempPath(),QProcessEnvironment::systemEnvironment()));
        QTRY_VERIFY_WITH_TIMEOUT(pane.stateLabel().contains(QStringLiteral("已退出")),10000);QVERIFY(pane.stateLabel().endsWith("7"));QCOMPARE(pane.runtimeLabel(),label);
    }
    void terminalColorsPreserveBuffer(){
        TerminalItem item;item.setSessionId("colors");item.setSize({500,200});QTest::qWait(60);
        item.feedBytes("saved output\r\n\x1b[48;2;10;20;30m   \x1b[0m");item.selectAll();const auto text=item.selectionText();
        item.setColors(QColor("#202020"),QColor("#fafafa"));
        QCOMPARE(item.sessionId(),QString("colors"));QCOMPARE(item.selectionText(),text);
        item.clearSelection();
        QImage image(500,200,QImage::Format_ARGB32);image.fill(Qt::transparent);QPainter painter(&image);item.paint(&painter);painter.end();
        QCOMPARE(image.pixelColor(499,199),QColor("#fafafa"));
        bool explicitColor=false;for(int y=0;y<100&&!explicitColor;++y)for(int x=0;x<60;++x)if(image.pixelColor(x,y)==QColor(10,20,30)){explicitColor=true;break;}
        QVERIFY(explicitColor);
        item.feedBytes("\r\nmore output");item.selectAll();QVERIFY(item.selectionText().contains("saved output"));QVERIFY(item.selectionText().contains("more output"));
    }
    void terminalPathDrop(){
        struct DropTerminal:TerminalItem {using TerminalItem::dropEvent;using TerminalItem::dragEnterEvent;};
        DropTerminal item;item.setSessionId("drop");QSignalSpy input(&item,&TerminalItem::inputGenerated);
        QMimeData mime;mime.setUrls({QUrl::fromLocalFile(QStringLiteral("C:/中文 path/it's $file.txt")),QUrl::fromLocalFile("D:/folder")});
        QDragEnterEvent enter({10,10},Qt::CopyAction|Qt::MoveAction,&mime,Qt::LeftButton,Qt::NoModifier);
        item.dragEnterEvent(&enter);QVERIFY(enter.isAccepted());QCOMPARE(enter.dropAction(),Qt::CopyAction);
        QDropEvent drop({10,10},Qt::CopyAction|Qt::MoveAction,&mime,Qt::LeftButton,Qt::NoModifier);
        item.dropEvent(&drop);QVERIFY(drop.isAccepted());QCOMPARE(drop.dropAction(),Qt::CopyAction);
        QCOMPARE(input.size(),1);QCOMPARE(input.takeFirst()[1].toString(),QStringLiteral("'C:\\中文 path\\it''s $file.txt' 'D:\\folder'"));
        item.setInputLanguage("cmd");item.dropEvent(&drop);QCOMPARE(input.takeFirst()[1].toString(),QStringLiteral("\"C:\\中文 path\\it's $file.txt\" \"D:\\folder\""));
        item.setInputLanguage("python");mime.setUrls({QUrl::fromLocalFile("C:/input file")});item.dropEvent(&drop);QCOMPARE(input.takeFirst()[1].toString(),QStringLiteral("C:\\input file"));
        mime.setUrls({QUrl("https://example.com/file")});item.dropEvent(&drop);QVERIFY(!drop.isAccepted());QVERIFY(input.isEmpty());
        mime.setUrls({QUrl::fromLocalFile("C:/bad\ncommand")});item.dropEvent(&drop);QVERIFY(!drop.isAccepted());QVERIFY(input.isEmpty());
        mime.setUrls({QUrl::fromLocalFile("C:/valid")});QDropEvent move({10,10},Qt::MoveAction,&mime,Qt::LeftButton,Qt::NoModifier);
        item.dropEvent(&move);QVERIFY(!move.isAccepted());QVERIFY(input.isEmpty());
        QQuickWindow window;window.resize(400,250);
        auto *surface=new TerminalItem(window.contentItem());surface->setSize({400,250});surface->setSessionId("window-drop");
        QSignalSpy routed(surface,&TerminalItem::inputGenerated);window.show();QTest::qWait(80);
        QDragEnterEvent windowEnter({30,30},Qt::CopyAction,&mime,Qt::LeftButton,Qt::NoModifier);
        QCoreApplication::sendEvent(&window,&windowEnter);QVERIFY(windowEnter.isAccepted());
        QDropEvent windowDrop({30,30},Qt::CopyAction,&mime,Qt::LeftButton,Qt::NoModifier);
        QCoreApplication::sendEvent(&window,&windowDrop);QVERIFY(windowDrop.isAccepted());
        QCOMPARE(routed.size(),1);QCOMPARE(routed.first()[1].toString(),QStringLiteral("'C:\\valid'"));
    }
    void terminalLogicalWrapping(){
        TerminalItem wide;wide.setSessionId("wide-edge");
        const auto edge=QString(wide.columns()-1,'x')+QStringLiteral("中文tail");
        wide.feedBytes(edge.toUtf8());wide.selectAll();QVERIFY2(wide.selectionText().startsWith(edge),qPrintable(wide.selectionText()));
        wide.openSearch();wide.setSearchText(QStringLiteral("x中文"));QCOMPARE(wide.searchCount(),1);
        TerminalItem restored;restored.setSessionId("backfill");restored.setSize({400,180});QTest::qWait(80);
        const QString flowed(restored.columns()*(restored.rows()+2)+3,'z');restored.feedBytes((flowed+"\r\n").toUtf8());
        QVERIFY(restored.scrollbackLineCount()>0);restored.setSize({400,2000});QTest::qWait(80);restored.selectAll();
        QVERIFY2(restored.selectionText().startsWith(flowed+"\n"),qPrintable(restored.selectionText().left(250)));
        TerminalItem item;item.setSessionId("wrap");item.setSize({400,180});QTest::qWait(80);
        const auto original=QString(item.columns()-2,'a')+QStringLiteral("  中文🙂tail");
        item.feedBytes((original+"\r\nnext-line\r\n").toUtf8());item.selectAll();
        QVERIFY2(item.selectionText().startsWith(original+"\nnext-line\n"),qPrintable(item.selectionText()));
        item.openSearch();item.setSearchText(QStringLiteral("a  中文🙂"));QCOMPARE(item.searchCount(),1);
        item.setSearchText("tailnext-line");QCOMPARE(item.searchCount(),0);
        for(int i=0;i<100;++i)item.feedBytes("history\r\n");
        item.selectAll();QVERIFY2(item.selectionText().startsWith(original+"\nnext-line\n"),qPrintable(item.selectionText().left(200)));
        item.setSearchText(QStringLiteral("a  中文🙂"));QCOMPARE(item.searchCount(),1);
        item.setSize({400,1000});QTest::qWait(80);item.selectAll();
        QVERIFY2(item.selectionText().startsWith(original+"\nnext-line\n"),qPrintable(item.selectionText().left(200)));
        item.setSize({700,1000});QTest::qWait(80);item.selectAll();
        QVERIFY2(item.selectionText().startsWith(original+"\nnext-line\n"),qPrintable(item.selectionText().left(200)));
    }
    void terminalSearch(){
        TerminalItem item;item.setSize({400,130});item.setSessionId("search");QTest::qWait(60);
        item.feedBytes(QStringLiteral("Alpha 中文🙂\r\nalpha second\r\n").toUtf8());
        for(int i=0;i<100;++i)item.feedBytes("filler\r\n");
        item.openSearch();item.setSearchText("ALPHA");QCOMPARE(item.searchCount(),2);QCOMPARE(item.searchIndex(),0);QVERIFY(item.scrollOffset()>0);
        item.nextSearch();QCOMPARE(item.searchIndex(),1);item.nextSearch();QCOMPARE(item.searchIndex(),0);item.nextSearch(true);QCOMPARE(item.searchIndex(),1);
        item.setSearchText(QStringLiteral("中文🙂"));QCOMPARE(item.searchCount(),1);
        item.feedBytes(QStringLiteral("中文🙂\r\n").toUtf8());QTRY_COMPARE(item.searchCount(),2);
        item.closeSearch();QVERIFY(!item.searchOpen());item.openSearch();QCOMPARE(item.searchCount(),2);
        item.setSearchText("absent");QCOMPARE(item.searchCount(),0);QCOMPARE(item.searchIndex(),-1);item.nextSearch(true);QCOMPARE(item.searchIndex(),-1);
        item.setSearchText({});QCOMPARE(item.searchCount(),0);
        item.setSearchText("Alpha");item.clearDisplay();QTRY_COMPARE(item.searchCount(),0);
    }
    void shellDirectoryResolution(){
        QTemporaryDir tmp;const auto directory=tmp.path()+"/中文 path";QVERIFY(QDir().mkpath(directory));QFile file(directory+"/script.py");QVERIFY(file.open(QIODevice::WriteOnly));file.close();
        QCOMPARE(ut::Sessions::resolveDirectory(directory),directory);QCOMPARE(ut::Sessions::resolveDirectory(file.fileName()),directory);
        QCOMPARE(ut::Sessions::resolveDirectory(directory+"/."),directory);
        QCOMPARE(ut::Sessions::resolveDirectory(QDir::rootPath()+"/."),QDir::rootPath());
        QCOMPARE(ut::Sessions::resolveDirectory(tmp.path()+"/missing"),QDir::homePath());QCOMPARE(ut::Sessions::resolveDirectory({}),QDir::homePath());
    }
    void updateHelperWaitsAndVerifies(){
        QTemporaryDir tmp;const auto marker=tmp.path()+"/installer-called.json";
        const auto restartMarker=tmp.path()+"/relaunch-called.json";
        const auto fixture=QCoreApplication::applicationDirPath()+"/uterminal_update_fixture.exe";
        const auto relaunch=tmp.path()+"/relaunch.exe";QVERIFY(QFile::copy(fixture,relaunch));
        QFile file(fixture);QVERIFY(file.open(QIODevice::ReadOnly));const auto bytes=file.readAll();file.close();
        QProcess parentProcess;parentProcess.start(fixture,{"--wait"});QVERIFY(parentProcess.waitForStarted());
        auto env=QProcessEnvironment::systemEnvironment();env.insert("UTERMINAL_TEST_INSTALLER_OUTPUT",marker);env.insert("UTERMINAL_TEST_RELAUNCH_OUTPUT",restartMarker);
        QProcess helper;helper.setProcessEnvironment(env);
        const auto program=QCoreApplication::applicationDirPath()+"/UTerminalUpdateRunner.exe";
        QStringList args{QString::number(parentProcess.processId()),fixture,QString::number(bytes.size()),QString::fromLatin1(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex())};
        const auto receiptPath=tmp.path()+"/install-result.json";QVERIFY(ut::writeJson(receiptPath,{{"version","9.0.0"}}));args.append(receiptPath);args.append(relaunch);
        helper.start(program,args);QVERIFY(helper.waitForStarted());QTest::qWait(150);QVERIFY(!QFileInfo::exists(marker));QCOMPARE(helper.state(),QProcess::Running);
        parentProcess.kill();QVERIFY(parentProcess.waitForFinished());QVERIFY(helper.waitForFinished(10000));QCOMPARE(helper.exitCode(),0);
        QCOMPARE(ut::readJson(receiptPath)["state"].toString(),QString("installed"));QCOMPARE(ut::readJson(receiptPath)["version"].toString(),QString("9.0.0"));QCOMPARE(ut::readJson(receiptPath)["installerExitCode"].toInt(),0);
        QTRY_VERIFY(QFileInfo::exists(marker));QFile result(marker);QVERIFY(result.open(QIODevice::ReadOnly));const auto arguments=QJsonDocument::fromJson(result.readAll()).array();result.close();
        QVERIFY(arguments.contains("/NOCLOSEAPPLICATIONS"));QVERIFY(arguments.contains("/SILENT"));QVERIFY(QFile::remove(marker));
        QTRY_VERIFY(QFileInfo::exists(restartMarker));QFile restartResult(restartMarker);QVERIFY(restartResult.open(QIODevice::ReadOnly));const auto restartArguments=QJsonDocument::fromJson(restartResult.readAll()).array();QCOMPARE(restartArguments.size(),1);
        QStringList legacyArgs{"4294967294",fixture,QString::number(bytes.size()),QString::fromLatin1(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex()),receiptPath};
        helper.start(program,legacyArgs);QVERIFY(helper.waitForFinished(10000));QCOMPARE(helper.exitCode(),0);QCOMPARE(ut::readJson(receiptPath)["state"].toString(),QString("installed"));QVERIFY(QFile::remove(marker));
        args[0]="4294967294";args[3]=QString(64,'0');helper.start(program,args);QVERIFY(helper.waitForFinished(10000));QCOMPARE(helper.exitCode(),4);QVERIFY(!QFileInfo::exists(marker));
        QCOMPARE(ut::readJson(receiptPath)["state"].toString(),QString("failed"));QVERIFY(ut::readJson(receiptPath)["message"].toString().contains("SHA-256"));
        const auto brokenPath=tmp.path()+"/broken.exe";QFile broken(brokenPath);QVERIFY(broken.open(QIODevice::WriteOnly));broken.write("invalid");broken.close();
        args[1]=brokenPath;args[2]="7";args[3]=QString::fromLatin1(QCryptographicHash::hash("invalid",QCryptographicHash::Sha256).toHex());
        helper.start(program,args);QVERIFY(helper.waitForFinished(10000));QCOMPARE(helper.exitCode(),5);
        QCOMPARE(ut::readJson(receiptPath)["state"].toString(),QString("failed"));QVERIFY(ut::readJson(receiptPath)["message"].toString().contains(QStringLiteral("无法启动安装程序")));
    }
    void interactiveScriptLifecycle_data(){
        QTest::addColumn<QString>("mode");
        for(const auto &mode:{"exit","timeout","end-pane","close-tab","destroy-service"})QTest::newRow(mode)<<QString(mode);
    }
    void interactiveScriptLifecycle(){
        QFETCH(QString,mode);QTemporaryDir tmp;const auto data=tmp.path();
        ut::Plugins plugins(data,data);ut::Settings settings(data);ut::Scripts scripts(data);ut::Sessions sessions(&plugins,&settings,&scripts);
        auto runs=std::make_unique<ut::Executions>(data,&plugins,&settings,&scripts,&sessions);
        scripts.newDraft(mode=="exit"?"@echo off\necho lifecycle-result\nexit /b 7":"@echo off\necho lifecycle-ready\nping -n 30 127.0.0.1 >nul","cmd");
        scripts.updateDraft("title","interactive lifecycle");scripts.updateDraft("timeoutSeconds",mode=="timeout"?1:0);QVERIFY(scripts.saveDraft());
        runs->runSelected({},true);QCOMPARE(sessions.rowCount(),1);QCOMPARE(runs->runningCount(),0);
        auto *pane=sessions.panes().first().value<ut::Pane*>();QVERIFY(pane);
        if(mode=="end-pane")sessions.endPane(pane);
        else if(mode=="close-tab")sessions.closeTab(0);
        else if(mode=="destroy-service")runs.reset();
        if(runs){
            QTRY_VERIFY_WITH_TIMEOUT(!runs->selectedRunning(),7000);
            QCOMPARE(runs->outcome(),QString("failed"));
            if(mode=="exit"){QVERIFY2(runs->status().contains("退出码 7"),qPrintable(runs->status()));QVERIFY(runs->output().isEmpty());QVERIFY(runs->selectedInteractive());}
            if(mode=="timeout")QVERIFY(runs->status().contains("运行超时"));
        }
        QVERIFY(!sessions.anyRunning());QCOMPARE(QDir(data+"/runs").entryList(QDir::Dirs|QDir::NoDotAndDotDot).size(),0);
        QVERIFY(scripts.deleteSelected());
    }
    void migratedBatchAttachmentsSurviveSharing(){
        QTemporaryDir temporary;const auto collection=temporary.path()+"/collection";
        QVERIFY(QDir().mkpath(collection+"/tools"));QVERIFY(QDir().mkpath(collection+"/scripts/data"));
        QFile source(collection+"/scripts/main.cmd");QVERIFY(source.open(QIODevice::WriteOnly));source.write("@echo off\ntype \"%~dp0data\\value.txt\"\n");source.close();
        QFile resource(collection+"/scripts/data/value.txt");QVERIFY(resource.open(QIODevice::WriteOnly));resource.write("attachment-round-trip");resource.close();
        QVERIFY(ut::writeJson(collection+"/tools/item.json",{{"id","bundle"},{"title","Bundle"},{"executor",QJsonObject{{"kind","batch"},{"command","scripts/main.cmd"}}}}));
        ut::Scripts imported(temporary.path()+"/first");const auto report=imported.importCollection(collection);QVERIFY2(imported.count()==1,qPrintable(report));
        const auto data=temporary.path()+"/second";ut::Scripts scripts(data);QCOMPARE(scripts.importText(imported.exportSelected())["status"].toString(),QString("ok"));
        QVERIFY(QFile::remove(resource.fileName())); // Running must use the captured snapshot.
        ut::Plugins plugins(data,data);ut::Settings settings(data);ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(data,&plugins,&settings,&scripts,&sessions);
        runs.runSelected({});QTRY_VERIFY_WITH_TIMEOUT(!runs.selectedRunning(),10000);
        QCOMPARE(runs.outcome(),QString("succeeded"));QVERIFY(runs.output().contains("attachment-round-trip"));
        QCOMPARE(QDir(data+"/runs").entryList(QDir::Dirs|QDir::NoDotAndDotDot).size(),0);
        auto invalid=scripts.get("bundle");invalid["id"]="traversal";invalid["bundledFiles"]=QJsonObject{{"../escape.txt","eA=="}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(invalid).toJson()))["status"].toString(),QString("error"));
        invalid["bundledFiles"]=QJsonObject{{"main.cmd","eA=="}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(invalid).toJson()))["status"].toString(),QString("error"));
        invalid["bundledFiles"]=QJsonObject{{"data/value.txt","invalid!"}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(invalid).toJson()))["status"].toString(),QString("error"));
    }
    void migratedScriptDefaultWorkingDirectory(){
        QTemporaryDir temporary;const auto data=temporary.path();
        ut::Plugins plugins(data,data);ut::Settings settings(data);ut::Scripts scripts(data);
        const QString code="@echo off\nif /I \"%CD%\"==\"%POPTOOLS_OUTPUT_DIR%\" (echo cwd-output-match) else (echo cwd-output-mismatch)";
        const QJsonObject legacy{{"id","legacy-cwd"},{"title","Legacy cwd"},{"executor",QJsonObject{{"kind","batch"},{"command",code}}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(legacy).toJson()))["status"].toString(),QString("ok"));
        QVERIFY(scripts.selected()["useOutputDirectoryAsWorkingDirectory"].toBool());
        ut::Scripts restored(data);QVERIFY(restored.selected()["useOutputDirectoryAsWorkingDirectory"].toBool());
        ut::Sessions sessions(&plugins,&settings,&restored);ut::Executions runs(data,&plugins,&settings,&restored,&sessions);
        runs.runSelected({});QTRY_VERIFY_WITH_TIMEOUT(!runs.selectedRunning(),10000);
        QCOMPARE(runs.outcome(),QString("succeeded"));QVERIFY(runs.output().contains("cwd-output-match"));QVERIFY(!runs.output().contains("cwd-output-mismatch"));
        restored.editSelected();restored.updateDraft("workingDirectory",data);QVERIFY(restored.saveDraft());
        runs.runSelected({});QTRY_VERIFY_WITH_TIMEOUT(!runs.selectedRunning(),10000);
        QCOMPARE(runs.outcome(),QString("succeeded"));QVERIFY(runs.output().contains("cwd-output-mismatch")); // Explicit directory takes precedence.
    }
    void scriptEnvironmentAndOutputDirectory(){
        QTemporaryDir temporary;const auto data=temporary.path()+"/数据 空间";QDir().mkpath(data);
        ut::Plugins plugins(data,data);ut::Settings settings(data);ut::Scripts scripts(data);ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(data,&plugins,&settings,&scripts,&sessions);
        scripts.newDraft("@echo off\necho %UT_TEST_VALUE%\necho result>\"%UTERMINAL_OUTPUT_DIR%\\result.txt\"\necho legacy>\"%POPTOOLS_OUTPUT_DIR%\\legacy.txt\"","cmd");
        scripts.updateDraft("title","environment and files");scripts.updateDraft("workingDirectory",data);scripts.updateDraft("outputDirectory","输出 结果");QVERIFY(scripts.setDraftEnvironment("UT_TEST_VALUE","isolated-value"));QVERIFY(scripts.saveDraft());
        QSignalSpy errors(&runs,&ut::Executions::error);runs.runSelected({});
        QTRY_VERIFY_WITH_TIMEOUT(!runs.selectedRunning(),10000);
        QCOMPARE(errors.size(),0);QCOMPARE(runs.outcome(),QString("succeeded"));QVERIFY2(runs.status().contains("退出码 0"),qPrintable(runs.status()));QVERIFY(runs.output().contains("isolated-value"));
        QVERIFY(QFileInfo::exists(data+"/输出 结果/result.txt"));QVERIFY(QFileInfo::exists(data+"/输出 结果/legacy.txt"));QVERIFY(qEnvironmentVariable("UT_TEST_VALUE").isEmpty());
        QCOMPARE(QDir(data+"/runs").entryList(QDir::Dirs|QDir::NoDotAndDotDot).size(),0);
    }
    void scriptIndentationUndo(){
        QTextDocument doc;const QString source="甲\n  beta\nlast";doc.setPlainText(source);
        auto selection=ut::ScriptEditing::indentDocument(&doc,0,9,false);
        QCOMPARE(doc.toPlainText(),QString("    甲\n      beta\nlast"));
        QCOMPARE(selection["anchor"].toInt(),0);QCOMPARE(selection["position"].toInt(),17);
        doc.undo();QCOMPARE(doc.toPlainText(),source);doc.redo();QCOMPARE(doc.toPlainText(),QString("    甲\n      beta\nlast"));
        selection=ut::ScriptEditing::indentDocument(&doc,17,0,true);
        QCOMPARE(doc.toPlainText(),source);QCOMPARE(selection["anchor"].toInt(),9);QCOMPARE(selection["position"].toInt(),0);
        doc.setPlainText("\t  value");selection=ut::ScriptEditing::indentDocument(&doc,2,2,true);
        QCOMPARE(doc.toPlainText(),QString("  value"));QCOMPARE(selection["position"].toInt(),1);
        doc.setPlainText("abc");selection=ut::ScriptEditing::indentDocument(&doc,3,3,false);
        QCOMPARE(doc.toPlainText(),QString("abc "));QCOMPARE(selection["position"].toInt(),4);
        doc.undo();QCOMPARE(doc.toPlainText(),QString("abc"));
        doc.setPlainText("");selection=ut::ScriptEditing::indentDocument(&doc,0,0,true);QCOMPARE(doc.toPlainText(),QString());
    }
    void scriptHighlighting(){
        QTextDocument document;ut::ScriptHighlighter highlighter;highlighter.setDocument(&document);highlighter.setLanguage("python");
        const QString source="import os # comment\nvalue = '''hello\nreturn # string\n'''\nreturn 42";
        document.setPlainText(source);highlighter.rehighlight();
        auto color=[&](int line,int offset){for(const auto &range:document.findBlockByNumber(line).layout()->formats())if(offset>=range.start&&offset<range.start+range.length)return range.format.foreground().color();return QColor();};
        QVERIFY(color(0,0).isValid());QVERIFY(color(0,0)!=color(0,12));
        QCOMPARE(color(2,0),color(1,8));QCOMPARE(color(4,0),color(0,0));
        QCOMPARE(document.toPlainText(),source);
        auto light=color(0,0);highlighter.setDark(true);QVERIFY(color(0,0)!=light);
        document.setPlainText("value = 'hello'\nreturn 42");highlighter.rehighlight();QCOMPARE(document.firstBlock().userState(),0);QVERIFY(color(1,0)!=color(0,8));
        highlighter.setLanguage("powershell");document.setPlainText("<#\nreturn comment\n#>\n$x = @'\n# string\n'@\nreturn $x");highlighter.rehighlight();
        QCOMPARE(color(0,0),color(1,0));QCOMPARE(color(4,0),color(3,5));QVERIFY(color(6,0)!=color(1,0));
        highlighter.setLanguage("cmd");document.setPlainText("REM comment\nEcHo %PATH%\n:: comment");highlighter.rehighlight();
        QCOMPARE(color(0,0),color(2,0));QVERIFY(color(1,0).isValid());QVERIFY(color(1,0)!=color(1,5));
    }
    void lastTabClosesCleanly(){
        QTemporaryDir temporary;ut::Plugins plugins(temporary.path(),temporary.path());ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Sessions sessions(&plugins,&settings,&scripts);
        auto*pane=sessions.startProgram(qEnvironmentVariable("SystemRoot")+"/System32/cmd.exe",{"/D","/Q"},temporary.path(),QProcessEnvironment::systemEnvironment(),"cmd","test");
        QVERIFY(pane);QCOMPARE(sessions.rowCount(),1);QSignalSpy focus(&sessions,&ut::Sessions::focusChanged);sessions.closePane(pane);QCOMPARE(sessions.rowCount(),0);QCOMPARE(sessions.currentIndex(),-1);QVERIFY(!sessions.anyRunning());QVERIFY(!sessions.focusedPane());QVERIFY(!focus.isEmpty());
    }
    void closeTabThroughQmlButton(){
        QTemporaryDir temporary;QVERIFY(temporary.isValid());
        ut::Plugins plugins(temporary.path(),temporary.path());ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Sessions sessions(&plugins,&settings,&scripts);
        qmlRegisterUncreatableType<ut::Pane>("UTerminal",1,0,"Pane","Owned by Sessions");
        qmlRegisterType<ut::PaneHost>("UTerminal",1,0,"PaneHost");
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("Settings",&settings);
        engine.rootContext()->setContextProperty("Sessions",&sessions);
        engine.rootContext()->setContextProperty("Plugins",&plugins);
        QQuickWindow window;window.resize(1000,700);
        QQmlComponent component(&engine,QUrl::fromLocalFile(QStringLiteral(UTERMINAL_TEST_SOURCE_DIR "/resources/qml/TerminalPage.qml")));
        QScopedPointer<QObject> object(component.create());QVERIFY2(object,qPrintable(component.errorString()));
        auto *page=qobject_cast<QQuickItem*>(object.data());QVERIFY(page);page->setParentItem(window.contentItem());page->setSize(window.size());
        window.show();QVERIFY(QTest::qWaitForWindowExposed(&window));
        for(int i=0;i<3;++i)QVERIFY(sessions.startProgram(qEnvironmentVariable("SystemRoot")+"/System32/cmd.exe",{"/D","/Q"},temporary.path(),QProcessEnvironment::systemEnvironment(),"cmd",QString("test %1").arg(i)));
        auto findItem=[](auto &&self,QQuickItem *parent,const QString &name)->QQuickItem*{
            if(parent->objectName()==name)return parent;
            for(auto *child:parent->childItems())if(auto *found=self(self,child,name))return found;
            return nullptr;
        };
        // Close an inactive tab, then the active tab, then the final tab through
        // actual pointer delivery. A direct Sessions::closeTab call misses this path.
        for(const int index:{0,1,0}){
            QTest::qWait(100);
            auto *button=findItem(findItem,page,QString("closeTab_%1").arg(index));QVERIFY(button);
            const auto before=sessions.rowCount();
            QTest::mouseClick(&window,Qt::LeftButton,Qt::NoModifier,button->mapToScene(QPointF(button->width()/2,button->height()/2)).toPoint());
            QTRY_COMPARE(sessions.rowCount(),before-1);
        }
        QVERIFY(!sessions.anyRunning());QVERIFY(!sessions.focusedPane());QCOMPARE(sessions.currentIndex(),-1);
    }
    void selectedTabRemainsVisible(){
        QTemporaryDir temporary;QVERIFY(temporary.isValid());
        ut::Plugins plugins(temporary.path(),temporary.path());ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Sessions sessions(&plugins,&settings,&scripts);
        qmlRegisterUncreatableType<ut::Pane>("UTerminal",1,0,"Pane","Owned by Sessions");
        qmlRegisterType<ut::PaneHost>("UTerminal",1,0,"PaneHost");
        QQmlEngine engine;engine.rootContext()->setContextProperty("Settings",&settings);engine.rootContext()->setContextProperty("Sessions",&sessions);engine.rootContext()->setContextProperty("Plugins",&plugins);
        QQuickWindow window;window.resize(1000,700);
        QQmlComponent component(&engine,QUrl::fromLocalFile(QStringLiteral(UTERMINAL_TEST_SOURCE_DIR "/resources/qml/TerminalPage.qml")));
        QScopedPointer<QObject> object(component.create());QVERIFY2(object,qPrintable(component.errorString()));
        auto *page=qobject_cast<QQuickItem*>(object.data());QVERIFY(page);page->setParentItem(window.contentItem());page->setSize({930,700});
        auto *tabs=page->findChild<QQuickItem*>("terminalTabs");QVERIFY(tabs);
        auto *bar=page->findChild<QQuickItem*>("terminalTabBar");QVERIFY(bar);
        QCOMPARE(bar->height(),42.0);QCOMPARE(tabs->y(),4.0);QCOMPARE(tabs->height(),38.0);
        window.show();QVERIFY(QTest::qWaitForWindowExposed(&window));
        auto fullyVisible=[&]{
            auto *item=qvariant_cast<QQuickItem*>(tabs->property("currentItem"));
            if(!item||tabs->property("currentIndex").toInt()!=sessions.currentIndex())return false;
            const auto left=item->mapToItem(tabs,QPointF()).x();
            return left>=-0.5&&left+item->width()<=tabs->width()+0.5;
        };
        for(int i=0;i<9;++i){
            QVERIFY(sessions.startProgram(qEnvironmentVariable("SystemRoot")+"/System32/cmd.exe",{"/D","/Q"},temporary.path(),QProcessEnvironment::systemEnvironment(),"cmd",QString("test %1").arg(i)));
            QTRY_VERIFY(fullyVisible());
        }
        QVERIFY(tabs->property("contentX").toDouble()>0);
        sessions.setCurrentIndex(0);QTRY_VERIFY(fullyVisible());
        // This is the same navigation entry point used by Ctrl+Tab.
        for(int i=0;i<9;++i){sessions.nextTab();QTRY_VERIFY(fullyVisible());}
        sessions.setCurrentIndex(8);QTRY_VERIFY(fullyVisible());
        sessions.closeTab(8);QTRY_VERIFY(fullyVisible());
        const auto narrowWidth=tabs->width();
        window.resize(1362,700);page->setWidth(1292);QTRY_VERIFY(tabs->width()>narrowWidth);QTRY_VERIFY(fullyVisible());
        QTRY_VERIFY(tabs->property("tabWidth").toDouble()>100);
        sessions.setCurrentIndex(0);QTRY_VERIFY(fullyVisible());
        QTRY_VERIFY(qAbs(qvariant_cast<QQuickItem*>(tabs->property("currentItem"))->mapToItem(tabs,QPointF()).x())<0.5);
        window.resize(1000,700);page->setWidth(930);QTRY_COMPARE(tabs->width(),narrowWidth);QTRY_VERIFY(fullyVisible());
        QTRY_COMPARE(tabs->property("tabWidth").toDouble(),100.0);
        const auto wheelPosition=tabs->mapToScene(QPointF(tabs->width()/2,tabs->height()/2));
        const auto beforeWheel=tabs->property("contentX").toDouble();
        QWheelEvent wheel(wheelPosition,window.mapToGlobal(wheelPosition.toPoint()),QPoint(),QPoint(0,-120),Qt::NoButton,Qt::NoModifier,Qt::NoScrollPhase,false);
        QCoreApplication::sendEvent(&window,&wheel);
        QTRY_VERIFY(tabs->property("contentX").toDouble()>beforeWheel);
        const auto scroll=tabs->property("contentX").toDouble();
        sessions.renameTab(sessions.currentIndex(),"renamed");QTest::qWait(60);
        QCOMPARE(tabs->property("contentX").toDouble(),scroll);
        sessions.closeAll();QTRY_COMPARE(tabs->property("count").toInt(),0);
    }
    void processOutputAndExit(){
        ut::ProcessRunner runner;QSignalSpy done(&runner,&ut::ProcessRunner::finished);QByteArray bytes;
        connect(&runner,&ut::ProcessRunner::output,this,[&](const QByteArray &b){bytes+=b;});
        QVERIFY(runner.start(qEnvironmentVariable("SystemRoot")+"/System32/cmd.exe",{"/D","/Q","/C","echo native-runner"},QDir::tempPath(),QProcessEnvironment::systemEnvironment(),5));
        QTRY_COMPARE_WITH_TIMEOUT(done.size(),1,10000);
        QCOMPARE(done.first()[0].toInt(),0);QVERIFY2(bytes.contains("native-runner"),bytes.constData());
    }
    void missingProcess(){
        ut::ProcessRunner runner;QSignalSpy done(&runner,&ut::ProcessRunner::finished);
        runner.start("C:/uterminal-not-a-real-executable.exe",{},QDir::tempPath(),QProcessEnvironment::systemEnvironment(),5);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(),1,5000);QVERIFY(done.first()[0].toInt()!=0);
    }
    void processTimeout(){
        ut::ProcessRunner runner;QSignalSpy done(&runner,&ut::ProcessRunner::finished);
        QVERIFY(runner.start(qEnvironmentVariable("SystemRoot")+"/System32/cmd.exe",{"/D","/Q","/C","ping -n 30 127.0.0.1 >nul"},QDir::tempPath(),QProcessEnvironment::systemEnvironment(),1));
        QTRY_COMPARE_WITH_TIMEOUT(done.size(),1,7000);QVERIFY(done.first()[1].toString().contains(QStringLiteral("超时")));
    }
    void conptyRealProcess(){
        ut::ConPty terminal;QByteArray bytes;QSignalSpy done(&terminal,&ut::ConPty::finished);
        connect(&terminal,&ut::ConPty::output,this,[&](const QByteArray &b){bytes+=b;});
        QVERIFY(terminal.start(qEnvironmentVariable("SystemRoot")+"/System32/cmd.exe",{"/D","/Q","/C","echo conpty-live"},QDir::tempPath(),QProcessEnvironment::systemEnvironment()));
        QTRY_VERIFY_WITH_TIMEOUT(bytes.contains("conpty-live"),10000);QTRY_COMPARE_WITH_TIMEOUT(done.size(),1,10000);terminal.close();
    }
    void conptyShutdownWhileOutputFlows(){
        ut::ConPty terminal;QByteArray bytes;
        connect(&terminal,&ut::ConPty::output,this,[&](const QByteArray &b){bytes+=b;});
        QVERIFY(terminal.start(qEnvironmentVariable("SystemRoot")+"/System32/cmd.exe",{"/D","/Q","/C","for /L %i in (1,1,50000) do @echo output-%i"},QDir::tempPath(),QProcessEnvironment::systemEnvironment()));
        QTRY_VERIFY_WITH_TIMEOUT(!bytes.isEmpty(),5000);QElapsedTimer timer;timer.start();terminal.close();QVERIFY(timer.elapsed()<5000);
    }
    void rendererUnicodeAcrossChunks(){
        TerminalItem item;item.setSize({800,500});item.setSessionId("test");QTest::qWait(60);
        const auto bytes=QStringLiteral("    中文🙂  abc").toUtf8();
        for(auto byte:bytes)item.feedBytes(QByteArray(1,byte));
        item.selectAll();QVERIFY2(item.selectionText().contains(QStringLiteral("    中文🙂  abc")),qPrintable(item.selectionText()));
    }
    void hostRecreationPreservesBuffer(){
        ut::Pane pane;auto*first=new ut::PaneHost;first->setSize({800,500});first->setPane(&pane);QTest::qWait(60);pane.terminal()->feedBytes("persisted-buffer");delete first;
        ut::PaneHost second;second.setSize({800,500});second.setPane(&pane);pane.terminal()->selectAll();QVERIFY(pane.terminal()->selectionText().contains("persisted-buffer"));
    }
    void rightClickNeverReachesTui(){
        TerminalItem item;item.setSize({800,500});item.setSessionId("test");item.feedBytes("\x1b[?1000h\x1b[?1006h");
        QSignalSpy menu(&item,&TerminalItem::contextMenuRequested);QSignalSpy input(&item,&TerminalItem::inputGenerated);
        QMouseEvent press(QEvent::MouseButtonPress,QPointF(20,20),QPointF(20,20),Qt::RightButton,Qt::RightButton,Qt::NoModifier);
        QMouseEvent release(QEvent::MouseButtonRelease,QPointF(20,20),QPointF(20,20),Qt::RightButton,Qt::NoButton,Qt::NoModifier);
        QCoreApplication::sendEvent(&item,&press);QCoreApplication::sendEvent(&item,&release);QCOMPARE(menu.size(),1);QCOMPARE(input.size(),0);
    }
    void multilinePasteRequiresConfirmation(){
        TerminalItem item;item.setSessionId("test");QSignalSpy ask(&item,&TerminalItem::multilinePasteRequested);QSignalSpy input(&item,&TerminalItem::inputGenerated);
        QGuiApplication::clipboard()->setText("first\nsecond");item.pasteClipboard();QCOMPARE(ask.size(),1);QCOMPARE(input.size(),0);
        item.pasteText(ask.first().first().toString());QVERIFY(input.size()>0);
    }
};
QTEST_MAIN(RuntimeTests)
#include "runtime_tests.moc"
