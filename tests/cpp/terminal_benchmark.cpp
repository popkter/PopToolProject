#include <QGuiApplication>
#include <QElapsedTimer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QTextStream>
#include <algorithm>
#include <vector>
#include "presentation/terminalitem.h"

int main(int argc,char **argv){
    QGuiApplication app(argc,argv);
    const auto args=app.arguments();bool ok=false;
    const int lines=args.value(1,"100000").toInt(&ok);
    if(!ok||lines<20000||lines>1000000)return 2;
    TerminalItem terminal;terminal.setSize({900,600});terminal.setSessionId("history-benchmark");
    std::vector<double> batches;QElapsedTimer total;total.start();
    for(int first=0;first<lines;first+=100){
        QByteArray data;
        for(int i=first;i<std::min(first+100,lines);++i)data+=QStringLiteral("row-%1 中文🙂 \x1b[38;2;64;180;120moutput\x1b[0m\r\n").arg(i,7,10,QChar('0')).toUtf8();
        QElapsedTimer timer;timer.start();terminal.feedBytes(data);batches.push_back(timer.nsecsElapsed()/1000000.0);
        QCoreApplication::processEvents();
    }
    const double elapsed=total.nsecsElapsed()/1000000.0;
    terminal.selectAll();const auto retained=terminal.selectionText();
    const bool valid=terminal.scrollbackLineCount()==10000&&!retained.contains("row-0000000")&&retained.contains(QString("row-%1").arg(lines-1,7,10,QChar('0')))&&retained.contains(QStringLiteral("中文🙂"));
    std::sort(batches.begin(),batches.end());
    const QJsonObject result{{"scope","VT parsing and history retention; no rendered input latency measurement"},{"qt",QT_VERSION_STR},{"lines",lines},{"batchLines",100},{"elapsedMs",elapsed},{"feedBatchP95Ms",batches[size_t(batches.size()*0.95)]},{"feedBatchMaxMs",batches.back()},{"historyLines",terminal.scrollbackLineCount()},{"retentionValid",valid}};
    const auto json=QJsonDocument(result).toJson();
    if(args.size()>2){QFile output(args[2]);if(!output.open(QIODevice::WriteOnly)||output.write(json)!=json.size())return 3;}
    QTextStream(stdout)<<json;
    return valid?0:1;
}
