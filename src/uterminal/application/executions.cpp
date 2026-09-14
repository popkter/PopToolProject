#include "executions.h"
#include "plugins.h"
#include "domain/parameters.h"
#include "infrastructure/processrunner.h"
#include "infrastructure/scriptfiles.h"
#include "presentation/scripts.h"
#include "presentation/settings.h"
#include "presentation/sessions.h"
#include <QDir>
#include <QFile>
#include <QUuid>
#include <QScopeGuard>
#include <algorithm>

namespace ut {
Executions::Executions(QString directory,Plugins *plugins,Settings *settings,Scripts *scripts,Sessions *sessions,QObject *parent)
    :QObject(parent),m_directory(std::move(directory)),m_plugins(plugins),m_settings(settings),m_scripts(scripts),m_sessions(sessions){
    connect(scripts,&Scripts::selectionChanged,this,&Executions::changed);
    m_flush.setInterval(50);connect(&m_flush,&QTimer::timeout,this,[this]{if(m_dirty){m_dirty=false;emit changed();}});m_flush.start();
}
Executions::~Executions(){
    cancelRun();m_waitingFor=nullptr;
    for(auto *r:m_runs){
        if(r->process){disconnect(r->process,nullptr,this,nullptr);delete r->process;}
        if(r->pane&&r->running)m_sessions->endPane(r->pane);
        if(r->running)finish(r,-1,QStringLiteral("应用退出"));
        if(r->timeout)delete r->timeout;
        cleanupSource(r->directory);delete r;
    }
}
void Executions::cleanupSource(const QString &directory){
    const auto root=QDir::cleanPath(m_directory+"/runs")+'/';const auto path=QDir::cleanPath(directory);
    if(path.startsWith(root,Qt::CaseInsensitive))QDir(path).removeRecursively();
}
int Executions::runningCount()const{int count=0;for(auto*r:m_runs)if(r->running&&!r->interactive)++count;return count;}
Executions::Run *Executions::selected()const{return m_runs.value(m_scripts->selected()["id"].toString());}
QString Executions::output()const{
    auto*r=selected();if(!r)return {};auto text=r->output;
    for(const auto &secret:r->secrets)text.replace(secret,QStringLiteral("***"));
    // Withhold a trailing partial match while the process can still append its
    // remainder, so split writes cannot expose a secret before replacement.
    if(r->running){qsizetype held=0;for(const auto &secret:r->secrets)
        for(qsizetype n=qMin(text.size(),secret.size()-1);n>held;--n)if(text.endsWith(secret.first(n))){held=n;break;}
        if(held)text.chop(held);
    }
    return text;
}
QString Executions::status()const{auto*r=selected();return r?r->status:QStringLiteral("尚未运行");}
QString Executions::outcome()const{auto*r=selected();return !r?QStringLiteral("idle"):r->running?QStringLiteral("running"):r->succeeded?QStringLiteral("succeeded"):QStringLiteral("failed");}
bool Executions::selectedRunning()const{auto*r=selected();return r&&r->running;}
bool Executions::selectedInteractive()const{auto*r=selected();return r&&r->interactive;}
void Executions::runSelected(const QVariantMap &parameters,bool interactive){
    if(m_plugins->pythonReady()&&m_plugins->pythonReserved()){emit error(QStringLiteral("Python 环境正在等待或进行依赖修改，请完成或取消后再启动任务"));return;}
    auto script=m_scripts->get(m_scripts->selected()["id"].toString());if(script.isEmpty())return;
    if(auto*r=m_runs.value(script["id"].toString());r&&r->running){emit error(QStringLiteral("此脚本正在运行"));return;}
    auto language=script["language"].toString();
    if((language=="python"&&!m_plugins->pythonReady())||(language=="powershell"&&!m_plugins->powerShellReady())){emit pluginRequired(language);return;}
    auto inputs=parameters;
    const auto definitions=Parameters::parse(Scripts::parameterSource(script),script.value("parameterMetadata").toArray());
    if(!definitions.error.isEmpty()){emit error(definitions.error);return;}
    for(const auto &entry:definitions.parameters){const auto p=entry.toObject();const auto id=p["id"].toString();if(!inputs.contains(id))inputs[id]=p["default"].toVariant();}
    script=Scripts::resolvedArgumentConditions(script,inputs);
    QString problem;Parameters::render(Scripts::parameterSource(script),inputs,&problem,script.value("parameterMetadata").toArray());if(!problem.isEmpty()){emit error(problem);return;}
    interactive=interactive||script["executionMode"].toString()=="interactive";
    m_pending=script;m_parameters=inputs;m_interactive=interactive;m_replace=!interactive&&runningCount()>=m_settings->concurrency();
    if(m_replace)emit confirmationRequested(QStringLiteral("并发名额已满。是否停止最早启动的任务，等待它退出后运行此脚本？"));
    else if(script["confirmBeforeRun"].toBool())emit confirmationRequested(QStringLiteral("确认运行“%1”？").arg(script["title"].toString()));
    else confirmRun();
}
void Executions::cancelRun(){m_pending={};m_parameters.clear();m_replace=false;}
void Executions::confirmRun(){
    if(m_pending.isEmpty())return;
    if(m_replace){Run *oldest=nullptr;for(auto*r:m_runs)if(r->running&&!r->interactive&&(!oldest||r->clock.elapsed()>oldest->clock.elapsed()))oldest=r;
        m_replace=false;if(oldest&&oldest->process){m_waitingFor=oldest->process;oldest->process->stop();return;}}
    auto script=m_pending;auto parameters=m_parameters;bool interactive=m_interactive;cancelRun();launch(script,parameters,interactive);
}
void Executions::append(Run *r,const QByteArray &bytes){r->output+=r->decoder(bytes);constexpr int limit=1024*1024;if(r->output.size()>limit)r->output.remove(0,r->output.size()-limit);m_dirty=true;}
void Executions::launch(QJsonObject script,QVariantMap parameters,bool interactive){
    if(m_plugins->pythonReady()&&m_plugins->pythonReserved()){emit error(QStringLiteral("Python 环境正在修改依赖，请稍后再试"));return;}
    auto id=script["id"].toString();if(auto*r=m_runs.value(id);r&&r->running)return;
    auto language=script["language"].toString();
    if((language=="python"&&!m_plugins->pythonReady())||(language=="powershell"&&!m_plugins->powerShellReady())){emit pluginRequired(language);return;}
    if(!interactive&&runningCount()>=m_settings->concurrency()){emit error(QStringLiteral("并发名额已被其他任务占用，请重试"));return;}
    QString problem=Scripts::argumentError(script);if(!problem.isEmpty()){emit error(problem);return;}
    auto resolved=parameters;const auto definitions=Parameters::parse(Scripts::parameterSource(script),script.value("parameterMetadata").toArray());
    if(!definitions.error.isEmpty()){emit error(definitions.error);return;}
    for(const auto &entry:definitions.parameters){const auto p=entry.toObject();if(!resolved.contains(p["id"].toString()))resolved[p["id"].toString()]=p["default"].toVariant();}
    auto code=Parameters::render(script["code"].toString(),resolved,&problem,script.value("parameterMetadata").toArray());if(!problem.isEmpty()){emit error(problem);return;}
    QStringList scriptArguments;
    for(const auto &entry:script["arguments"].toArray()){
        const auto value=Parameters::render(entry.toString(),resolved,&problem,script.value("parameterMetadata").toArray());
        if(!problem.isEmpty()||value.contains(QChar(0))){emit error(problem.isEmpty()?QStringLiteral("命令行参数包含空字符"):problem);return;}
        scriptArguments.append(value);
    }
    problem=Scripts::environmentError(script["env"]);if(!problem.isEmpty()){emit error(problem);return;}
    auto cwd=script["workingDirectory"].toString();
    const bool useOutputDirectory=cwd.isEmpty()&&script["useOutputDirectoryAsWorkingDirectory"].toBool();
    if(cwd.isEmpty())cwd=QDir::homePath();
    if(!useOutputDirectory&&!QFileInfo(cwd).isDir()){emit error(QStringLiteral("工作目录不存在"));return;}
    auto outputDirectory=script["outputDirectory"].toString();
    if(outputDirectory.isEmpty())outputDirectory=m_directory+"/outputs/"+QUuid::createUuid().toString(QUuid::WithoutBraces);
    else if(QDir::isRelativePath(outputDirectory))outputDirectory=QDir(cwd).absoluteFilePath(outputDirectory);
    outputDirectory=QDir::cleanPath(outputDirectory);
    if(!QDir().mkpath(outputDirectory)){emit error(QStringLiteral("无法创建输出目录：")+outputDirectory);return;}
    if(useOutputDirectory)cwd=outputDirectory;
    const auto directory=m_directory+"/runs/"+QUuid::createUuid().toString(QUuid::WithoutBraces);QDir().mkpath(directory);
    auto sourceCleanup=qScopeGuard([this,directory]{cleanupSource(directory);});
    if(!materializeScriptFiles(script,directory,&problem)){emit error(problem);return;}
    auto path=directory+"/"+script["bundleEntryPoint"].toString("script."+(language=="python"?QString("py"):language=="cmd"?QString("cmd"):QString("ps1")));
    code.replace("\r\n","\n");code.replace('\r','\n');
    if(language=="cmd")code="@chcp 65001 >nul\n"+code;
    if(language=="powershell"){
        auto profile=m_plugins->resourcePath("terminal-profile.ps1");profile.replace("'","''");
        code=". '"+profile+"'\n"+code;
    }
    if(language!="python")code.replace("\n","\r\n");
    QFile file(path);if(!file.open(QIODevice::WriteOnly)){emit error(file.errorString());return;}
    auto bytes=code.toUtf8();if(language=="powershell")bytes.prepend("\xef\xbb\xbf");if(file.write(bytes)!=bytes.size()){emit error(file.errorString());return;}file.close();
    auto*r=new Run;r->id=id;r->directory=directory;r->interactive=interactive;
    for(const auto &entry:definitions.parameters){const auto p=entry.toObject();const auto value=resolved.value(p["id"].toString()).toString();if(p["kind"].toString()=="secret"&&!value.isEmpty()&&!r->secrets.contains(value))r->secrets.append(value);}
    std::sort(r->secrets.begin(),r->secrets.end(),[](const QString &a,const QString &b){return a.size()>b.size();});
    sourceCleanup.dismiss();
    if(m_plugins->pythonReady())r->pythonVersion=m_plugins->pythonVersion();
    auto *previous=m_runs.take(id);if(previous){if(previous->process)delete previous->process;delete previous;}m_runs.insert(id,r);
    QString program;QStringList arguments;
    if(language=="python"){r->pythonVersion=m_plugins->pythonVersion();program=m_plugins->executable("python");arguments={"-u",path};}
    else if(language=="powershell"){r->powerShellVersion=m_plugins->powerShellVersion();program=m_plugins->executable("powershell");arguments={"-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File",path};}
    else {program=qEnvironmentVariable("SystemRoot")+"/System32/cmd.exe";arguments={"/D","/Q","/C",path};}
    arguments.append(scriptArguments);
    auto environment=m_plugins->environment(r->pythonVersion);
    const auto additions=script["env"].toObject();for(auto i=additions.begin();i!=additions.end();++i)environment.insert(i.key(),i.value().toString());
    environment.insert("UTERMINAL_OUTPUT_DIR",QDir::toNativeSeparators(outputDirectory));
    environment.insert("POPTOOLS_OUTPUT_DIR",QDir::toNativeSeparators(outputDirectory));
    r->running=true;r->status=QStringLiteral("正在运行");r->clock.start();m_scripts->setRunning(id,true);m_scripts->recordUse(id);
    if(interactive){
        r->pane=m_sessions->startProgram(program,arguments,cwd,environment,language,script["title"].toString());
        if(!r->pane){finish(r,-1,QStringLiteral("无法创建交互会话"));return;}
        connect(r->pane,&Pane::ended,this,[this,r](int code,const QString &reason){finish(r,code,r->stopReason.isEmpty()?reason:r->stopReason);});
        connect(r->pane,&QObject::destroyed,this,[this,r]{if(r->running)finish(r,-1,QStringLiteral("会话已关闭"));});
        const int seconds=script["timeoutSeconds"].toInt(300);
        if(seconds>0){
            r->timeout=new QTimer(this);r->timeout->setSingleShot(true);
            connect(r->timeout,&QTimer::timeout,this,[this,r]{
                if(!r->running)return;r->stopReason=QStringLiteral("运行超时");
                if(r->pane)m_sessions->endPane(r->pane);
                finish(r,-1,r->stopReason);
            });
            r->timeout->start(qMin(seconds,86400)*1000);
        }
        emit interactiveStarted();
    }else{
        m_plugins->acquire("python",r->pythonVersion);m_plugins->acquire("powershell",r->powerShellVersion);
        auto *p=new ProcessRunner(this);r->process=p;
        connect(p,&ProcessRunner::output,this,[this,r](const QByteArray&data){append(r,data);});
        connect(p,&ProcessRunner::finished,this,[this,r,p](int code,const QString&reason){finish(r,code,reason);if(m_waitingFor==p){m_waitingFor=nullptr;QTimer::singleShot(0,this,&Executions::confirmRun);}});
        p->start(program,arguments,cwd,environment,script["timeoutSeconds"].toInt(300));
    }emit changed();
}
void Executions::finish(Run *r,int code,const QString &reason){
    if(!r->running)return;r->running=false;r->succeeded=code==0&&reason.isEmpty();r->status=QStringLiteral("退出码 %1 · %2 秒%3").arg(code).arg(r->clock.elapsed()/1000.0,0,'f',2).arg(reason.isEmpty()?QString():" · "+reason);
    if(r->timeout){r->timeout->stop();r->timeout->deleteLater();r->timeout=nullptr;}
    if(r->pane){disconnect(&r->pane->process,nullptr,this,nullptr);disconnect(r->pane,nullptr,this,nullptr);}
    if(!r->interactive){m_plugins->release("python",r->pythonVersion);m_plugins->release("powershell",r->powerShellVersion);}
    m_scripts->setRunning(r->id,false);
    // Rendered code can contain private parameter values; remove it after the run.
    cleanupSource(r->directory);
    emit changed();
}
void Executions::stopSelected(){auto*r=selected();if(!r||!r->running)return;if(r->process)r->process->stop();else if(r->pane){r->stopReason=QStringLiteral("用户结束会话");m_sessions->endPane(r->pane);finish(r,-1,r->stopReason);}}
void Executions::stopAll(){cancelRun();m_waitingFor=nullptr;for(auto*r:m_runs)if(r->running){if(r->process)r->process->stop();else if(r->pane){m_sessions->endPane(r->pane);finish(r,-1,QStringLiteral("用户结束会话"));}}}
void Executions::clearOutput(){if(auto*r=selected()){r->output.clear();emit changed();}}
}
