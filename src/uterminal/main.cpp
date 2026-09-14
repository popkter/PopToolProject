#include <QApplication>
#include <QDir>
#include <QFontDatabase>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QFile>
#include <QMutex>
#include <QTimer>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QWheelEvent>
#include <QMimeData>
#include <QDragEnterEvent>
#include <QDropEvent>
#include "infrastructure/storage.h"
#include "presentation/app.h"
#include "presentation/settings.h"
#include "presentation/scripts.h"
#include "presentation/sessions.h"
#include "presentation/scripthighlighter.h"
#include "presentation/scriptediting.h"
#include "application/plugins.h"
#include "application/executions.h"
#include "application/pythonenvironment.h"
#include "application/updates.h"

int main(int argc,char **argv){
    QApplication application(argc,argv);
    application.setOrganizationName("UTerminal");application.setApplicationName("UTerminal");application.setApplicationVersion(QStringLiteral(UTERMINAL_VERSION));
    QQuickStyle::setStyle("Basic");
    QString resources=qEnvironmentVariable("UTERMINAL_RESOURCES");
    if(resources.isEmpty())resources=QCoreApplication::applicationDirPath()+"/resources";
#ifdef UTERMINAL_SOURCE_RESOURCES
    if(!QFile::exists(resources+"/qml/Main.qml"))resources=QStringLiteral(UTERMINAL_SOURCE_RESOURCES);
#endif
    QFontDatabase::addApplicationFont(resources+"/fonts/MaterialIconsRound-Regular.otf");
    application.setFont(QFont("Microsoft YaHei UI",10));application.setWindowIcon(QIcon(resources+"/icons/app-icon.ico"));
    const auto data=ut::dataDirectory();
    QDir().mkpath(data);
    static QFile log(data+"/application.log");
    log.open(QIODevice::WriteOnly|QIODevice::Append);
    qInstallMessageHandler([](QtMsgType,const QMessageLogContext &,const QString &message){
        static QMutex mutex;QMutexLocker lock(&mutex);log.write(message.toUtf8()+'\n');log.flush();
    });
    ut::Settings settings(data);ut::Scripts scripts(data);ut::Plugins plugins(data,resources);
    ut::PythonEnvironment python(data,&plugins);
    ut::Updates updates(data,&settings,&plugins);
    QObject::connect(&application,&QCoreApplication::aboutToQuit,&updates,&ut::Updates::launchInstallerAfterExit);
    ut::Sessions sessions(&plugins,&settings,&scripts);ut::Executions runs(data,&plugins,&settings,&scripts,&sessions);
    ut::App app(resources,&scripts,&plugins,&sessions,&runs,&python,&updates);
    QObject::connect(&settings,&ut::Settings::error,&app,&ut::App::showNotice);
    QObject::connect(&python,&ut::PythonEnvironment::error,&app,&ut::App::showNotice);
    qmlRegisterUncreatableType<TerminalItem>("UTerminal",1,0,"TerminalItem","由会话管理器创建");
    qmlRegisterUncreatableType<ut::Pane>("UTerminal",1,0,"Pane","由会话管理器创建");
    qmlRegisterType<ut::PaneHost>("UTerminal",1,0,"PaneHost");
    qmlRegisterType<ut::ScriptHighlighter>("UTerminal",1,0,"ScriptHighlighter");
    qmlRegisterType<ut::ScriptEditing>("UTerminal",1,0,"ScriptEditing");
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("App",&app);engine.rootContext()->setContextProperty("Settings",&settings);
    engine.rootContext()->setContextProperty("Scripts",&scripts);engine.rootContext()->setContextProperty("Plugins",&plugins);
    engine.rootContext()->setContextProperty("Sessions",&sessions);engine.rootContext()->setContextProperty("Runs",&runs);
    engine.rootContext()->setContextProperty("Python",&python);
    engine.rootContext()->setContextProperty("Updates",&updates);
    QObject::connect(&engine,&QQmlApplicationEngine::objectCreationFailed,&application,[]{QCoreApplication::exit(1);},Qt::QueuedConnection);
    engine.load(QUrl::fromLocalFile(resources+"/qml/Main.qml"));
    if(engine.rootObjects().isEmpty())return 1;
    if(application.arguments().contains("--open-terminal")){
        const auto arguments=application.arguments();const int directoryIndex=arguments.indexOf("--directory");
        const auto directory=directoryIndex>=0&&directoryIndex+1<arguments.size()?arguments[directoryIndex+1]:QString();
        app.setPage(1);sessions.openDirectory(directory);
    }
    if(application.arguments().contains("--smoke-test")){
        const auto args=application.arguments();const int pageIndex=args.indexOf("--smoke-page");
        if(args.contains("--smoke-small"))if(auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first()))window->resize(1000,700);
        const auto pluginIndex=args.indexOf("--smoke-plugin");
        if(pluginIndex>=0&&pluginIndex+1<args.size())app.showPlugin(args[pluginIndex+1]);
        if(args.contains("--smoke-file-drop")){
            scripts.newDraft("echo ${文件@file}","cmd");scripts.updateDraft("title",QStringLiteral("文件拖入验证"));scripts.saveDraft();app.setPage(0);
            QTimer::singleShot(900,&application,[&]{
                auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
                std::function<QQuickItem*(QQuickItem*)> find=[&](QQuickItem *item)->QQuickItem*{
                    if(item->objectName()==QStringLiteral("parameterDrop_文件"))return item;
                    for(auto *child:item->childItems())if(auto *found=find(child))return found;return nullptr;
                };
                auto *target=find(window->contentItem());if(!target){application.exit(2);return;}
                const auto point=target->mapToScene({target->width()/2,target->height()/2});
                QMimeData mime;const auto path=QStringLiteral("C:/中文 folder/100% # file.txt");mime.setUrls({QUrl::fromLocalFile(path)});
                QDragEnterEvent enter(point.toPoint(),Qt::CopyAction,&mime,Qt::LeftButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&enter);
                QDropEvent drop(point,Qt::CopyAction,&mime,Qt::LeftButton,Qt::NoModifier);QCoreApplication::sendEvent(window,&drop);
                if(!drop.isAccepted() || scripts.parameterValues()[QStringLiteral("文件")].toString()!=QDir::toNativeSeparators(path)){qCritical("File parameter drop failed");application.exit(2);}
            });
        }
        if(args.contains("--smoke-order")){
            QStringList ids;
            for(int i=0;i<3;++i){scripts.newDraft("echo order","cmd");scripts.updateDraft("title",QStringLiteral("排序验证 %1").arg(i+1));scripts.saveDraft();ids.append(scripts.selected()["id"].toString());}
            scripts.setSortMode("custom");app.setPage(0);
            QTimer::singleShot(1000,&application,[&,ids]{
                auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
                std::function<QQuickItem*(QQuickItem*,const QString&)> find=[&](QQuickItem *item,const QString &name)->QQuickItem*{
                    if(item->objectName()==name)return item;for(auto *child:item->childItems())if(auto *found=find(child,name))return found;return nullptr;
                };
                auto *from=find(window->contentItem(),"scriptDrag_2");auto *to=find(window->contentItem(),"scriptDrag_0");
                if(!from||!to){application.exit(2);return;}
                const auto start=from->mapToScene({from->width()/2,from->height()/2});const auto end=to->mapToScene({to->width()/2,to->height()/2});
                QMouseEvent press(QEvent::MouseButtonPress,start,start,Qt::LeftButton,Qt::LeftButton,Qt::NoModifier);
                QMouseEvent move(QEvent::MouseMove,end,end,Qt::NoButton,Qt::LeftButton,Qt::NoModifier);
                QMouseEvent release(QEvent::MouseButtonRelease,end,end,Qt::LeftButton,Qt::NoButton,Qt::NoModifier);
                QCoreApplication::sendEvent(window,&press);QCoreApplication::sendEvent(window,&move);QCoreApplication::sendEvent(window,&release);
                if(scripts.customOrder()!=QStringList{ids[2],ids[0],ids[1]}){qCritical("Order smoke failed: pointer drag did not reorder scripts");application.exit(2);}
            });
        }
        if(pageIndex>=0&&pageIndex+1<args.size())app.setPage(args[pageIndex+1].toInt());
        if(args.contains("--smoke-python")){
            if(auto *dialog=engine.rootObjects().first()->findChild<QObject*>("globalPythonEnvironment"))QMetaObject::invokeMethod(dialog,"open");
        }
        if(args.contains("--smoke-editor")){
            app.newScript();
            scripts.updateDraft("title", "高亮验证脚本");
            scripts.updateDraft("language", "python");
            scripts.updateDraft("code", "import os\n\n# 中文注释与参数\ndef greet(name):\n    message = '''多行字符串\n第二行内容'''\n    print(name, message, 42)\n\ngreet('${名称:用户}')\n");
        }
        if(args.contains("--smoke-parameters"))QTimer::singleShot(900,&application,[&]{
            auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());auto *scroll=window->findChild<QQuickItem*>("scriptParameterScroll");
            if(!scroll||scroll->height()<60){qCritical("Parameter smoke failed: unusable scroll viewport");application.exit(2);return;}
            const auto point=scroll->mapToScene(QPointF(scroll->width()/2,scroll->height()/2));
            QWheelEvent wheel(point,window->mapToGlobal(point.toPoint()),QPoint(),QPoint(0,-12000),Qt::NoButton,Qt::NoModifier,Qt::NoScrollPhase,false);
            QCoreApplication::sendEvent(window,&wheel);
        });
        if(args.contains("--smoke-description"))QTimer::singleShot(900,&application,[&]{
            auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
            auto *preview=window->findChild<QQuickItem*>("scriptDescriptionPreview");auto *run=window->findChild<QQuickItem*>("scriptRunButton");
            auto *output=window->findChild<QQuickItem*>("scriptOutputPanel");auto *open=window->findChild<QObject*>("scriptDescriptionOpen");
            if(!preview||!preview->property("truncated").toBool()||preview->height()>80||!run||run->mapToScene(QPointF(0,run->height())).y()>window->height()||!output||output->height()<159||output->mapToScene(QPointF(0,output->height())).y()>window->height()||!open){qCritical("Description smoke failed: preview or actions overflow");application.exit(2);return;}
            QMetaObject::invokeMethod(open,"clicked");
        });
        if(args.contains("--smoke-terminal")){app.setPage(1);sessions.newTab();if(args.contains("--smoke-split"))sessions.split(false);}
        if(args.contains("--smoke-close-pane"))QTimer::singleShot(1800,&application,[&]{
            auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
            const auto panes=sessions.panes();if(panes.size()!=2){application.exit(2);return;}
            QPointer<ut::Pane> survivor=panes.first().value<ut::Pane*>();
            std::function<QQuickItem*(QQuickItem*)> find=[&](QQuickItem *item)->QQuickItem*{
                if(item->objectName()=="closePane_1")return item;
                for(auto *child:item->childItems())if(auto *found=find(child))return found;return nullptr;
            };
            auto *button=find(window->contentItem());if(!button){application.exit(2);return;}
            const auto point=button->mapToScene({button->width()/2,button->height()/2});
            QMouseEvent press(QEvent::MouseButtonPress,point,point,Qt::LeftButton,Qt::LeftButton,Qt::NoModifier);
            QMouseEvent release(QEvent::MouseButtonRelease,point,point,Qt::LeftButton,Qt::NoButton,Qt::NoModifier);
            QCoreApplication::sendEvent(window,&press);QCoreApplication::sendEvent(window,&release);
            if(sessions.panes().size()!=1 || !survivor || !survivor->running() || sessions.focusedPane()!=survivor){qCritical("Close pane button failed");application.exit(2);}
        });
        if(args.contains("--smoke-arguments"))QTimer::singleShot(1000,&application,[&]{
            scripts.setDraftArgument(0,"--name");scripts.setDraftArgument(1,QStringLiteral("${名字:中文 空格}"));scripts.setDraftArgument(2,"");
            if(auto *dialog=engine.rootObjects().first()->findChild<QObject*>("scriptArgumentsDialog"))QMetaObject::invokeMethod(dialog,"open");
            else application.exit(2);
        });
        if(args.contains("--smoke-icons"))QTimer::singleShot(1000,&application,[&]{
            auto *dialog=engine.rootObjects().first()->findChild<QObject*>("scriptIconDialog");
            if(!dialog){application.exit(2);return;}
            QMetaObject::invokeMethod(dialog,"open");
            QTimer::singleShot(120,&application,[&,dialog]{
                std::function<bool(QQuickItem*)> choose=[&](QQuickItem *item){
                    if(!item)return false;
                    if(item->property("symbol").toString()=="folder")return QMetaObject::invokeMethod(item,"clicked");
                    for(auto *child:item->childItems())if(choose(child))return true;
                    return false;
                };
                const bool selected=choose(dialog->property("contentItem").value<QQuickItem*>());
                if(!selected||scripts.draft().value("icon").toString()!="folder"||ut::readJson(data+"/draft.json")["icon"].toString()!="folder"){
                    qCritical("Icon smoke failed: selection or draft persistence");application.exit(2);return;
                }
                QMetaObject::invokeMethod(dialog,"open");
            });
        });
        if(args.contains("--smoke-search"))QTimer::singleShot(900,&application,[&]{
            if(auto *pane=sessions.focusedPane()){
                pane->terminal()->setSearchText("PS");pane->terminal()->openSearch();
            }
        });
        QTimer::singleShot(250,&application,[&]{if(auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first()))window->grabWindow();});
        if(args.contains("--smoke-editor"))QTimer::singleShot(600,&application,[&,args]{
            auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
            auto *code=window->findChild<QQuickItem*>("scriptCodeEditor");
            if(!code){qCritical("Editor smoke failed: missing code editor");application.exit(2);return;}
            code->forceActiveFocus();
            const QString original=code->property("text").toString();
            auto key=[&](int value,Qt::KeyboardModifiers modifiers=Qt::NoModifier){
                QKeyEvent press(QEvent::KeyPress,value,modifiers),release(QEvent::KeyRelease,value,modifiers);
                QCoreApplication::sendEvent(window,&press);QCoreApplication::sendEvent(window,&release);
            };
            QMetaObject::invokeMethod(code,"selectAll");key(Qt::Key_Tab);
            const QString indented=code->property("text").toString();
            bool ok=indented.startsWith("    import")&&indented.contains("\n    def greet");
            if(auto *pluginDialog=window->findChild<QObject*>("globalPluginDialog")){
                if(!plugins.pythonReady())ok&=pluginDialog->property("visible").toBool();
                QMetaObject::invokeMethod(pluginDialog,"close");code->forceActiveFocus();
            }
            key(Qt::Key_Backtab,Qt::ShiftModifier);ok&=code->property("text").toString()==original;
            key(Qt::Key_Z,Qt::ControlModifier);ok&=code->property("text").toString()==indented;
            key(Qt::Key_Y,Qt::ControlModifier);ok&=code->property("text").toString()==original;
            ok&=scripts.draft().value("code").toString()==original;
            if(auto *pluginDialog=window->findChild<QObject*>("globalPluginDialog"))ok&=!pluginDialog->property("visible").toBool();
            if(!ok){qCritical("Editor smoke failed: indentation, undo/redo or draft synchronization");application.exit(2);}
            if(args.contains("--smoke-expanded"))if(auto *toggle=window->findChild<QObject*>("scriptAdvancedToggle"))QMetaObject::invokeMethod(toggle,"clicked");
        });
        QTimer::singleShot(args.contains("--smoke-terminal")?5000:1500,&application,[&,args]{
            if(auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first())){
                std::function<void(QQuickItem*)> polish=[&](QQuickItem *item){item->ensurePolished();for(auto *child:item->childItems())polish(child);};
                polish(window->contentItem());polish(window->contentItem());
                if(args.contains("--smoke-parameters")){
                    auto *scroll=window->findChild<QQuickItem*>("scriptParameterScroll");const auto definitions=scripts.parameters();
                    const auto lastName=definitions.isEmpty()?QString():"scriptParameter_"+definitions.last().toMap()["id"].toString();
                    std::function<QQuickItem*(QQuickItem*)> findParameter=[&](QQuickItem *item)->QQuickItem*{if(item->objectName()==lastName)return item;for(auto *child:item->childItems())if(auto *found=findParameter(child))return found;return nullptr;};
                    auto *last=lastName.isEmpty()?nullptr:findParameter(window->contentItem());
                    auto *run=window->findChild<QQuickItem*>("scriptRunButton");auto *output=window->findChild<QQuickItem*>("scriptOutputPanel");
                    if(!scroll||!last||last->mapToItem(scroll,QPointF()).y()<-1||last->mapToItem(scroll,QPointF(0,last->height())).y()>scroll->height()+1||!run||run->mapToScene(QPointF(0,run->height())).y()>window->height()||!output||output->mapToScene(QPointF(0,output->height())).y()>window->height()||runs.runningCount()!=0){qCritical("Parameter smoke failed: viewport=%f lastY=%f lastHeight=%f",scroll?scroll->height():-1.0,(scroll&&last)?last->mapToItem(scroll,QPointF()).y():-1.0,last?last->height():-1.0);window->grabWindow().save(data+"/parameter-smoke-failure.png");application.exit(2);return;}
                }
                if(args.contains("--smoke-description")){
                    auto *dialog=window->findChild<QObject*>("scriptDescriptionDialog");auto *text=window->findChild<QObject*>("scriptDescriptionText");auto *scroll=window->findChild<QObject*>("scriptDescriptionScroll");
                    auto *content=scroll?scroll->property("contentItem").value<QObject*>():nullptr;
                    if(!dialog||!dialog->property("visible").toBool()||!text||text->property("text").toString()!=scripts.selected()["description"].toString()||!content||content->property("contentHeight").toDouble()<=content->property("height").toDouble()){qCritical("Description smoke failed: full text or scroll area missing");application.exit(2);return;}
                    const auto bottom=content->property("contentHeight").toDouble()-content->property("height").toDouble();content->setProperty("contentY",bottom);
                    if(qAbs(content->property("contentY").toDouble()-bottom)>1){qCritical("Description smoke failed: cannot reach end");application.exit(2);return;}
                }
                if(args.contains("--smoke-editor")){
                    auto *viewport=window->findChild<QQuickItem*>("scriptCodeViewport");auto *save=window->findChild<QQuickItem*>("scriptSaveButton");auto *body=window->findChild<QQuickItem*>("scriptEditorBody");
                    if(!viewport||!save||!body||viewport->height()<109||viewport->width()<200||save->mapToScene(QPointF(0,save->height())).y()>window->height()||save->mapToScene(QPointF()).y()<0||save->mapToItem(body,QPointF(0,save->height())).y()>body->height()+1){
                        qCritical("Editor smoke failed: code viewport or save button is outside usable layout");application.exit(2);return;
                    }
                }
            }
            if(args.contains("--smoke-terminal")){
                auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
                const auto panes=sessions.panes();
                if(panes.isEmpty()){application.exit(2);return;}
                for(const auto &value:panes){
                    auto *pane=value.value<ut::Pane*>();auto *terminal=pane->terminal();terminal->selectAll();
                    const bool prompt=terminal->selectionText().contains("PS ");terminal->clearSelection();
                    if(!prompt||terminal->width()<window->width()*0.8/panes.size()||terminal->height()<window->height()*0.8){qCritical("Terminal smoke failed: prompt or pane layout");application.exit(2);return;}
                }
            }
            const int screenshotIndex=args.indexOf("--screenshot");
            if(screenshotIndex>=0&&screenshotIndex+1<args.size()){
                if(auto *window=qobject_cast<QQuickWindow*>(engine.rootObjects().first()))window->grabWindow().save(args[screenshotIndex+1]);
            }
            application.quit();
        });
    }
    return application.exec();
}
