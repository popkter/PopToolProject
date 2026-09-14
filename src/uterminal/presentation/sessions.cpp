#include "sessions.h"
#include <utility>
#include "application/plugins.h"
#include "settings.h"
#include "scripts.h"
#include <QClipboard>
#include <QDir>
#include <QGuiApplication>
#include <QQmlEngine>
#include <QUuid>

namespace ut {
Pane::Pane(QObject *parent):QObject(parent),id(QUuid::createUuid().toString(QUuid::WithoutBraces)),m_terminal(new TerminalItem) {
    m_terminal->setParent(this);
    QQmlEngine::setObjectOwnership(m_terminal,QQmlEngine::CppOwnership);
    m_terminal->setSessionId(id);
    connect(&process,&ConPty::output,m_terminal,&TerminalItem::feedBytes);
    connect(m_terminal,&TerminalItem::inputGenerated,this,[this](const QString &,const QString &text){process.write(text.toUtf8());});
    connect(m_terminal,&TerminalItem::terminalSizeChanged,&process,&ConPty::resize);
    connect(m_terminal,&TerminalItem::terminalTitleChanged,this,[this](const QString &,const QString &title){setTitle(title);});
    connect(&process,&ConPty::finished,this,[this](int code){m_finished=true;m_exitCode=code;m_terminal->feedBytes(QString("\r\n[进程已退出：%1]\r\n").arg(code).toUtf8());emit changed();emit ended(code,{});});
}
void Pane::captureRuntime(){
    m_runtimeLabel=language=="powershell"?QStringLiteral("PowerShell ")+powerShellVersion:language=="python"?QStringLiteral("Python ")+pythonVersion:QStringLiteral("CMD");
    if(language!="python"&&!pythonVersion.isEmpty())m_runtimeLabel+=QStringLiteral(" · Python ")+pythonVersion;
    emit changed();
}
Pane::~Pane(){process.close();m_terminal->setParentItem(nullptr);delete m_terminal;}
void Pane::setTitle(const QString &title){if(title==m_title)return;m_title=title.left(200);emit changed();}
PaneHost::~PaneHost(){if(m_pane && m_pane->terminal()->parentItem()==this)m_pane->terminal()->setParentItem(nullptr);}
void PaneHost::setPane(Pane *pane){
    if(m_pane==pane)return;
    if(m_pane && m_pane->terminal()->parentItem()==this)m_pane->terminal()->setParentItem(nullptr);
    m_pane=pane;
    if(pane){pane->terminal()->setParentItem(this);pane->terminal()->setSize(size());}
    emit paneChanged();
}
void PaneHost::geometryChange(const QRectF &now,const QRectF &before){QQuickItem::geometryChange(now,before);if(m_pane)m_pane->terminal()->setSize(now.size());}

Sessions::Sessions(Plugins *plugins,Settings *settings,Scripts *scripts,QObject *parent)
    :QAbstractListModel(parent),m_plugins(plugins),m_settings(settings),m_scripts(scripts),m_historyPrediction(settings->historyPrediction()){
    connect(settings,&Settings::changed,this,[this]{
        for(const auto &tab:m_tabs)for(auto *p:tab.panes){p->terminal()->setColors(m_settings->terminalForeground(),m_settings->terminalBackground());p->terminal()->setFontSize(m_settings->fontSize());p->terminal()->setFontFamily(m_settings->fontFamily());}
        const bool desired=m_settings->historyPrediction();
        if(desired!=m_historyPrediction){m_historyPrediction=desired;m_historyErrorReported=false;applyHistoryPredictionToAll();emit menuChanged();}
    });
}
Sessions::~Sessions(){closeAll();}
int Sessions::rowCount(const QModelIndex &parent)const{return parent.isValid()?0:int(m_tabs.size());}
QVariant Sessions::data(const QModelIndex &index,int role)const{
    if(!index.isValid()||index.row()<0||index.row()>=m_tabs.size())return {};
    if(role==Qt::UserRole+1)return m_tabs[index.row()].title;
    if(role==Qt::UserRole+2)return index.row()==m_current;
    return {};
}
QHash<int,QByteArray> Sessions::roleNames()const{return {{Qt::UserRole+1,"tabTitle"},{Qt::UserRole+2,"active"}};}
QVariantList Sessions::panes()const{QVariantList result;if(m_current>=0&&m_current<m_tabs.size())for(auto *p:m_tabs[m_current].panes)result.append(QVariant::fromValue(p));return result;}
bool Sessions::vertical()const{return m_current>=0&&m_current<m_tabs.size()&&m_tabs[m_current].vertical;}
bool Sessions::anyRunning()const{for(const auto &t:m_tabs)for(auto *p:t.panes)if(p->running())return true;return false;}
bool Sessions::historyPrediction()const{return m_historyPrediction;}
void Sessions::setCurrentIndex(int i){if(i<0||i>=m_tabs.size())return;m_current=i;emit dataChanged(index(0),index(rowCount()-1));emit changed();if(!m_tabs[i].panes.isEmpty())focusPane(m_tabs[i].panes.first());}
void Sessions::nextTab(){if(!m_tabs.isEmpty())setCurrentIndex((m_current+1)%int(m_tabs.size()));}
Pane *Sessions::makePane(){
    auto *pane=new Pane(this);QQmlEngine::setObjectOwnership(pane,QQmlEngine::CppOwnership);
    pane->terminal()->setColors(m_settings->terminalForeground(),m_settings->terminalBackground());pane->terminal()->setFontSize(m_settings->fontSize());pane->terminal()->setFontFamily(m_settings->fontFamily());
    connect(&pane->process,&ConPty::error,this,&Sessions::error);
    connect(&pane->process,&ConPty::finished,this,[this,pane]{release(pane);emit changed();});
    connect(pane,&Pane::changed,this,[this,pane]{for(int i=0;i<m_tabs.size();++i)if(m_tabs[i].panes.contains(pane)&&!m_tabs[i].fixedTitle){m_tabs[i].title=pane->title();emit dataChanged(index(i),index(i));}});
    connect(pane->terminal(),&QQuickItem::activeFocusChanged,this,[this,pane]{if(pane->terminal()->hasActiveFocus()){m_focused=pane;emit focusChanged();}});
    connect(pane->terminal(),&TerminalItem::contextMenuRequested,this,[this,pane](qreal x,qreal y){m_menuPane=pane;m_menuText=pane->terminal()->selectionText();auto pos=pane->terminal()->mapToScene({x,y});emit menuChanged();emit contextMenuRequested(pos.x(),pos.y());});
    connect(pane->terminal(),&TerminalItem::multilinePasteRequested,this,[this,pane](const QString &text){m_pastePane=pane;m_pasteText=text;emit pasteConfirmationRequested(text);});
    connect(pane->terminal(),&TerminalItem::shellCommandSubmitted,this,[pane](const QString &){pane->m_shellPromptReady=false;});
    connect(pane->terminal(),&TerminalItem::shellControlReceived,this,[this,pane](const QString &,const QString &message){handleShellControl(pane,message);});
    return pane;
}
bool Sessions::startShell(Pane *pane,const QString &directory){
    if(m_plugins->pythonReady()&&m_plugins->pythonReserved()){emit error(QStringLiteral("Python 环境有待完成的依赖修改，请先结束现有会话或取消该修改"));return false;}
    if(!m_plugins->powerShellReady()){emit pluginRequired("powershell");return false;}
    pane->powerShellVersion=m_plugins->powerShellVersion();
    if(m_plugins->pythonReady())pane->pythonVersion=m_plugins->pythonVersion();
    m_plugins->acquire("powershell",pane->powerShellVersion);m_plugins->acquire("python",pane->pythonVersion);
    auto profile=m_plugins->resourcePath("terminal-profile.ps1");profile.replace("'","''");
    auto ok=pane->process.start(m_plugins->executable("powershell",pane->powerShellVersion),{"-NoLogo","-NoProfile","-NoExit","-Command",". '"+profile+"'"},resolveDirectory(directory),m_plugins->environment(pane->pythonVersion));
    if(!ok)release(pane);else pane->captureRuntime();return ok;
}
void Sessions::release(Pane *pane){m_plugins->release("powershell",pane->powerShellVersion);m_plugins->release("python",pane->pythonVersion);pane->powerShellVersion.clear();pane->pythonVersion.clear();}
void Sessions::appendTab(Pane *pane,const QString &title,bool fixedTitle,bool activate){beginInsertRows({},int(m_tabs.size()),int(m_tabs.size()));m_tabs.append({title,fixedTitle,false,{pane}});endInsertRows();if(activate)setCurrentIndex(int(m_tabs.size())-1);else emit changed();}
void Sessions::activatePaneTab(Pane *pane){for(int i=0;i<m_tabs.size();++i)if(m_tabs[i].panes.contains(pane)){setCurrentIndex(i);return;}}
void Sessions::newTab(){
    if(!m_pendingDirectories.isEmpty()){
        if(!m_plugins->powerShellReady()){emit pluginRequired("powershell");return;}
        const auto directories=std::exchange(m_pendingDirectories,{});
        for(const auto &directory:directories)openDirectory(directory);
    }else openDirectory({});
}
void Sessions::ensureTab(){
    if(!m_tabs.isEmpty())return;
    if(!m_pendingDirectories.isEmpty()){newTab();return;}
    openDirectory({});
}
QString Sessions::resolveDirectory(const QString &path){
    if(path.isEmpty())return QDir::homePath();const QFileInfo info(path);
    if(info.isDir())return info.absoluteFilePath();if(info.isFile())return info.absolutePath();return QDir::homePath();
}
void Sessions::openDirectory(const QString &path){
    openDirectoryTab(path,true);
}
Pane *Sessions::openDirectoryTab(const QString &path,bool activate,bool notifyMissing){
    const auto directory=resolveDirectory(path);
    if(!m_plugins->powerShellReady()){
        if(m_pendingDirectories.size()<128)m_pendingDirectories.append(directory);
        else emit error(QStringLiteral("待打开目录过多，请安装 PowerShell 后重试。"));
        if(notifyMissing)emit pluginRequired("powershell");return nullptr;
    }
    auto *pane=makePane();if(!startShell(pane,directory)){delete pane;return nullptr;}
    appendTab(pane,QStringLiteral("Power'Shell"),true,activate);return pane;
}
void Sessions::split(bool vertical){if(m_current<0){newTab();return;}auto *pane=makePane();if(!startShell(pane)){delete pane;return;}m_tabs[m_current].vertical=vertical;m_tabs[m_current].panes.append(pane);emit changed();focusPane(pane);}
void Sessions::focusPane(Pane *pane){m_focused=pane;if(pane)pane->terminal()->forceActiveFocus();emit focusChanged();}
void Sessions::endPane(Pane *pane){if(!pane)return;const bool wasRunning=pane->running();pane->process.close();release(pane);if(wasRunning)emit pane->ended(-1,QStringLiteral("会话已关闭"));emit pane->changed();emit changed();}
void Sessions::interrupt(Pane *pane){if(pane)pane->process.interrupt();}
void Sessions::toggleHistoryPrediction(){m_settings->setHistoryPrediction(!m_historyPrediction);}
void Sessions::applyHistoryPredictionToAll(){for(const auto &tab:m_tabs)for(auto *pane:tab.panes)applyHistoryPrediction(pane);}
void Sessions::applyHistoryPrediction(Pane *pane){
    if(!pane||pane->language!="powershell"||!pane->running()||!pane->m_shellPromptReady||!pane->m_historySupported||pane->m_historyInFlight)return;
    if(pane->m_historyApplied&&*pane->m_historyApplied==m_historyPrediction)return;
    pane->m_historyInFlight=true;
    pane->process.write(m_historyPrediction?QByteArray("\x18\x19",2):QByteArray("\x18\x0e",2));
}
void Sessions::handleShellControl(Pane *pane,const QString &message){
    if(!pane||pane->language!="powershell")return;
    if(message=="prompt:ready"){
        pane->m_shellPromptReady=true;pane->m_historySupported=true;applyHistoryPrediction(pane);return;
    }
    if(message=="prompt:unsupported"){
        pane->m_shellPromptReady=true;pane->m_historySupported=false;
        if(m_historyPrediction&&!m_historyErrorReported){m_historyErrorReported=true;emit error(QStringLiteral("当前 PowerShell 的 PSReadLine 不支持历史预测列表。"));}
        return;
    }
    if(message=="history:on"||message=="history:off"){
        pane->m_historyInFlight=false;pane->m_shellPromptReady=true;pane->m_historyApplied=message=="history:on";applyHistoryPrediction(pane);return;
    }
    if(message.startsWith("history:error")){
        pane->m_historyInFlight=false;pane->m_shellPromptReady=false;
        if(!m_historyErrorReported){m_historyErrorReported=true;emit error(QStringLiteral("无法应用 PowerShell 历史预测设置，将在下次提示符出现时重试。"));}
    }
}
void Sessions::closePane(Pane *pane){for(int i=0;i<m_tabs.size();++i){auto &t=m_tabs[i];if(!t.panes.contains(pane))continue;if(t.panes.size()==1){closeTab(i);return;}const bool wasFocused=m_focused==pane;t.panes.removeOne(pane);endPane(pane);delete pane;emit changed();if(i==m_current&&wasFocused)focusPane(t.panes.first());return;}}
void Sessions::closeTab(int i){if(i<0||i>=m_tabs.size())return;beginRemoveRows({},i,i);auto tab=m_tabs.takeAt(i);if(m_current>=i)--m_current;m_current=m_tabs.isEmpty()?-1:qBound(0,m_current,int(m_tabs.size())-1);endRemoveRows();for(auto*p:tab.panes){endPane(p);delete p;}emit changed();if(m_current>=0)setCurrentIndex(m_current);else focusPane(nullptr);}
void Sessions::closeOthers(int i){for(int n=int(m_tabs.size())-1;n>=0;--n)if(n!=i)closeTab(n);}
void Sessions::closeRight(int i){for(int n=int(m_tabs.size())-1;n>i;--n)closeTab(n);}
void Sessions::renameTab(int i,const QString &title){if(i<0||i>=m_tabs.size()||title.trimmed().isEmpty())return;m_tabs[i].title=title.trimmed().left(200);m_tabs[i].fixedTitle=true;emit dataChanged(index(i),index(i));}
void Sessions::copyMenuSelection(){if(!m_menuText.isEmpty())QGuiApplication::clipboard()->setText(m_menuText);}
void Sessions::draftFromSelection(){if(m_menuText.trimmed().isEmpty())return;m_scripts->newDraft(m_menuText,m_menuPane?m_menuPane->language:"powershell");emit draftRequested();}
void Sessions::acceptPaste(){if(m_pastePane&&m_pastePane->running())m_pastePane->terminal()->pasteText(m_pasteText);cancelPaste();}
void Sessions::cancelPaste(){m_pastePane=nullptr;m_pasteText.clear();}
void Sessions::closeAll(){m_pendingDirectories.clear();while(!m_tabs.isEmpty())closeTab(int(m_tabs.size())-1);}
Pane *Sessions::startProgram(const QString &program,const QStringList &args,const QString &cwd,const QProcessEnvironment &env,const QString &language,const QString &title){
    if(m_plugins->pythonReady()&&m_plugins->pythonReserved()){emit error(QStringLiteral("环境正在修改依赖"));return nullptr;}
    auto *pane=makePane();pane->language=language;pane->terminal()->setInputLanguage(language);pane->setTitle(title);
    if(m_plugins->pythonReady())pane->pythonVersion=m_plugins->pythonVersion();
    if(language=="powershell")pane->powerShellVersion=m_plugins->powerShellVersion();
    m_plugins->acquire("python",pane->pythonVersion);m_plugins->acquire("powershell",pane->powerShellVersion);
    if(!pane->process.start(program,args,cwd,env)){release(pane);delete pane;return nullptr;}
    pane->captureRuntime();appendTab(pane,title);return pane;
}
}
