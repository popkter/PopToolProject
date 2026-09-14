#include "pythonenvironment.h"
#include "plugins.h"
#include "infrastructure/processrunner.h"
#include "infrastructure/storage.h"
#include "domain/parameters.h"
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QTimer>
#include <QUuid>
namespace ut {
PythonEnvironment::PythonEnvironment(QString directory,Plugins *plugins,QObject *parent)
    :QObject(parent),m_directory(std::move(directory)),m_plugins(plugins){
    connect(plugins,&Plugins::leasesChanged,this,[this]{QTimer::singleShot(0,this,&PythonEnvironment::tryQueued);});
    connect(plugins,&Plugins::pythonSwitchRequested,this,&PythonEnvironment::requestSwitch);
}
PythonEnvironment::~PythonEnvironment(){if(m_process){disconnect(m_process,nullptr,this,nullptr);delete m_process;}if(!m_readLease.isEmpty())m_plugins->release("python",m_readLease);releaseLocks();}
QStringList PythonEnvironment::packageArguments(const QString &input,QString *error){
    // Accept distribution requirements, never pip switches or arbitrary shell text.
    static const QRegularExpression requirement("^[A-Za-z0-9][A-Za-z0-9._-]*(?:\\[[A-Za-z0-9_,.-]+\\])?(?:(?:==|!=|~=|>=|<=|>|<)[A-Za-z0-9*.+!_-]+(?:,(?:==|!=|~=|>=|<=|>|<)[A-Za-z0-9*.+!_-]+)*)?$");
    auto args=input.split(QRegularExpression("[\\s;]+"),Qt::SkipEmptyParts);
    if(args.isEmpty())*error=QStringLiteral("请输入包名");
    for(const auto &arg:args)if(!requirement.match(arg).hasMatch()){*error=QStringLiteral("包名或版本约束无效：")+arg;return {};}
    args.removeDuplicates();return args;
}
void PythonEnvironment::run(const QString &program,const QStringList &args,const QString &version,std::function<void()> success){
    m_captured.clear();m_decoder=QStringDecoder(QStringDecoder::Utf8);m_cancelled=false;auto*p=new ProcessRunner(this);m_process=p;
    connect(p,&ProcessRunner::output,this,[this](const QByteArray &bytes){m_captured+=bytes;if(m_captured.size()>2*1024*1024)m_captured.remove(0,m_captured.size()-2*1024*1024);m_log+=m_decoder(bytes);if(m_log.size()>256*1024)m_log.remove(0,m_log.size()-256*1024);emit changed();});
    connect(p,&ProcessRunner::finished,this,[this,p,success](int code,const QString &reason){m_process=nullptr;p->deleteLater();if(!m_readLease.isEmpty()){auto v=m_readLease;m_readLease.clear();m_plugins->release("python",v);}if(m_cancelled){fail(QStringLiteral("操作已取消"));return;}if(code||!reason.isEmpty()){fail(reason.isEmpty()?QStringLiteral("操作失败，退出码 %1。请查看日志。").arg(code):reason);return;}success();});
    p->start(program,args,QDir::homePath(),m_plugins->environment(version),600);
}
void PythonEnvironment::releaseLocks(){auto locks=m_locks;m_locks.clear();for(const auto &v:locks)m_plugins->releasePythonReservation(v);}
void PythonEnvironment::fail(const QString &message){m_busy=false;m_queued=false;m_confirming=false;m_whenIdle={};releaseLocks();m_status=message;emit changed();emit error(message);if(!m_temp.isEmpty()){QDir(m_temp).removeRecursively();m_temp.clear();}}
void PythonEnvironment::refresh(){inspect({{"action","info"}});}
void PythonEnvironment::probe(const QString &source,const QString &directory){
    auto parsed=Parameters::parse(source);if(!parsed.error.isEmpty()){emit error(parsed.error);return;}
    QVariantMap values;for(const auto &v:parsed.parameters){auto p=v.toObject();auto value=p["default"].toString();values[p["id"].toString()]=value.isEmpty()?"0":value;}
    QString problem;auto rendered=Parameters::render(source,values,&problem);if(!problem.isEmpty()){emit error(problem);return;}
    inspect({{"action","probe"},{"source",rendered},{"directory",directory}});
}
void PythonEnvironment::inspect(const QJsonObject &request){
    if(m_busy)return;if(!m_plugins->pythonReady()){emit error(QStringLiteral("请先安装 Python 插件"));return;}
    m_version=m_plugins->pythonVersion();if(m_plugins->pythonReserved(m_version)){emit error(QStringLiteral("该环境正在等待或进行依赖变更"));return;}
    m_busy=true;m_log.clear();m_status=QStringLiteral("正在检查 Python 环境…");m_plugins->acquire("python",m_version);m_readLease=m_version;
    m_temp=m_directory+"/staging/doctor-"+QUuid::createUuid().toString(QUuid::WithoutBraces);QDir().mkpath(m_temp);
    writeJson(m_temp+"/request.json",request);m_output=m_temp+"/result.json";
    // The runner completes asynchronously, with the same bootstrap as real scripts.
    const auto version=m_version;
    run(m_plugins->executable("python",version),{m_plugins->resourcePath("python-doctor.py"),m_temp+"/request.json",m_output},version,[this]{
        QString problem;auto result=readJson(m_output,&problem);if(result.isEmpty()){fail(problem.isEmpty()?QStringLiteral("诊断结果无效"):problem);return;}
        m_info=result;m_diagnostics=result["diagnostics"].toObject();m_status=QStringLiteral("环境检查完成");m_busy=false;QDir(m_temp).removeRecursively();m_temp.clear();emit changed();
    });
    emit changed();
}
void PythonEnvironment::tryQueued(){
    if(!m_queued||!m_whenIdle)return;
    for(const auto &v:m_locks)if(m_plugins->inUse("python",v))return;
    m_queued=false;auto action=std::move(m_whenIdle);m_whenIdle={};action();emit changed();
}
void PythonEnvironment::installPackages(const QString &input){
    if(m_busy)return;if(!m_plugins->pythonReady()){emit error(QStringLiteral("请先安装 Python 插件"));return;}
    QString problem;auto packages=packageArguments(input,&problem);if(!problem.isEmpty()){emit error(problem);return;}
    m_version=m_plugins->pythonVersion();if(!m_plugins->reservePython(m_version)){emit error(QStringLiteral("环境已被其他依赖任务锁定"));return;}
    m_locks={m_version};m_busy=true;m_queued=true;m_log.clear();m_status=QStringLiteral("等待使用此环境的脚本和终端结束…");
    m_whenIdle=[this,packages]{m_status=QStringLiteral("正在安装依赖…");QStringList args{"-m","pip","--isolated","install","--disable-pip-version-check"};args+=packages;
        run(m_plugins->environmentPath(m_version)+"/Scripts/python.exe",args,m_version,[this]{m_status=QStringLiteral("依赖安装完成");m_busy=false;releaseLocks();emit changed();});};
    tryQueued();emit changed();
}
void PythonEnvironment::installSuggested(){QStringList names;for(const auto &v:m_diagnostics["suggestions"].toArray())names.append(v.toString());installPackages(names.join(' '));}
void PythonEnvironment::requestSwitch(const QString &version){
    if(m_busy){emit error(QStringLiteral("请先完成或取消当前环境操作"));return;}
    if(!m_plugins->installedVersion("python",version)){emit error(QStringLiteral("目标 Python 版本尚未安装"));return;}
    if(version==m_plugins->pythonVersion())return;
    m_version=m_plugins->pythonVersion();m_target=version;m_requirements.clear();m_log.clear();m_busy=true;
    // Export is read-only: existing tasks retain their original environment.
    if(m_plugins->pythonReserved(m_version)){fail(QStringLiteral("当前环境正在变更依赖"));return;}
    m_plugins->acquire("python",m_version);m_readLease=m_version;const auto source=m_version;m_status=QStringLiteral("正在导出当前环境依赖…");
    run(m_plugins->environmentPath(source)+"/Scripts/python.exe",{"-m","pip","--isolated","freeze","--disable-pip-version-check"},source,[this]{m_requirements=QString::fromUtf8(m_captured).trimmed();m_confirming=true;m_status=QStringLiteral("请选择是否在目标版本重新安装这些依赖");emit changed();emit switchConfirmationRequested();});
    emit changed();
}
void PythonEnvironment::confirmSwitch(bool migrate){
    if(!m_confirming||m_target.isEmpty())return;m_confirming=false;
    if(!m_plugins->reservePython(m_target)){fail(QStringLiteral("目标环境正在变更依赖"));return;}
    m_locks={m_target};m_queued=true;m_status=QStringLiteral("等待目标环境空闲…");
    m_whenIdle=[this,migrate]{
        if(!migrate||m_requirements.isEmpty()){validateAndActivate();return;}
        m_temp=m_directory+"/staging/migration-"+QUuid::createUuid().toString(QUuid::WithoutBraces);QDir().mkpath(m_temp);
        QFile file(m_temp+"/requirements.txt");if(!file.open(QIODevice::WriteOnly)){fail(file.errorString());return;}file.write(m_requirements.toUtf8());file.close();
        m_status=QStringLiteral("正在为目标 Python 重新安装依赖…");
        run(m_plugins->environmentPath(m_target)+"/Scripts/python.exe",{"-m","pip","--isolated","install","--disable-pip-version-check","-r",file.fileName()},m_target,[this]{validateAndActivate();});
    };tryQueued();emit changed();
}
void PythonEnvironment::validateAndActivate(){
    m_status=QStringLiteral("正在验证新环境依赖…");
    run(m_plugins->environmentPath(m_target)+"/Scripts/python.exe",{"-m","pip","--isolated","check"},m_target,[this]{
        if(!m_plugins->commitActivation("python",m_target)){fail(QStringLiteral("活动版本保存失败"));return;}
        m_status=QStringLiteral("已切换到 Python ")+m_target;m_busy=false;releaseLocks();if(!m_temp.isEmpty()){QDir(m_temp).removeRecursively();m_temp.clear();}emit changed();
    });
}
void PythonEnvironment::cancel(){
    if(!m_busy)return;m_cancelled=true;
    if(m_process)m_process->stop();else fail(QStringLiteral("操作已取消"));
}
}
