#include "conpty.h"
#include <Windows.h>
#include <QDir>
#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>
#include <vector>

namespace ut {
struct ConPty::State {
    HPCON console=nullptr;
    HANDLE input=nullptr,output=nullptr,process=nullptr,job=nullptr;
    std::thread reader,writer,closer;
    std::mutex mutex;
    std::condition_variable wake;
    std::deque<QByteArray> writes;
    QByteArray pending;
    std::atomic<bool> stopping=false,exited=false,readDone=false;
    int code=0;
    bool reported=false;
    bool exitObserved=false;
};
ConPty::ConPty(QObject *parent):QObject(parent){m_pump.setInterval(16);connect(&m_pump,&QTimer::timeout,this,&ConPty::pump);}
ConPty::~ConPty(){close();}
QString ConPty::quoteArgument(const QString &a){
    if(!a.isEmpty()&&!a.contains(' ')&&!a.contains('\t')&&!a.contains('"'))return a;
    QString out="\"";int slashes=0;
    for(auto c:a){if(c=='\\'){++slashes;continue;}if(c=='"'){out+=QString(slashes*2+1,'\\');out+=c;}else{out+=QString(slashes,'\\');out+=c;}slashes=0;}
    return out+QString(slashes*2,'\\')+'"';
}
bool ConPty::start(const QString &program,const QStringList &args,const QString &directory,const QProcessEnvironment &environment,int columns,int rows){
    close();m_state=std::make_unique<State>();auto*s=m_state.get();
    HANDLE readInput=nullptr,writeOutput=nullptr;
    auto fail=[&](QString message){if(readInput)CloseHandle(readInput);if(writeOutput)CloseHandle(writeOutput);emit error(message+QString::number(GetLastError()));close();return false;};
    if(!CreatePipe(&readInput,&s->input,nullptr,0)||!CreatePipe(&s->output,&writeOutput,nullptr,0))return fail(QStringLiteral("创建终端管道失败："));
    COORD size{SHORT(qBound(1,columns,32767)),SHORT(qBound(1,rows,32767))};
    if(FAILED(CreatePseudoConsole(size,readInput,writeOutput,0,&s->console)))return fail(QStringLiteral("创建 ConPTY 失败："));
    CloseHandle(readInput);readInput=nullptr;CloseHandle(writeOutput);writeOutput=nullptr;
    SIZE_T attrSize=0;InitializeProcThreadAttributeList(nullptr,1,0,&attrSize);
    std::vector<char> attrs(attrSize);STARTUPINFOEXW si{};si.StartupInfo.cb=sizeof(si);
    // Override inherited redirected std handles. Null handles let ConPTY supply
    // its console handles, including when the host was launched by CTest/CI.
    si.StartupInfo.dwFlags=STARTF_USESTDHANDLES;
    si.lpAttributeList=reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attrs.data());
    if(!InitializeProcThreadAttributeList(si.lpAttributeList,1,0,&attrSize))return fail(QStringLiteral("初始化进程属性失败："));
    if(!UpdateProcThreadAttribute(si.lpAttributeList,0,PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,s->console,sizeof(HPCON),nullptr,nullptr)){
        DeleteProcThreadAttributeList(si.lpAttributeList);return fail(QStringLiteral("设置伪控制台失败："));
    }
    QString command=quoteArgument(QDir::toNativeSeparators(program));for(const auto &a:args)command+=' '+quoteArgument(a);
    auto keys=environment.keys();keys.sort(Qt::CaseInsensitive);QString block;
    for(const auto&key:keys)block+=key+'='+environment.value(key)+QChar(0);block+=QChar(0);
    std::wstring cmd=command.toStdWString(),cwd=QDir::toNativeSeparators(directory).toStdWString(),env=block.toStdWString();
    PROCESS_INFORMATION pi{};
    BOOL ok=CreateProcessW(reinterpret_cast<LPCWSTR>(program.utf16()),cmd.data(),nullptr,nullptr,FALSE,
        EXTENDED_STARTUPINFO_PRESENT|CREATE_UNICODE_ENVIRONMENT|CREATE_SUSPENDED,env.data(),cwd.empty()?nullptr:cwd.c_str(),&si.StartupInfo,&pi);
    DeleteProcThreadAttributeList(si.lpAttributeList);
    if(!ok)return fail(QStringLiteral("启动 Shell 失败："));
    s->process=pi.hProcess;s->job=CreateJobObjectW(nullptr,nullptr);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};limits.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if(!s->job||!SetInformationJobObject(s->job,JobObjectExtendedLimitInformation,&limits,sizeof(limits))||!AssignProcessToJobObject(s->job,s->process)){
        TerminateProcess(s->process,1);CloseHandle(pi.hThread);return fail(QStringLiteral("无法建立终端进程归属："));
    }
    ResumeThread(pi.hThread);CloseHandle(pi.hThread);
    s->reader=std::thread([s]{
        char buffer[32768];DWORD count=0;
        while(ReadFile(s->output,buffer,sizeof(buffer),&count,nullptr)&&count){
            std::unique_lock lock(s->mutex);
            s->wake.wait(lock,[s]{return s->stopping||s->pending.size()<4*1024*1024;});
            if(s->stopping)continue;
            s->pending.append(buffer,count);
        }
        s->readDone=true;
    });
    s->writer=std::thread([s]{
        while(!s->stopping){QByteArray bytes;{
            std::unique_lock lock(s->mutex);s->wake.wait(lock,[s]{return s->stopping||!s->writes.empty();});
            if(s->stopping)break;bytes=std::move(s->writes.front());s->writes.pop_front();}
            qsizetype offset=0;while(offset<bytes.size()&&!s->stopping){DWORD wrote=0;if(!WriteFile(s->input,bytes.constData()+offset,DWORD(bytes.size()-offset),&wrote,nullptr)||!wrote)break;offset+=wrote;}
        }
    });m_pump.start();return true;
}
void ConPty::pump(){
    if(!m_state)return;auto*s=m_state.get();QByteArray data;{std::lock_guard lock(s->mutex);data.swap(s->pending);}s->wake.notify_all();if(!data.isEmpty())emit output(data);
    if(m_state.get()!=s)return;
    if(s->process&&WaitForSingleObject(s->process,0)==WAIT_OBJECT_0&&!s->exitObserved){
        DWORD code=0;GetExitCodeProcess(s->process,&code);s->code=int(code);s->exitObserved=true;
        if(s->job)TerminateJobObject(s->job,1);
        // Closing ConPTY may wait for output to drain; keep the GUI pump and
        // reader alive while a separate thread closes the console endpoint.
        auto console=s->console;s->console=nullptr;
        s->closer=std::thread([console]{if(console)ClosePseudoConsole(console);});
    }
    if(s->exitObserved&&s->readDone&&!s->reported){
        {std::lock_guard lock(s->mutex);if(!s->pending.isEmpty())return;}
        s->reported=true;s->exited=true;emit finished(s->code);
    }
}
bool ConPty::running()const{return m_state&&m_state->process&&!m_state->exited;}
void ConPty::write(const QByteArray &bytes){if(!running()||bytes.isEmpty())return;{std::lock_guard lock(m_state->mutex);m_state->writes.push_back(bytes);}m_state->wake.notify_all();}
void ConPty::interrupt(){write(QByteArray(1,'\x03'));}
void ConPty::resize(int c,int r){if(m_state&&m_state->console)ResizePseudoConsole(m_state->console,{SHORT(qBound(1,c,32767)),SHORT(qBound(1,r,32767))});}
void ConPty::close(){
    m_pump.stop();if(!m_state)return;auto*s=m_state.get();
    // Change the wait predicate while holding its mutex, so a worker cannot
    // miss the shutdown notification between checking the predicate and waiting.
    {std::lock_guard lock(s->mutex);s->stopping=true;}s->wake.notify_all();
    if(s->job)TerminateJobObject(s->job,1);
    if(s->writer.joinable()){CancelSynchronousIo(static_cast<HANDLE>(s->writer.native_handle()));s->writer.join();}
    // Keep output draining while Windows tears down the pseudoconsole.
    if(s->console){ClosePseudoConsole(s->console);s->console=nullptr;}
    if(s->closer.joinable())s->closer.join();
    if(s->reader.joinable()){CancelSynchronousIo(static_cast<HANDLE>(s->reader.native_handle()));s->reader.join();}
    for(HANDLE h:{s->input,s->output,s->process,s->job})if(h)CloseHandle(h);
    m_state.reset();
}
}
