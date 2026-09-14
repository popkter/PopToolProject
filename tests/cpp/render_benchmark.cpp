#include <QGuiApplication>
#include <QQuickWindow>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QSaveFile>
#include <QDir>
#include <QFileInfo>
#include <QSysInfo>
#include <QTimer>
#include <QTextStream>
#include <QPainter>
#include <QImage>
#include <QKeyEvent>
#include <QScopeGuard>
#include <algorithm>
#include <atomic>
#include <array>
#include <memory>
#include <mutex>
#include <vector>
#include <cstring>
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <psapi.h>
#include "presentation/terminalitem.h"
#include "infrastructure/conpty.h"

// An opt-in, visible rendering workload. Never installed with the application.
// Each child owns a real pseudoconsole; no Python or PowerShell is required.
class MeasuredTerminal : public TerminalItem {
public:
    using TerminalItem::TerminalItem;
    std::atomic<quint64> paints{0};
    std::atomic<qint64> maximumPaintNs{0};
    std::atomic<quint64> probeRequested{0},probePainted{0};
    std::atomic<QRgb> probeColor{0};
    std::atomic<qint64> probeFrameNs{0};
    std::mutex probeMutex;
    void paint(QPainter *painter) override {
        QElapsedTimer timer;timer.start();TerminalItem::paint(painter);
        const std::lock_guard probeLock(probeMutex);
        const auto probe=probeRequested.load();
        if(probe&&probePainted.load()!=probe&&painter->device()->devType()==QInternal::Image){
            const auto *pixels=static_cast<const QImage*>(painter->device());
            const int x=qBound(0,qRound(painter->deviceTransform().map(QPointF(2,0)).x()),pixels->width()-1);
            const auto expected=probeColor.load();
            // The child paints a unique solid background in its reserved status row.
            // Check actual painted pixels, not merely receipt of a VT byte sequence.
            for(int y=0;y<pixels->height();++y)if(pixels->pixelColor(x,y).rgb()==expected){probePainted=probe;break;}
        }
        const auto elapsed=timer.nsecsElapsed();++paints;
        auto old=maximumPaintNs.load();while(elapsed>old&&!maximumPaintNs.compare_exchange_weak(old,elapsed)){}
    }
};

int main(int argc,char **argv){
    if(argc>1&&std::strcmp(argv[1],"--producer")==0){
        const HANDLE output=GetStdHandle(STD_OUTPUT_HANDLE);DWORD mode=0;
        const bool inputMode=argc>2&&std::strcmp(argv[2],"--input-probes")==0;
        const HANDLE input=GetStdHandle(STD_INPUT_HANDLE);int statusRow=0;
        SetConsoleOutputCP(CP_UTF8);
        if(GetConsoleMode(output,&mode))SetConsoleMode(output,mode|ENABLE_VIRTUAL_TERMINAL_PROCESSING);
        if(inputMode){
            SetConsoleMode(input,ENABLE_EXTENDED_FLAGS|ENABLE_PROCESSED_INPUT);
            CONSOLE_SCREEN_BUFFER_INFO info{};if(!GetConsoleScreenBufferInfo(output,&info))return 2;
            statusRow=info.srWindow.Bottom-info.srWindow.Top+1;
            const auto setup=QString("\x1b[1;%1r\x1b[1;1H").arg(statusRow-1).toUtf8();DWORD written=0;
            if(!WriteFile(output,setup.constData(),DWORD(setup.size()),&written,nullptr))return 2;
        }
        for(quint64 batch=0;;++batch){
            QByteArray bytes;
            if(inputMode){
                CONSOLE_SCREEN_BUFFER_INFO info{};if(!GetConsoleScreenBufferInfo(output,&info))return 2;
                const int currentRows=info.srWindow.Bottom-info.srWindow.Top+1;
                if(currentRows!=statusRow){statusRow=currentRows;bytes+=QString("\x1b[1;%1r\x1b[1;1H").arg(statusRow-1).toUtf8();}
                DWORD count=0;if(!GetNumberOfConsoleInputEvents(input,&count))return 2;
                if(count){INPUT_RECORD records[64];DWORD read=0;if(!ReadConsoleInputW(input,records,std::min(count,DWORD(64)),&read))return 2;
                    for(DWORD i=0;i<read;++i)if(records[i].EventType==KEY_EVENT&&records[i].Event.KeyEvent.bKeyDown){
                        const auto character=records[i].Event.KeyEvent.uChar.UnicodeChar;
                        if(character=='a'||character=='b')bytes+=QString("\x1b" "7\x1b[%1;1H\x1b[48;2;%2m        \x1b[0m\x1b" "8").arg(statusRow).arg(character=='a'?"192;47;224":"34;197;223").toUtf8();
                    }
                }
            }
            for(int line=0;line<10;++line)bytes+=QStringLiteral("row-%1 中文🙂 \x1b[38;2;64;180;120mcontinuous output\x1b[0m\r\n").arg(batch*10+line).toUtf8();
            DWORD written=0;if(!WriteFile(output,bytes.constData(),DWORD(bytes.size()),&written,nullptr)||written!=DWORD(bytes.size()))return 1;
            Sleep(10);
        }
    }
    QGuiApplication app(argc,argv);const auto args=app.arguments();bool valid=false;
    const int seconds=args.value(1,"600").toInt(&valid);
    if(!valid||seconds<10||seconds>3600||args.size()<3)return 2;
    const QString resultPath=QFileInfo(args[2]).absoluteFilePath();
    const bool inputMode=args.contains("--input-probes");
    std::atomic<quint64> frames{0};
    QQuickWindow window;window.setTitle("UTerminal — four-pane rendering benchmark");window.resize(1200,800);
    if(args.contains("--keep-visible"))window.setFlag(Qt::WindowStaysOnTopHint);
    std::array<MeasuredTerminal*,4> terminals{};
    std::array<std::unique_ptr<ut::ConPty>,4> processes;
    std::array<quint64,4> received{},generatedInputs{};
    QStringList errors;bool stopping=false;QElapsedTimer elapsed;elapsed.start();
    QJsonArray memorySamples;std::vector<double> heartbeatDelays,steadyHeartbeatDelays;
    const auto swapConnection=QObject::connect(&window,&QQuickWindow::frameSwapped,&window,[&]{
        ++frames;if(inputMode)for(auto *terminal:terminals)if(terminal){
            const std::lock_guard probeLock(terminal->probeMutex);
            const auto requested=terminal->probeRequested.load();qint64 empty=0;
            if(requested&&terminal->probePainted.load()==requested)terminal->probeFrameNs.compare_exchange_strong(empty,elapsed.nsecsElapsed());
        }
    },Qt::DirectConnection);
    const auto disconnectSwap=qScopeGuard([&]{QObject::disconnect(swapConnection);});
    auto layout=[&]{for(int i=0;i<4;++i){terminals[i]->setPosition({(i%2)*window.width()/2.0,(i/2)*window.height()/2.0});terminals[i]->setSize({window.width()/2.0,window.height()/2.0});}};
    for(int i=0;i<4;++i){
        terminals[i]=new MeasuredTerminal(window.contentItem());terminals[i]->setSessionId(QString("stress-%1").arg(i));
        processes[i]=std::make_unique<ut::ConPty>();
        QObject::connect(processes[i].get(),&ut::ConPty::output,&app,[&,i](const QByteArray &bytes){received[i]+=bytes.size();terminals[i]->feedBytes(bytes);});
        QObject::connect(processes[i].get(),&ut::ConPty::error,&app,[&,i](const QString &error){errors.append(QString("pane %1: %2").arg(i).arg(error));});
        QObject::connect(processes[i].get(),&ut::ConPty::finished,&app,[&,i](int code){if(!stopping)errors.append(QString("pane %1 exited early: %2").arg(i).arg(code));});
        QObject::connect(terminals[i],&TerminalItem::terminalSizeChanged,&app,[&,i](int cols,int rows){processes[i]->resize(cols,rows);});
        QObject::connect(terminals[i],&TerminalItem::inputGenerated,&app,[&,i](const QString &,const QString &text){++generatedInputs[i];if(!args.contains("--drop-probe-input")||(text!="a"&&text!="b"))processes[i]->write(text.toUtf8());});
    }
    layout();QObject::connect(&window,&QQuickWindow::widthChanged,&app,layout);QObject::connect(&window,&QQuickWindow::heightChanged,&app,layout);
    window.show();
    if(args.contains("--simulate-hidden-window")){
        QTimer::singleShot(7000,&window,&QWindow::hide);
        QTimer::singleShot(14000,&window,&QWindow::show);
    }
    QStringList childArguments{"--producer"};if(inputMode)childArguments.append("--input-probes");
    for(int i=0;i<4;++i)if(!processes[i]->start(app.applicationFilePath(),childArguments,QDir::currentPath(),QProcessEnvironment::systemEnvironment(),terminals[i]->columns(),terminals[i]->rows()))return 3;
    std::array<qint64,4> probeStarts{};std::array<int,4> paneProbes{};QJsonArray inputSamples;
    int nextProbePane=0,probeTimeouts=0;quint64 probeSequence=0;
    auto collectProbes=[&]{for(int i=0;i<4;++i)if(probeStarts[i]){
        const auto frame=terminals[i]->probeFrameNs.load();
        if(frame){inputSamples.append(QJsonObject{{"pane",i},{"startNs",double(probeStarts[i])},{"frameNs",double(frame)},{"latencyMs",(frame-probeStarts[i])/1000000.0}});probeStarts[i]=0;}
        else if(elapsed.nsecsElapsed()-probeStarts[i]>2000000000ll){++probeTimeouts;probeStarts[i]=0;}
    }};
    QTimer probes;probes.setInterval(500);
    QObject::connect(&probes,&QTimer::timeout,&app,[&]{
        collectProbes();if(!inputMode||elapsed.elapsed()<5000||elapsed.elapsed()>=seconds*1000-2500)return;
        const int pane=nextProbePane++%4;if(probeStarts[pane])return;
        auto *terminal=terminals[pane];const bool alternate=(paneProbes[pane]++%2)!=0;
        terminal->forceActiveFocus();{
            const std::lock_guard probeLock(terminal->probeMutex);
            terminal->probeRequested=0;terminal->probeFrameNs=0;
            terminal->probeColor=alternate?qRgb(34,197,223):qRgb(192,47,224);
            probeStarts[pane]=elapsed.nsecsElapsed();terminal->probeRequested=++probeSequence;
        }
        QKeyEvent event(QEvent::KeyPress,alternate?Qt::Key_B:Qt::Key_A,Qt::NoModifier,alternate?"b":"a");
        QCoreApplication::sendEvent(&window,&event);
    });if(inputMode)probes.start();
    QTimer heartbeat;heartbeat.setTimerType(Qt::PreciseTimer);heartbeat.setInterval(10);qint64 previous=elapsed.nsecsElapsed();
    QObject::connect(&heartbeat,&QTimer::timeout,&app,[&]{const auto now=elapsed.nsecsElapsed();const auto delay=std::max(0.0,(now-previous)/1000000.0-10.0);heartbeatDelays.push_back(delay);if(now>=5000000000ll)steadyHeartbeatDelays.push_back(delay);previous=now;});heartbeat.start();
    quint64 previousFrames=0;std::array<quint64,4> previousPaints{},previousReceived{};
    qint64 previousSampleMs=0;int stalledRenderIntervals=0;
    auto record=[&](bool final){
        const auto sampleMs=elapsed.elapsed();const auto frameCount=frames.load();
        bool renderStalled=!window.isVisible()||!window.isExposed();QJsonArray intervalPaints;
        for(int i=0;i<4;++i){const auto count=terminals[i]->paints.load();intervalPaints.append(double(count-previousPaints[i]));
            if(sampleMs-previousSampleMs>=500&&received[i]>previousReceived[i]&&count==previousPaints[i])renderStalled=true;
            previousPaints[i]=count;previousReceived[i]=received[i];}
        if(sampleMs-previousSampleMs>=500&&frameCount==previousFrames)renderStalled=true;
        if(renderStalled)++stalledRenderIntervals;
        PROCESS_MEMORY_COUNTERS_EX memory{};memory.cb=sizeof(memory);
        const bool memoryValid=GetProcessMemoryInfo(GetCurrentProcess(),reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory),sizeof(memory));
        QJsonArray histories;for(auto *terminal:terminals)histories.append(terminal->scrollbackLineCount());
        memorySamples.append(QJsonObject{{"elapsedMs",double(sampleMs)},{"valid",memoryValid},{"privateBytes",double(memory.PrivateUsage)},{"workingSetBytes",double(memory.WorkingSetSize)},{"historyLines",histories},{"visible",window.isVisible()},{"exposed",window.isExposed()},{"intervalFrames",double(frameCount-previousFrames)},{"intervalPaints",intervalPaints},{"renderStalled",renderStalled}});
        previousFrames=frameCount;previousSampleMs=sampleMs;
        auto delays=heartbeatDelays;std::sort(delays.begin(),delays.end());
        auto steady=steadyHeartbeatDelays;std::sort(steady.begin(),steady.end());
        collectProbes();int pendingProbes=0;for(auto start:probeStarts)if(start)++pendingProbes;
        QJsonArray panes;bool complete=errors.isEmpty()&&stalledRenderIntervals==0&&(!inputMode||(inputSamples.size()>0&&probeTimeouts==0&&pendingProbes==0));
        for(int i=0;i<4;++i){const auto painted=terminals[i]->paints.load();complete=complete&&painted>0&&received[i]>0&&terminals[i]->scrollbackLineCount()==10000;
            panes.append(QJsonObject{{"receivedBytes",double(received[i])},{"paints",double(painted)},{"maximumPaintMs",terminals[i]->maximumPaintNs.load()/1000000.0},{"historyLines",terminals[i]->scrollbackLineCount()}});}
        const QJsonObject result{{"scope","Four visible TerminalItem controls, real ConPTY output; memory covers host process only; excludes application navigation, input-to-display latency and Windows Terminal comparison"},{"status",final?"finished":"running"},{"workloadComplete",final&&complete},{"requestedSeconds",seconds},{"elapsedMs",double(elapsed.elapsed())},{"qt",QT_VERSION_STR},{"os",QSysInfo::prettyProductName()},{"architecture",QSysInfo::currentCpuArchitecture()},{"width",window.width()},{"height",window.height()},{"devicePixelRatio",window.devicePixelRatio()},{"frames",double(frames.load())},{"heartbeatSamples",int(delays.size())},{"heartbeatDelayP95Ms",delays.empty()?0:delays[size_t(delays.size()*0.95)]},{"heartbeatDelayMaxMs",delays.empty()?0:delays.back()},{"warmupMs",5000},{"steadyHeartbeatDelayP95Ms",steady.empty()?0:steady[size_t(steady.size()*0.95)]},{"steadyHeartbeatDelayMaxMs",steady.empty()?0:steady.back()},{"panes",panes},{"memorySamples",memorySamples},{"errors",QJsonArray::fromStringList(errors)}};
        auto report=result;report["stalledRenderIntervals"]=stalledRenderIntervals;
        if(inputMode){
            std::vector<double> latencies;for(const auto &value:inputSamples)latencies.push_back(value.toObject()["latencyMs"].toDouble());std::sort(latencies.begin(),latencies.end());
            report["scope"]="Qt key event to ConPTY child status-pixel echo, TerminalItem painted image and frameSwapped; four output panes. Excludes physical keyboard/monitor, full application UI and Windows Terminal comparison.";
            report["inputSamples"]=inputSamples;report["inputTimeouts"]=probeTimeouts;report["inputPending"]=pendingProbes;
            QJsonArray generated;for(auto count:generatedInputs)generated.append(double(count));report["inputGeneratedEvents"]=generated;
            report["inputToFrameP95Ms"]=latencies.empty()?QJsonValue():QJsonValue(latencies[size_t(latencies.size()*0.95)]);
            report["inputToFrameMaxMs"]=latencies.empty()?QJsonValue():QJsonValue(latencies.back());
        }
        const auto bytes=QJsonDocument(report).toJson();QSaveFile output(resultPath);
        if(!output.open(QIODevice::WriteOnly)||output.write(bytes)!=bytes.size()||!output.commit()){QTextStream(stderr)<<"Cannot write benchmark result\n";return false;}
        return complete;
    };
    QTimer sample;sample.setInterval(5000);QObject::connect(&sample,&QTimer::timeout,&app,[&]{record(false);});sample.start();
    QTimer::singleShot(seconds*1000,&app,[&]{
        stopping=true;heartbeat.stop();sample.stop();const bool complete=record(true);
        window.grabWindow().save(resultPath+".png");for(auto &process:processes)process->close();app.exit(complete?0:1);
    });
    const int code=app.exec();stopping=true;for(auto &process:processes)process->close();
    // Destroy the rendering surface while signal captures and counters are alive.
    window.hide();window.releaseResources();
    return code;
}
