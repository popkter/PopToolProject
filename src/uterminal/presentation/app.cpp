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
void App::setPage(int p){if(p<0||p>2)return;bool entering=p!=m_page;m_page=p;emit pageChanged();if(entering&&p==1&&!m_plugins->powerShellReady()&&m_sessions->rowCount()==0)emit pluginRequested("powershell");}
void App::showNotice(const QString &text){m_notice=text;emit noticeChanged();}
void App::newScript(){m_scripts->newDraft();emit editorRequested();}
void App::editScript(){if(m_scripts->selected().isEmpty())return;m_scripts->editSelected();emit editorRequested();}
void App::shareScript(){auto text=m_scripts->exportSelected();if(!text.isEmpty()){copyText(text);showNotice(QStringLiteral("脚本 JSON 已复制"));}}
void App::importClipboard(bool replace){if(!replace)m_import=QApplication::clipboard()->text();auto result=m_scripts->importText(m_import,replace);if(result["status"]=="duplicate")emit replaceImportRequested();else showNotice(result["status"]=="ok"?QStringLiteral("脚本已导入"):result["message"].toString());}
void App::importCollection(){auto dir=chooseDirectory();if(!dir.isEmpty())showNotice(m_scripts->importCollection(dir));}
void App::exportCollection(){auto dir=chooseDirectory();if(!dir.isEmpty()&&m_scripts->exportCollection(dir))showNotice(QStringLiteral("脚本集合已导出"));}
QString App::chooseFile(){return QFileDialog::getOpenFileName(nullptr,QStringLiteral("选择文件"));}
QString App::chooseDirectory(){return QFileDialog::getExistingDirectory(nullptr,QStringLiteral("选择目录"));}
void App::copyText(const QString &text){QApplication::clipboard()->setText(text);}
void App::openDirectory(const QString &path){QDesktopServices::openUrl(QUrl::fromLocalFile(path));}
void App::showPlugin(const QString &kind){emit pluginRequested(kind);}
void App::noteEditorInput(){
    const auto draft=m_scripts->draft();const auto kind=draft["language"].toString();
    if(draft["code"].toString().isEmpty()||m_editorPrompts.contains(kind))return;
    if((kind=="python"&&!m_plugins->pythonReady())||(kind=="powershell"&&!m_plugins->powerShellReady())){
        m_editorPrompts.insert(kind);emit pluginRequested(kind);
    }
}
void App::requestQuit(){if(m_sessions->anyRunning()||m_runs->runningCount()>0||m_plugins->busy()||m_python->busy()||m_updates->downloading())emit quitConfirmationRequested();else quitNow();}
void App::quitNow(){m_updates->cancelDownload();m_python->cancel();m_plugins->cancel();m_runs->stopAll();m_sessions->closeAll();QApplication::quit();}
}
