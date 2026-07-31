#include "runner/utils.h"
#include <windows.h>
#include <string>
#include <vector>
#include <comdef.h>
#include <WbemIdl.h>

#pragma comment(lib, "wbemuuid.lib")

extern bool g_IsDevelopmentMode;

struct ProcessMatch {
    DWORD pid;
    std::wstring cmdLine;
};

struct WmiBridge {
    IWbemLocator* pLoc = nullptr;
    IWbemServices* pSvc = nullptr;
    bool initialized = false;

    WmiBridge() {
        HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
            return; 
        }

        hr = CoInitializeSecurity(
            nullptr, -1, nullptr, nullptr, 
            RPC_C_AUTHN_LEVEL_DEFAULT, RPC_C_IMP_LEVEL_IMPERSONATE, 
            nullptr, EOAC_NONE, nullptr
        );

        hr = CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER, IID_IWbemLocator, (LPVOID*)&pLoc);
        if (SUCCEEDED(hr)) {
            hr = pLoc->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), nullptr, nullptr, nullptr, 0, nullptr, nullptr, &pSvc);
            if (SUCCEEDED(hr)) {
                CoSetProxyBlanket(pSvc, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, nullptr, RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE, nullptr, EOAC_NONE);
                initialized = true; 
            }
        }
    }

    ~WmiBridge() {
        if (pSvc) pSvc->Release();
        if (pLoc) pLoc->Release();
        CoUninitialize();
    }
};

bool evaluate_matrix_rules(bool is_dev_mode, bool as_server, bool hasServer, bool hasDevelopment) {
    if (as_server) {
        return is_dev_mode ? (hasServer && hasDevelopment) : (hasServer && !hasDevelopment);
    } else {
        return is_dev_mode ? (!hasDevelopment || (hasDevelopment && hasServer)) : (hasServer || hasDevelopment);
    }
}

std::vector<ProcessMatch> get_target_processes_wmi_cached(const std::wstring& targetExe) {
    std::vector<ProcessMatch> matches;
    
    static WmiBridge bridge;
    if (!bridge.initialized) return matches;

    IEnumWbemClassObject* pEnumerator = nullptr;
    std::wstring query = L"SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = '" + targetExe + L"'";
    
    HRESULT hr = bridge.pSvc->ExecQuery(_bstr_t(L"WQL"), _bstr_t(query.c_str()), WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY, nullptr, &pEnumerator);
    if (FAILED(hr)) return matches;

    IWbemClassObject* pclsObj = nullptr;
    ULONG uReturn = 0;
    
    while (pEnumerator->Next(WBEM_INFINITE, 1, &pclsObj, &uReturn) == 0) {
        VARIANT vtPid, vtCmd;
        VariantInit(&vtPid);
        VariantInit(&vtCmd);

        if (SUCCEEDED(pclsObj->Get(L"ProcessId", 0, &vtPid, nullptr, nullptr)) && vtPid.vt == VT_I4) {
            std::wstring cmdLine = L"";
            if (SUCCEEDED(pclsObj->Get(L"CommandLine", 0, &vtCmd, nullptr, nullptr)) && vtCmd.vt == VT_BSTR && vtCmd.bstrVal != nullptr) {
                cmdLine = vtCmd.bstrVal;
            }
            matches.push_back({ (DWORD)vtPid.lVal, cmdLine });
        }

        VariantClear(&vtPid);
        VariantClear(&vtCmd);
        pclsObj->Release();
    }
    pEnumerator->Release();
    return matches;
}

extern "C" {
    __declspec(dllexport) int get_active_process_pids(int *outPids, int maxCount) {
        if (!outPids || maxCount <= 0) return 0;

        std::vector<ProcessMatch> processes = get_target_processes_wmi_cached(L"jxledger.exe");
        int foundCount = 0;
        DWORD currentPid = GetCurrentProcessId();

        for (const auto& proc : processes) {
            if (foundCount >= maxCount) {
                break;
            }

            std::wstring cmd = proc.cmdLine;
            if (cmd.empty()) continue;

            if (proc.pid == currentPid) {
                wchar_t* myCmd = GetCommandLineW();
                if (myCmd) cmd = myCmd;
            }

            bool hasServer = (cmd.find(L"--server") != std::wstring::npos);
            bool hasDevelopment = (cmd.find(L"--development") != std::wstring::npos);

            if (evaluate_matrix_rules(g_IsDevelopmentMode, false, hasServer, hasDevelopment)) {
                continue; 
            }

            outPids[foundCount++] = (int)proc.pid;
        }
        return foundCount;
    }

    __declspec(dllexport) int is_server_instance_running() {
        std::vector<ProcessMatch> processes = get_target_processes_wmi_cached(L"jxledger.exe");
        DWORD currentPid = GetCurrentProcessId();

        for (const auto& proc : processes) {
            std::wstring cmd = proc.cmdLine;
            if (cmd.empty()) continue;

            if (proc.pid == currentPid) {
                wchar_t* myCmd = GetCommandLineW();
                if (myCmd) cmd = myCmd;
            }

            bool hasServer = (cmd.find(L"--server") != std::wstring::npos);
            bool hasDevelopment = (cmd.find(L"--development") != std::wstring::npos);

            if (evaluate_matrix_rules(g_IsDevelopmentMode, true, hasServer, hasDevelopment)) {
                return 1; 
            }
        }
        return 0;
    }
}
