#include <Windows.h>
#include <ShlObj.h>
#include <Shlwapi.h>
#include <ShObjIdl.h>
#include <wrl/client.h>
#include <atomic>
#include <filesystem>
#include <string>
using Microsoft::WRL::ComPtr;
namespace {
const CLSID commandId={0xb50ea7d3,0x701b,0x4f46,{0xa8,0x0d,0x2b,0x75,0xf7,0xd2,0xa6,0x41}};
HMODULE moduleHandle=nullptr;
std::atomic<long> objects=0,locks=0;
std::wstring moduleDirectory(){wchar_t buffer[32768];const auto count=GetModuleFileNameW(moduleHandle,buffer,32768);return count?std::filesystem::path(std::wstring(buffer,count)).parent_path().wstring():std::wstring();}
std::wstring quote(const std::wstring &value){
    std::wstring result=L"\"";size_t slashes=0;
    for(auto ch:value){if(ch==L'\\'){++slashes;continue;}result.append(ch==L'"'?slashes*2+1:slashes,L'\\');result+=ch;slashes=0;}
    result.append(slashes*2,L'\\');return result+L'"';
}
class Command final:public IExplorerCommand,public IObjectWithSite {
    std::atomic<ULONG> refs{1};ComPtr<IUnknown> site;
public:
    Command(){++objects;}~Command(){--objects;}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid,void **out)override{
        if(!out)return E_POINTER;*out=nullptr;
        if(iid==IID_IUnknown||iid==IID_IExplorerCommand)*out=static_cast<IExplorerCommand*>(this);
        else if(iid==IID_IObjectWithSite)*out=static_cast<IObjectWithSite*>(this);
        else return E_NOINTERFACE;AddRef();return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef()override{return ++refs;}
    ULONG STDMETHODCALLTYPE Release()override{auto count=--refs;if(!count)delete this;return count;}
    HRESULT STDMETHODCALLTYPE SetSite(IUnknown *value)override{site=value;return S_OK;}
    HRESULT STDMETHODCALLTYPE GetSite(REFIID iid,void **out)override{if(!out)return E_POINTER;*out=nullptr;return site?site->QueryInterface(iid,out):E_FAIL;}
    HRESULT STDMETHODCALLTYPE GetTitle(IShellItemArray*,PWSTR *out)override{return SHStrDupW(L"在 UTerminal 中打开",out);}
    HRESULT STDMETHODCALLTYPE GetIcon(IShellItemArray*,PWSTR *out)override{try{return SHStrDupW((moduleDirectory()+L"\\resources\\icons\\app-icon.ico").c_str(),out);}catch(...){return E_FAIL;}}
    HRESULT STDMETHODCALLTYPE GetToolTip(IShellItemArray*,PWSTR *out)override{if(!out)return E_POINTER;*out=nullptr;return E_NOTIMPL;}
    HRESULT STDMETHODCALLTYPE GetCanonicalName(GUID *out)override{if(!out)return E_POINTER;*out=commandId;return S_OK;}
    HRESULT STDMETHODCALLTYPE GetState(IShellItemArray*,BOOL,EXPCMDSTATE *out)override{if(!out)return E_POINTER;*out=ECS_ENABLED;return S_OK;}
    HRESULT STDMETHODCALLTYPE GetFlags(EXPCMDFLAGS *out)override{if(!out)return E_POINTER;*out=ECF_DEFAULT;return S_OK;}
    HRESULT STDMETHODCALLTYPE EnumSubCommands(IEnumExplorerCommand **out)override{if(!out)return E_POINTER;*out=nullptr;return E_NOTIMPL;}
    HRESULT STDMETHODCALLTYPE Invoke(IShellItemArray *items,IBindCtx*)override{
        try{
            ComPtr<IShellItem> location;DWORD count=0;
            if(items&&SUCCEEDED(items->GetCount(&count))&&count)items->GetItemAt(0,&location);
            if(!location&&site){ComPtr<IServiceProvider> services;ComPtr<IFolderView> view;
                if(SUCCEEDED(site.As(&services))&&SUCCEEDED(services->QueryService(SID_SFolderView,IID_PPV_ARGS(&view))))view->GetFolder(IID_PPV_ARGS(&location));}
            std::wstring directory;PWSTR path=nullptr;
            if(location&&SUCCEEDED(location->GetDisplayName(SIGDN_FILESYSPATH,&path))){directory=path;CoTaskMemFree(path);}
            const auto program=moduleDirectory()+L"\\UTerminal.exe";
            auto line=quote(program)+L" --open-terminal --directory "+quote(directory);
            STARTUPINFOW startup{};startup.cb=sizeof(startup);startup.dwFlags=STARTF_USESHOWWINDOW;startup.wShowWindow=SW_SHOWNORMAL;PROCESS_INFORMATION process{};
            if(!CreateProcessW(program.c_str(),line.data(),nullptr,nullptr,FALSE,CREATE_UNICODE_ENVIRONMENT,nullptr,nullptr,&startup,&process))return HRESULT_FROM_WIN32(GetLastError());
            CloseHandle(process.hThread);CloseHandle(process.hProcess);return S_OK;
        }catch(...){return E_FAIL;}
    }
};
class Factory final:public IClassFactory {
    std::atomic<ULONG> refs{1};
public:
    Factory(){++objects;}~Factory(){--objects;}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid,void **out)override{if(!out)return E_POINTER;*out=nullptr;if(iid!=IID_IUnknown&&iid!=IID_IClassFactory)return E_NOINTERFACE;*out=this;AddRef();return S_OK;}
    ULONG STDMETHODCALLTYPE AddRef()override{return ++refs;}
    ULONG STDMETHODCALLTYPE Release()override{auto count=--refs;if(!count)delete this;return count;}
    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown *outer,REFIID iid,void **out)override{if(outer)return CLASS_E_NOAGGREGATION;auto *command=new(std::nothrow) Command;if(!command)return E_OUTOFMEMORY;auto result=command->QueryInterface(iid,out);command->Release();return result;}
    HRESULT STDMETHODCALLTYPE LockServer(BOOL lock)override{if(lock)++locks;else --locks;return S_OK;}
};
}
BOOL WINAPI DllMain(HINSTANCE instance,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH)moduleHandle=instance;return TRUE;}
STDAPI DllGetClassObject(REFCLSID clsid,REFIID iid,void **out){
    if(clsid!=commandId)return CLASS_E_CLASSNOTAVAILABLE;auto *factory=new(std::nothrow) Factory;if(!factory)return E_OUTOFMEMORY;auto result=factory->QueryInterface(iid,out);factory->Release();return result;
}
STDAPI DllCanUnloadNow(){return objects==0&&locks==0?S_OK:S_FALSE;}
