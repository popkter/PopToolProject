#include <QtTest>
#include <QDir>
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>
#include <algorithm>
#include "application/plugins.h"
#include "application/pythonenvironment.h"
#include "infrastructure/processrunner.h"
#include "presentation/sessions.h"
#include "presentation/scripts.h"
#include "infrastructure/storage.h"
#include "application/updates.h"
#include "application/executions.h"
#include "presentation/settings.h"
class PluginIntegrationTests:public QObject {
    Q_OBJECT
    std::unique_ptr<ut::Plugins> plugins;
    std::unique_ptr<ut::PythonEnvironment> python;
    QString root,resources;
private slots:
    void initTestCase(){
        root=qEnvironmentVariable("UTERMINAL_INTEGRATION_DATA");resources=qEnvironmentVariable("UTERMINAL_RESOURCES");
        QVERIFY2(!root.isEmpty()&&!resources.isEmpty(),"Set explicit integration data and resource paths.");QDir().mkpath(root);
        plugins=std::make_unique<ut::Plugins>(root,resources);python=std::make_unique<ut::PythonEnvironment>(root,plugins.get());
    }
    void explorerWorkingDirectory(){
        QVERIFY(plugins->powerShellReady());QTemporaryDir temporary;const auto directory=temporary.path()+"/中文 path";
        QVERIFY(QDir().mkpath(directory));QFile file(directory+"/script.py");QVERIFY(file.open(QIODevice::WriteOnly));file.close();
        ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());
        for(const auto &requested:QStringList{directory,file.fileName(),temporary.path()+"/missing",QString()}){
            ut::Sessions sessions(plugins.get(),&settings,&scripts);sessions.openDirectory(requested);QCOMPARE(sessions.rowCount(),1);
            auto *pane=sessions.focusedPane();QVERIFY(pane);QByteArray output;
            connect(&pane->process,&ut::ConPty::output,this,[&](const QByteArray &bytes){output+=bytes;});
            QTRY_VERIFY_WITH_TIMEOUT(output.contains("PS "),20000);output.clear();
            pane->process.write("[Console]::WriteLine('UT_CWD_'+[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Location).Path)))\r");
            const auto expected=QDir::toNativeSeparators(ut::Sessions::resolveDirectory(requested)).toUtf8().toBase64();
            QTRY_VERIFY_WITH_TIMEOUT(output.contains("UT_CWD_"+expected),10000);sessions.closeAll();
        }
    }
    void closeSplitPreservesOtherPane(){
        QVERIFY(plugins->powerShellReady());QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Sessions sessions(plugins.get(),&settings,&scripts);
        sessions.newTab();auto *first=sessions.focusedPane();QVERIFY(first);sessions.split(false);auto *second=sessions.focusedPane();QVERIFY(second&&second!=first);
        QCOMPARE(sessions.panes().size(),2);sessions.closePane(second);QCOMPARE(sessions.panes().size(),1);QCOMPARE(sessions.focusedPane(),first);QVERIFY(first->running());
        QByteArray output;connect(&first->process,&ut::ConPty::output,this,[&](const QByteArray &bytes){output+=bytes;});
        QTRY_VERIFY_WITH_TIMEOUT(output.contains("PS "),20000);output.clear();first->process.write("[Console]::WriteLine(('surviving'+'-pane'))\r");
        QTRY_VERIFY_WITH_TIMEOUT(output.contains("surviving-pane"),10000);sessions.closeAll();
    }
    void pythonScriptArguments(){
        QVERIFY(plugins->pythonReady());QTemporaryDir temporary;ut::Scripts scripts(temporary.path());ut::Settings settings(temporary.path());
        scripts.newDraft("import sys,json\nprint(json.dumps(sys.argv[1:],ensure_ascii=False))","python");scripts.updateDraft("title","argv");
        const QJsonArray values{QStringLiteral("中文 空格"),QStringLiteral("quote\"slash\\"),QString(),QStringLiteral("${名字:默认值}"),QStringLiteral("?名字:--enabled value"),QStringLiteral("?missing:${unused}")};
        scripts.updateDraft("legacyConditionalArguments",true);
        QVERIFY(scripts.setDraftArguments(QString::fromUtf8(QJsonDocument(values).toJson())));QVERIFY(scripts.saveDraft());
        ut::Sessions sessions(plugins.get(),&settings,&scripts);ut::Executions runs(temporary.path(),plugins.get(),&settings,&scripts,&sessions);QSignalSpy errors(&runs,&ut::Executions::error);
        runs.runSelected({{QStringLiteral("名字"),QStringLiteral("输入 值")}});QTRY_VERIFY_WITH_TIMEOUT(!runs.selectedRunning(),10000);QVERIFY(errors.isEmpty());
        const auto received=QJsonDocument::fromJson(runs.output().trimmed().toUtf8());QVERIFY2(received.isArray(),qPrintable(runs.output()));
        QCOMPARE(received.array(),(QJsonArray{values[0],values[1],values[2],QStringLiteral("输入 值"),QStringLiteral("--enabled value")}));
    }
    void secretParameterOutput(){
        QVERIFY(plugins->pythonReady());QTemporaryDir temporary;ut::Scripts scripts(temporary.path());ut::Settings settings(temporary.path());
        const QJsonObject old{{"id","secret"},{"title","secret"},{"parameters",QJsonArray{QJsonObject{{"id","token"},{"label","Token"},{"kind","secret"},{"required",true}}}},
            {"executor",QJsonObject{{"kind","python"},{"command","import sys,time\ns=sys.argv[1]\nprint('begin:',end='',flush=True)\nprint(s[:6],end='',flush=True)\ntime.sleep(0.2)\nprint(s[6:],flush=True)"},{"args",QJsonArray{"${token}"}}}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()))["status"].toString(),QString("ok"));
        const auto secret=QString("UT_SECRET_SENTINEL_42");scripts.setParameterValue("token",secret);
        ut::Sessions sessions(plugins.get(),&settings,&scripts);ut::Executions runs(temporary.path(),plugins.get(),&settings,&scripts,&sessions);QSignalSpy errors(&runs,&ut::Executions::error);
        QStringList snapshots;connect(&runs,&ut::Executions::changed,this,[&]{snapshots.append(runs.output());});
        runs.runSelected(scripts.parameterValues());QTRY_VERIFY_WITH_TIMEOUT(!runs.selectedRunning(),10000);QVERIFY(errors.isEmpty());QCOMPARE(runs.output().trimmed(),QString("begin:***"));
        for(const auto &snapshot:snapshots){QVERIFY(!snapshot.contains(secret));QVERIFY(!snapshot.contains("UT_SEC"));}
        QCOMPARE(QDir(temporary.path()+"/runs").entryList(QDir::Dirs|QDir::NoDotAndDotDot).size(),0);
        ut::Scripts restored(temporary.path());restored.select("secret");QCOMPARE(restored.parameterValues()["token"].toString(),QString());QVERIFY(!restored.exportSelected().contains(secret));
    }
    void migratedParameterExecution(){
        QVERIFY(plugins->pythonReady());QTemporaryDir temporary;ut::Scripts scripts(temporary.path());ut::Settings settings(temporary.path());
        const QJsonArray metadata{
            QJsonObject{{"id","enabled"},{"label","Enabled"},{"kind","boolean"},{"required",true}},
            QJsonObject{{"id","text"},{"label","Text"},{"kind","multiline"},{"required",false}},
            QJsonObject{{"id","count"},{"label","Count"},{"kind","integer"},{"required",true}}};
        const QJsonObject old{{"id","migrated-parameters"},{"title","migrated parameters"},{"parameters",metadata},
            {"executor",QJsonObject{{"kind","python"},{"command","import sys,json\nprint(json.dumps([${enabled:on},sys.argv[1:]],ensure_ascii=False))"},
            {"args",QJsonArray{"${text}","${count}","?enabled:--enabled","?missing:${unused}"}}}}};
        QCOMPARE(scripts.importText(QString::fromUtf8(QJsonDocument(old).toJson()))["status"].toString(),QString("ok"));
        ut::Sessions sessions(plugins.get(),&settings,&scripts);ut::Executions runs(temporary.path(),plugins.get(),&settings,&scripts,&sessions);QSignalSpy errors(&runs,&ut::Executions::error);
        const auto text=QStringLiteral("第一行\r\n\n  quote\" slash\\\n");const auto count=QString("000123456789012345678901234567890");
        for(int scenario=0;scenario<3;++scenario){
            QVariantMap inputs{{"text",text},{"count",count}};if(scenario<2)inputs["enabled"]=bool(scenario);
            runs.runSelected(inputs);QTRY_VERIFY_WITH_TIMEOUT(!runs.selectedRunning(),10000);QVERIFY2(errors.isEmpty(),errors.isEmpty()?"":qPrintable(errors.last().first().toString()));
            const auto received=QJsonDocument::fromJson(runs.output().trimmed().toUtf8());QVERIFY2(received.isArray(),qPrintable(runs.output()));
            QJsonArray arguments{text,count};if(scenario!=0)arguments.append("--enabled");
            QCOMPARE(received.array(),(QJsonArray{scenario!=0,arguments}));
        }
    }
    void crossProcessPythonLocks(){
        QVERIFY(plugins->pythonReady());const auto env=plugins->environment();
        QProcess reader;reader.setProcessEnvironment(env);reader.start(plugins->executable("python"),{"-u","-c","import time;print('reader-ready',flush=True);time.sleep(60)"});
        QVERIFY(reader.waitForStarted());QTRY_VERIFY_WITH_TIMEOUT(reader.bytesAvailable()>0,10000);QVERIFY(reader.readAllStandardOutput().contains("reader-ready"));
        QProcess second;second.setProcessEnvironment(env);second.start(plugins->executable("python"),{"-c","print('second-reader')"});QVERIFY(second.waitForFinished(10000));QCOMPARE(second.exitCode(),0);
        QProcess pip;pip.setProcessEnvironment(env);pip.start(plugins->environmentPath()+"/Scripts/python.exe",{"-m","pip","--isolated","install","--no-index","--no-deps","uterminal-lock-fixture-not-a-package"});
        QVERIFY(pip.waitForFinished(10000));QCOMPARE(pip.exitCode(),75);QVERIFY(QString::fromUtf8(pip.readAllStandardError()).contains(QStringLiteral("环境正在")));
        pip.start(plugins->environmentPath()+"/Scripts/pip.exe",{"install","--no-index","--no-deps","uterminal-lock-fixture-not-a-package"});
        QVERIFY(pip.waitForFinished(10000));QCOMPARE(pip.exitCode(),75);
        reader.kill();QVERIFY(reader.waitForFinished(10000));
        const auto versionDir=QFileInfo(plugins->environmentPath()).absolutePath();
        const auto lockPath=QFileInfo(versionDir).absolutePath()+"/.locks/"+QFileInfo(versionDir).fileName()+".lock";
        HANDLE handle=CreateFileW(reinterpret_cast<LPCWSTR>(lockPath.utf16()),GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
        QVERIFY(handle!=INVALID_HANDLE_VALUE);OVERLAPPED overlapped{};
        const bool locked=LockFileEx(handle,LOCKFILE_EXCLUSIVE_LOCK|LOCKFILE_FAIL_IMMEDIATELY,0,1,0,&overlapped);if(!locked)CloseHandle(handle);QVERIFY(locked);
        second.start(plugins->executable("python"),{"-c","print('must-not-run')"});const bool finished=second.waitForFinished(10000);CloseHandle(handle);QVERIFY(finished);QCOMPARE(second.exitCode(),75);
        second.start(plugins->executable("python"),{"-c","print('released')"});QVERIFY(second.waitForFinished(10000));QCOMPARE(second.exitCode(),0);
        pip.start(plugins->environmentPath()+"/Scripts/python.exe",{"-m","pip","--version"});QVERIFY(pip.waitForFinished(10000));QCOMPARE(pip.exitCode(),0);
    }
    void externalLockPreventsEnvironmentMutation(){
        QTemporaryDir temporary;QVERIFY(temporary.isValid());
        const auto version=QStringLiteral("3.12.10");
        const auto directory=temporary.path()+"/plugins/python/"+version+"-x64";
        QVERIFY(QDir().mkpath(directory));
        QVERIFY(ut::writeJson(directory+"/fixture.json",{{"preserve",true}}));
        const auto locks=temporary.path()+"/plugins/python/.locks";QVERIFY(QDir().mkpath(locks));
        const auto path=locks+"/"+version+"-x64.lock";
        HANDLE handle=CreateFileW(reinterpret_cast<LPCWSTR>(path.utf16()),GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
        QVERIFY(handle!=INVALID_HANDLE_VALUE);
        std::shared_ptr<void> guard(handle,[](void *value){CloseHandle(value);});OVERLAPPED overlapped{};
        QVERIFY(LockFileEx(handle,LOCKFILE_FAIL_IMMEDIATELY,0,1,0,&overlapped));
        ut::Plugins isolated(temporary.path(),resources);QSignalSpy errors(&isolated,&ut::Plugins::error);
        QVERIFY(!isolated.removeVersion("python",version));QVERIFY(QFile::exists(directory+"/fixture.json"));
        isolated.install("python",version);QVERIFY(!isolated.busy());QCOMPARE(errors.size(),2);
        QVERIFY(errors.last()[0].toString().contains(QStringLiteral("其他进程")));
        QVERIFY(!QFile::exists(temporary.path()+"/staging/python-"+version+".zip"));
        guard.reset();QVERIFY(isolated.removeVersion("python",version));QVERIFY(!QFile::exists(directory));
    }
    void installPython(){
        QSignalSpy error(plugins.get(),&ut::Plugins::error);
        if(!plugins->pythonReady())plugins->install("python","3.13.14");
        QTRY_VERIFY_WITH_TIMEOUT(!plugins->busy(),600000);
        QVERIFY2(plugins->pythonReady(),qPrintable(plugins->status()));QVERIFY2(error.isEmpty(),error.isEmpty()?"":qPrintable(error.last()[0].toString()));
        QVERIFY(plugins->commitActivation("python","3.13.14"));
        QVERIFY(!QFileInfo::exists(root+"/plugins/python/3.13.14-x64/installing.json"));
    }
    void repairInterruptedPythonInstall(){
        QVERIFY(plugins->pythonReady());const auto version=plugins->pythonVersion();
        const auto directory=root+"/plugins/python/"+version+"-x64";
        const auto module=directory+"/runtime/Lib/colorsys.py";
        auto digest=[](const QString &path){QFile file(path);if(!file.open(QIODevice::ReadOnly))return QByteArray();return QCryptographicHash::hash(file.readAll(),QCryptographicHash::Sha256);};
        const auto before=digest(module);QVERIFY(!before.isEmpty());
        QVERIFY(ut::writeJson(directory+"/installing.json",{{"kind","python"},{"version",version}}));
        QVERIFY(QFile::remove(module));QVERIFY(!plugins->pythonReady());
        plugins->install("python",version);QTRY_VERIFY_WITH_TIMEOUT(!plugins->busy(),600000);
        QVERIFY2(plugins->pythonReady(),qPrintable(plugins->status()));
        QCOMPARE(digest(module),before);QCOMPARE(plugins->pythonVersion(),version);
        QVERIFY(!QFileInfo::exists(directory+"/installing.json"));
    }
    void checkApplicationUpdates(){
        QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Updates updates(temporary.path(),&settings,plugins.get());
        updates.check();QTRY_VERIFY_WITH_TIMEOUT(!updates.busy(),45000);
        QVERIFY2(!updates.status().contains("失败")&&!updates.status().contains("无效"),qPrintable(updates.status()));
        QVERIFY(ut::readJson(temporary.path()+"/update-state.json")["lastSuccess"].toInteger()>0);
    }
    void verifiedDownloadSize(){
        QTemporaryDir temporary(root+"/download-check-XXXXXX");QVERIFY(temporary.isValid());
        auto catalog=ut::readJson(resources+"/plugin-catalog.json");QJsonObject package;
        for(const auto &entry:catalog["packages"].toArray())if(entry.toObject()["version"].toString()=="3.12.10")package=entry.toObject();
        QVERIFY(!package.isEmpty());package["size"]=1;
        QVERIFY(ut::writeJson(temporary.path()+"/bad-resources/plugin-catalog.json",{{"packages",QJsonArray{package}}}));
        {
            ut::Plugins invalid(temporary.path()+"/bad",temporary.path()+"/bad-resources");QSignalSpy errors(&invalid,&ut::Plugins::error);
            invalid.install("python","3.12.10");QTRY_VERIFY_WITH_TIMEOUT(!invalid.busy(),120000);
            QCOMPARE(errors.size(),1);QVERIFY2(invalid.status().contains("大小"),qPrintable(invalid.status()));QVERIFY(!invalid.pythonReady());
            QVERIFY(!QFileInfo::exists(temporary.path()+"/bad/staging/python-3.12.10.zip"));QVERIFY(invalid.pythonVersion().isEmpty());
        }
        ut::Plugins valid(temporary.path()+"/valid",resources);QSignalSpy errors(&valid,&ut::Plugins::error);
        valid.install("python","3.12.10");QTRY_VERIFY_WITH_TIMEOUT(!valid.busy(),600000);
        QVERIFY2(valid.pythonReady(),qPrintable(valid.status()));QVERIFY(errors.isEmpty());QCOMPARE(valid.pythonVersion(),QString("3.12.10"));
    }
    void cancelPythonPreparationAndRetry(){
        QTemporaryDir temporary(root+"/cancel-install-XXXXXX");QVERIFY(temporary.isValid());
        ut::Plugins isolated(temporary.path(),resources);QSignalSpy installed(&isolated,&ut::Plugins::installed);
        bool requested=false;
        const auto connection=connect(&isolated,&ut::Plugins::changed,this,[&]{
            if(!requested&&isolated.busy()&&isolated.progress()==90){requested=true;QTimer::singleShot(100,&isolated,&ut::Plugins::cancel);}
        });
        isolated.install("python","3.12.10");QTRY_VERIFY_WITH_TIMEOUT(!isolated.busy(),180000);
        QVERIFY(requested);QVERIFY2(isolated.status().contains(QStringLiteral("取消")),qPrintable(isolated.status()));
        QVERIFY(installed.isEmpty());QVERIFY(!isolated.pythonReady());QVERIFY(isolated.pythonVersion().isEmpty());
        const auto versionPath=temporary.path()+"/plugins/python/3.12.10-x64";
        QVERIFY(!QFile::exists(versionPath+"/installed.json"));QVERIFY(!QFile::exists(temporary.path()+"/staging/python-3.12.10.zip"));
        disconnect(connection);
        isolated.install("python","3.12.10");QTRY_VERIFY_WITH_TIMEOUT(!isolated.busy(),180000);
        QVERIFY2(isolated.pythonReady(),qPrintable(isolated.status()));QCOMPARE(installed.size(),1);QCOMPARE(isolated.pythonVersion(),QString("3.12.10"));
    }
    void baseInterpreterAndVenvAgree(){
        QVERIFY(plugins->pythonReady());python->refresh();QTRY_VERIFY_WITH_TIMEOUT(!python->busy(),30000);
        auto info=python->information();
        QCOMPARE(QDir::cleanPath(info["executable"].toString()).toLower(),QDir::cleanPath(plugins->executable("python")).toLower());
        QCOMPARE(QDir::cleanPath(info["prefix"].toString()).toLower(),QDir::cleanPath(plugins->environmentPath()).toLower());
        QVERIFY(!python->packages().isEmpty());
        const auto basePackages=QDir::cleanPath(QFileInfo(plugins->executable("python")).absolutePath()+"/Lib/site-packages").toLower();
        for(const auto &path:info["searchPath"].toList())QVERIFY(QDir::cleanPath(path.toString()).toLower()!=basePackages);
    }
    void diagnoseMissingAndSyntax(){
        QVERIFY(plugins->pythonReady());python->probe("import pathlib\nimport uterminal_missing_test_module_813\n");QTRY_VERIFY_WITH_TIMEOUT(!python->busy(),30000);
        QCOMPARE(python->diagnostics()["missing"].toList(),QVariantList{QString("uterminal_missing_test_module_813")});
        python->probe("def invalid(:\n");QTRY_VERIFY_WITH_TIMEOUT(!python->busy(),30000);QVERIFY(!python->diagnostics()["syntaxError"].toString().isEmpty());
    }
    void pipWaitsForLeaseAndUsesPrivateEnvironment(){
        QVERIFY(plugins->pythonReady());auto version=plugins->pythonVersion();plugins->acquire("python",version);
        python->installPackages("colorama==0.4.6");QVERIFY(python->queued());QVERIFY(plugins->pythonReserved());QTest::qWait(100);QVERIFY(python->queued());
        plugins->release("python",version);QTRY_VERIFY_WITH_TIMEOUT(!python->busy(),180000);QVERIFY2(python->status().contains(QStringLiteral("完成")),qPrintable(python->log()));QVERIFY(!plugins->pythonReserved());
        python->probe("import colorama\n");QTRY_VERIFY_WITH_TIMEOUT(!python->busy(),30000);QVERIFY(python->diagnostics()["missing"].toList().isEmpty());
    }
    void installPowerShell(){
        QSignalSpy error(plugins.get(),&ut::Plugins::error);
        if(!plugins->powerShellReady())plugins->install("powershell","7.6.3");
        QTRY_VERIFY_WITH_TIMEOUT(!plugins->busy(),600000);
        QVERIFY2(plugins->powerShellReady(),qPrintable(plugins->status()));QVERIFY2(error.isEmpty(),error.isEmpty()?"":qPrintable(error.last()[0].toString()));
        QVERIFY(!QFileInfo::exists(root+"/plugins/powershell/7.6.3-x64/installing.json"));
    }
    void realPowerShellUpgradeKeepsOldSession(){
        const auto data=root+"/powershell-upgrade";
        const QJsonObject older{{"kind","powershell"},{"version","7.6.2"},{"architecture","x64"},
            {"url","https://github.com/PowerShell/PowerShell/releases/download/v7.6.2/PowerShell-7.6.2-win-x64.zip"},
            {"sha256","32e0dd26752483ba3f0e40e9ae44150643cbff469c13210c93295d158bfd7b26"},{"size",116913144},{"prefix",""}};
        QVERIFY(ut::writeJson(data+"/plugins/catalog-cache.json",{{"packages",QJsonArray{older}}}));
        ut::Plugins manager(data,resources);
        QVERIFY2(!manager.installedVersion("powershell","7.6.3"),"Run this installation-path test with a fresh integration data directory.");
        manager.install("powershell","7.6.2");QTRY_VERIFY_WITH_TIMEOUT(!manager.busy(),600000);
        QVERIFY2(manager.powerShellReady(),qPrintable(manager.status()));QCOMPARE(manager.powerShellVersion(),QString("7.6.2"));
        ut::Settings settings(data);ut::Scripts scripts(data);ut::Sessions sessions(&manager,&settings,&scripts);
        sessions.newTab();auto *old=sessions.focusedPane();QVERIFY(old);QByteArray oldOutput,newOutput;
        connect(&old->process,&ut::ConPty::output,this,[&](const QByteArray &bytes){oldOutput+=bytes;});
        QTRY_VERIFY_WITH_TIMEOUT(oldOutput.contains("PS "),20000);
        manager.install("powershell","7.6.3");QTRY_VERIFY_WITH_TIMEOUT(!manager.busy(),600000);
        QVERIFY2(manager.installedVersion("powershell","7.6.3"),qPrintable(manager.status()));
        QCOMPARE(manager.powerShellVersion(),QString("7.6.2"));QVERIFY(old->running());
        manager.install("powershell","7.6.3");QCOMPARE(manager.powerShellVersion(),QString("7.6.3"));
        sessions.newTab();auto *current=sessions.focusedPane();QVERIFY(current&&current!=old);
        connect(&current->process,&ut::ConPty::output,this,[&](const QByteArray &bytes){newOutput+=bytes;});
        QTRY_VERIFY_WITH_TIMEOUT(newOutput.contains("PS "),20000);
        oldOutput.clear();newOutput.clear();
        const QByteArray query="[Console]::WriteLine(('UT_VERSION_' + $PSVersionTable.PSVersion.ToString()))\r";
        old->process.write(query);current->process.write(query);
        QTRY_VERIFY_WITH_TIMEOUT(oldOutput.contains("UT_VERSION_7.6.2"),10000);
        QTRY_VERIFY_WITH_TIMEOUT(newOutput.contains("UT_VERSION_7.6.3"),10000);
        QCOMPARE(old->powerShellVersion,QString("7.6.2"));QCOMPARE(current->powerShellVersion,QString("7.6.3"));
        QVERIFY(!manager.removeVersion("powershell","7.6.2"));
        QVERIFY(manager.activate("powershell","7.6.2"));QVERIFY(current->running());
        QCOMPARE(current->powerShellVersion,QString("7.6.3"));
        sessions.closeAll();QVERIFY(!manager.inUse("powershell","7.6.2"));QVERIFY(!manager.inUse("powershell","7.6.3"));
    }
    void queuedInstallCanBeCancelled(){
        auto version=plugins->pythonVersion();plugins->acquire("python",version);python->installPackages("colorama==0.4.6");QVERIFY(python->queued());
        python->cancel();QVERIFY(!python->busy());QVERIFY(!plugins->pythonReserved(version));plugins->release("python",version);
    }
    void realPowerShellInteractivePrompt(){
        QVERIFY(plugins->powerShellReady());ut::Pane pane;pane.terminal()->setSize({900,600});QByteArray bytes;
        connect(&pane.process,&ut::ConPty::output,this,[&](const QByteArray &data){bytes+=data;});
        auto profile=plugins->resourcePath("terminal-profile.ps1");profile.replace("'","''");
        QVERIFY(pane.process.start(plugins->executable("powershell"),{"-NoLogo","-NoProfile","-NoExit","-Command",". '"+profile+"'"},root,plugins->environment()));
        QTRY_VERIFY_WITH_TIMEOUT(bytes.contains("PS "),20000);
        pane.process.write("Write-Output ('uterminal-'+'interactive-ok')\r");
        QTRY_VERIFY_WITH_TIMEOUT(bytes.contains("uterminal-interactive-ok"),10000);
        pane.process.close();
    }
    void historyPredictionIsSilentAndDeferred(){
        QVERIFY(plugins->powerShellReady());QTemporaryDir temporary;ut::Settings settings(temporary.path());ut::Scripts scripts(temporary.path());ut::Sessions sessions(plugins.get(),&settings,&scripts);
        QSignalSpy errors(&sessions,&ut::Sessions::error);sessions.newTab();auto *pane=sessions.focusedPane();QVERIFY(pane);QSignalSpy controls(pane->terminal(),&TerminalItem::shellControlReceived);
        const auto messages=[&]{QStringList result;for(const auto &row:controls)result.append(row[1].toString());return result.join(',');};
        QTRY_VERIFY_WITH_TIMEOUT(std::any_of(controls.begin(),controls.end(),[](const auto &row){return row[1].toString()=="prompt:ready";}),20000);
        QTRY_VERIFY2_WITH_TIMEOUT(std::any_of(controls.begin(),controls.end(),[](const auto &row){return row[1].toString()=="history:off";}),qPrintable(messages()),10000);
        sessions.split(false);auto *second=sessions.focusedPane();QVERIFY(second&&second!=pane);QSignalSpy secondControls(second->terminal(),&TerminalItem::shellControlReceived);
        QTRY_VERIFY_WITH_TIMEOUT(std::any_of(secondControls.begin(),secondControls.end(),[](const auto &row){return row[1].toString()=="history:off";}),20000);
        pane->process.write("Write-Outp");settings.setHistoryPrediction(true);
        QTRY_VERIFY2_WITH_TIMEOUT(std::any_of(controls.begin(),controls.end(),[](const auto &row){return row[1].toString()=="history:on";}),qPrintable(messages()),10000);
        QTRY_VERIFY_WITH_TIMEOUT(std::any_of(secondControls.begin(),secondControls.end(),[](const auto &row){return row[1].toString()=="history:on";}),10000);
        pane->terminal()->selectAll();auto visible=pane->terminal()->selectionText();pane->terminal()->clearSelection();
        QVERIFY(!visible.contains("Set-PSReadLineOption"));QVERIFY(!visible.contains("6973"));QVERIFY(!visible.contains("history:on"));
        QByteArray output;connect(&pane->process,&ut::ConPty::output,this,[&](const QByteArray &bytes){output+=bytes;});
        pane->process.write("ut 'buffer-preserved'\r");QTRY_VERIFY_WITH_TIMEOUT(output.contains("buffer-preserved"),10000);output.clear();
        const auto offCount=[&]{return std::count_if(controls.cbegin(),controls.cend(),[](const auto &row){return row[1].toString()=="history:off";});};
        const auto secondOffCount=[&]{return std::count_if(secondControls.cbegin(),secondControls.cend(),[](const auto &row){return row[1].toString()=="history:off";});};
        const int beforeOff=offCount(),beforeSecondOff=secondOffCount();
        pane->terminal()->pasteText("Start-Sleep -Milliseconds 600; Write-Output 'long-command-done'\r");settings.setHistoryPrediction(false);
        QTRY_VERIFY_WITH_TIMEOUT(secondOffCount()>beforeSecondOff,3000);QCOMPARE(offCount(),beforeOff);
        QTRY_VERIFY_WITH_TIMEOUT(output.contains("long-command-done"),10000);
        QTRY_VERIFY_WITH_TIMEOUT(offCount()>beforeOff,10000);
        QCOMPARE(errors.count(),0);sessions.closeAll();
    }
    void pythonImportedAttachments(){
        QVERIFY(plugins->pythonReady());QTemporaryDir temporary;const auto collection=temporary.path()+"/collection";
        QVERIFY(QDir().mkpath(collection+"/tools"));QVERIFY(QDir().mkpath(collection+"/scripts"));
        auto file=[](const QString &path,const QByteArray &bytes){QFile output(path);return output.open(QIODevice::WriteOnly)&&output.write(bytes)==bytes.size();};
        QVERIFY(QDir().mkpath(collection+"/scripts/cache/empty"));
        QVERIFY(file(collection+"/scripts/main.py","from pathlib import Path\nimport helper\nempty = Path(__file__).parent / 'cache' / 'empty'\nassert empty.is_dir() and not list(empty.iterdir())\nprint(helper.VALUE + Path(__file__).with_name('message.txt').read_text(encoding='utf-8'))\n"));
        QVERIFY(file(collection+"/scripts/helper.py","VALUE = 'bundled-module:'\n"));
        QVERIFY(file(collection+"/scripts/message.txt",QStringLiteral("中文🙂").toUtf8()));
        QVERIFY(ut::writeJson(collection+"/tools/main.json",{{"id","python-bundle"},{"title","Python bundle"},{"executor",QJsonObject{{"kind","python"},{"command","scripts/main.py"}}}}));
        ut::Scripts imported(temporary.path()+"/first");const auto report=imported.importCollection(collection);QVERIFY2(imported.count()==1,qPrintable(report));
        QVERIFY(imported.exportCollection(temporary.path()+"/export"));
        const auto data=temporary.path()+"/second";ut::Scripts scripts(data);const auto copied=scripts.importCollection(temporary.path()+"/export");QVERIFY2(scripts.count()==1,qPrintable(copied));
        QVERIFY(QFile::remove(collection+"/scripts/helper.py"));QVERIFY(QFile::remove(collection+"/scripts/message.txt"));
        QVERIFY(QDir().rmdir(collection+"/scripts/cache/empty"));
        ut::Settings settings(data);ut::Sessions sessions(plugins.get(),&settings,&scripts);ut::Executions runs(data,plugins.get(),&settings,&scripts,&sessions);
        runs.runSelected({});QTRY_VERIFY_WITH_TIMEOUT(!runs.selectedRunning(),15000);
        QVERIFY2(runs.outcome()=="succeeded",qPrintable(runs.status()+"\n"+runs.output()));
        QVERIFY(runs.output().contains(QStringLiteral("bundled-module:中文🙂")));
        QCOMPARE(QDir(data+"/runs").entryList(QDir::Dirs|QDir::NoDotAndDotDot).size(),0);
    }
    void pythonConsoleUnicodeInput(){
        QVERIFY(plugins->pythonReady());ut::Pane pane;QByteArray bytes;
        connect(&pane.process,&ut::ConPty::output,this,[&](const QByteArray &data){bytes+=data;});
        QVERIFY(pane.process.start(plugins->executable("python"),
            {"-u","-c","import sys; print('input-ready', flush=True); s=sys.stdin.readline().rstrip('\\r\\n'); print('codepoints=' + ','.join(hex(ord(c)) for c in s), flush=True)"},root,plugins->environment()));
        QTRY_VERIFY_WITH_TIMEOUT(bytes.contains("input-ready"),15000);bytes.clear();
        pane.process.write(QStringLiteral("中文🙂\r").toUtf8());
        QTRY_VERIFY2_WITH_TIMEOUT(bytes.contains("codepoints=0x4e2d,0x6587,0x1f642"),bytes.toHex(' ').constData(),10000);
        pane.process.close();
    }
    void powerShellCompletionAndPythonRepl_data(){
        QTest::addColumn<bool>("direct");
        QTest::newRow("powershell")<<false;
        QTest::newRow("direct")<<true;
    }
    void powerShellCompletionAndPythonRepl(){
        QFETCH(bool,direct);
        QVERIFY(plugins->powerShellReady());QVERIFY(plugins->pythonReady());
        ut::Pane pane;pane.terminal()->setSize({900,600});QByteArray bytes;
        connect(&pane.process,&ut::ConPty::output,this,[&](const QByteArray &data){bytes+=data;if(bytes.size()>1024*1024)bytes.remove(0,bytes.size()-1024*1024);});
        auto profile=plugins->resourcePath("terminal-profile.ps1");profile.replace("'","''");
        if(direct){
            QVERIFY(pane.process.start(plugins->executable("python"),{},root,plugins->environment()));
        }else{
        QVERIFY(pane.process.start(plugins->executable("powershell"),{"-NoLogo","-NoProfile","-NoExit","-Command",". '"+profile+"'"},root,plugins->environment()));
        QTRY_VERIFY_WITH_TIMEOUT(bytes.contains("PS "),20000);bytes.clear();
        pane.process.write("Write-Outp\t('psreadline-'+'completion')\r");
        QTRY_VERIFY_WITH_TIMEOUT(bytes.contains("psreadline-completion"),10000);bytes.clear();
        pane.process.write("python\r");
        }
        QTRY_VERIFY_WITH_TIMEOUT(bytes.contains(">>>"),15000);bytes.clear();
        pane.process.write(QStringLiteral("print('中文' + '🙂-repl')\r").toUtf8());
        QTRY_VERIFY2_WITH_TIMEOUT(bytes.contains(QStringLiteral("中文🙂-repl").toUtf8()),bytes.toHex(' ').constData(),10000);
        pane.terminal()->selectAll();QVERIFY(pane.terminal()->selectionText().contains(QStringLiteral("中文🙂-repl")));pane.terminal()->clearSelection();
        bytes.clear();pane.process.write("exit()\r");
        if(direct){QTRY_VERIFY_WITH_TIMEOUT(!pane.process.running(),10000);return;}
        QTRY_VERIFY_WITH_TIMEOUT(bytes.contains("PS "),10000);bytes.clear();
        pane.process.write("Write-Output ('returned-'+'to-shell')\r");QTRY_VERIFY_WITH_TIMEOUT(bytes.contains("returned-to-shell"),10000);
        pane.process.close();
    }
    void migrateAcrossMinorVersions(){
        QVERIFY(plugins->pythonReady());QSignalSpy confirmation(python.get(),&ut::PythonEnvironment::switchConfirmationRequested);
        plugins->install("python","3.12.10");QTRY_VERIFY_WITH_TIMEOUT(!plugins->busy(),600000);
        QVERIFY2(plugins->installedVersion("python","3.12.10"),qPrintable(plugins->status()));
        QTRY_COMPARE_WITH_TIMEOUT(confirmation.size(),1,30000);QCOMPARE(plugins->pythonVersion(),QString("3.13.14"));QVERIFY(python->requirements().contains("colorama"));
        python->confirmSwitch(true);QTRY_VERIFY_WITH_TIMEOUT(!python->busy(),180000);
        QCOMPARE(plugins->pythonVersion(),QString("3.12.10"));python->probe("import colorama\n");QTRY_VERIFY_WITH_TIMEOUT(!python->busy(),30000);
        QVERIFY(python->diagnostics()["missing"].toList().isEmpty());QCOMPARE(python->information()["version"].toString(),QString("3.12.10"));
    }
    void failedMigrationRetainsSource(){
        QVERIFY(plugins->commitActivation("python","3.13.14"));
        const auto metadata=plugins->environmentPath()+"/Lib/site-packages/uterminal_nonexistent_fixture_813-1.0.dist-info";QDir().mkpath(metadata);
        QFile fixture(metadata+"/METADATA");QVERIFY(fixture.open(QIODevice::WriteOnly));fixture.write("Metadata-Version: 2.1\nName: uterminal-nonexistent-fixture-813\nVersion: 1.0\n");fixture.close();
        QSignalSpy confirmation(python.get(),&ut::PythonEnvironment::switchConfirmationRequested);python->requestSwitch("3.12.10");QTRY_COMPARE_WITH_TIMEOUT(confirmation.size(),1,30000);
        python->confirmSwitch(true);QTRY_VERIFY_WITH_TIMEOUT(!python->busy(),180000);
        QCOMPARE(plugins->pythonVersion(),QString("3.13.14"));QVERIFY(!plugins->pythonReserved("3.12.10"));
        QVERIFY(python->log().contains("uterminal-nonexistent-fixture-813"));QDir(metadata).removeRecursively();
    }
    void cleanupTestCase(){python.reset();plugins.reset();}
};
QTEST_MAIN(PluginIntegrationTests)
#include "plugin_integration_tests.moc"
