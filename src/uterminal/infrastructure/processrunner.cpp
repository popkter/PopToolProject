#include "processrunner.h"
#include <Windows.h>
#include <vector>

namespace ut {
struct ProcessRunner::State {
    HANDLE job=nullptr;
    STARTUPINFOEXW startup{};
    std::vector<char> attributes;
    ~State(){if(startup.lpAttributeList)DeleteProcThreadAttributeList(startup.lpAttributeList);if(job)CloseHandle(job);}
};
ProcessRunner::ProcessRunner(QObject *parent):QObject(parent){
    m_process.setProcessChannelMode(QProcess::MergedChannels);
    m_timeout.setSingleShot(true);m_forceStop.setSingleShot(true);m_forceStop.setInterval(1500);
    connect(&m_process,&QProcess::readyRead,this,[this]{emit output(m_process.readAll());});
    connect(&m_process,&QProcess::errorOccurred,this,[this](QProcess::ProcessError error){if(error==QProcess::FailedToStart){m_timeout.stop();emit finished(-1,m_process.errorString());}});
    connect(&m_process,qOverload<int,QProcess::ExitStatus>(&QProcess::finished),this,[this](int code,QProcess::ExitStatus status){
        m_timeout.stop();m_forceStop.stop();emit output(m_process.readAll());
        // Also reclaim descendants that outlive the script's root process.
        killTree();
        emit finished(code,m_reason.isEmpty()&&status==QProcess::CrashExit?QStringLiteral("进程异常退出"):m_reason);
    });
    connect(&m_timeout,&QTimer::timeout,this,[this]{m_reason=QStringLiteral("运行超时");stop();});
    connect(&m_forceStop,&QTimer::timeout,this,&ProcessRunner::killTree);
}
ProcessRunner::~ProcessRunner(){killTree();if(running())m_process.waitForFinished(3000);}
bool ProcessRunner::start(const QString &program,const QStringList &args,const QString &directory,const QProcessEnvironment &environment,int timeoutSeconds){
    if(running())return false;
    m_reason.clear();m_state=std::make_unique<State>();auto *state=m_state.get();
    state->job=CreateJobObjectW(nullptr,nullptr);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};limits.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if(!state->job||!SetInformationJobObject(state->job,JobObjectExtendedLimitInformation,&limits,sizeof(limits))){emit finished(-1,QStringLiteral("创建脚本进程组失败"));return false;}
    SIZE_T size=0;InitializeProcThreadAttributeList(nullptr,1,0,&size);state->attributes.resize(size);
    state->startup.lpAttributeList=reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(state->attributes.data());
    if(!InitializeProcThreadAttributeList(state->startup.lpAttributeList,1,0,&size)){state->startup.lpAttributeList=nullptr;emit finished(-1,QStringLiteral("初始化脚本进程属性失败"));return false;}
    if(!UpdateProcThreadAttribute(state->startup.lpAttributeList,0,PROC_THREAD_ATTRIBUTE_JOB_LIST,&state->job,sizeof(HANDLE),nullptr,nullptr)){emit finished(-1,QStringLiteral("绑定脚本进程组失败"));return false;}
    m_process.setCreateProcessArgumentsModifier([state](QProcess::CreateProcessArguments *arguments){
        state->startup.StartupInfo=*reinterpret_cast<STARTUPINFOW*>(arguments->startupInfo);
        state->startup.StartupInfo.cb=sizeof(STARTUPINFOEXW);
        arguments->startupInfo=reinterpret_cast<Q_STARTUPINFO*>(&state->startup);
        arguments->flags|=EXTENDED_STARTUPINFO_PRESENT|CREATE_NO_WINDOW;
    });
    m_process.setWorkingDirectory(directory);m_process.setProcessEnvironment(environment);
    m_process.start(program,args);
    if(timeoutSeconds>0)m_timeout.start(qMin(qint64(timeoutSeconds)*1000,qint64(INT_MAX)));
    return true;
}
void ProcessRunner::stop(){if(!running())return;if(m_reason.isEmpty())m_reason=QStringLiteral("用户停止");m_process.terminate();m_forceStop.start();}
void ProcessRunner::killTree(){if(m_state&&m_state->job)TerminateJobObject(m_state->job,1);}
}
