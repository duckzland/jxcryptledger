#include "runner/utils.h"
#include <windows.h>
#include <string.h>
#include <wchar.h>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#define NULL 0

#pragma comment(lib, "wtsapi32.lib")

typedef long(__stdcall *pfnNtQueryInformationProcess)(void *, unsigned long, void *, unsigned long, unsigned long *);

struct WTS_PROCESS_INFOW
{
    unsigned long SessionId;
    unsigned long ProcessId;
    wchar_t *pProcessName;
    void *pUserSid;
};

struct PROCESS_BASIC_INFORMATION_MIN
{
    void *Reserved1;
    void *PebBaseAddress;
    void *Reserved2[2];
    unsigned long long UniqueProcessId;
    void *Reserved3;
};

struct UNICODE_STRING_MIN
{
    unsigned short Length;
    unsigned short MaximumLength;
    wchar_t *Buffer;
};

extern "C"
{
    __declspec(dllimport) int __stdcall WTSEnumerateProcessesW(void *hServer, unsigned long Reserved, unsigned long Version, WTS_PROCESS_INFOW **ppProcessInfo, unsigned long *pCount);
    __declspec(dllimport) void __stdcall WTSFreeMemory(void *pMemory);
    __declspec(dllimport) void *__stdcall OpenProcess(unsigned long dwDesiredAccess, int bInheritHandle, unsigned long dwProcessId);
    __declspec(dllimport) int __stdcall CloseHandle(void *hObject);
    __declspec(dllimport) int __stdcall ReadProcessMemory(void *hProcess, const void *lpBaseAddress, void *lpBuffer, unsigned long long nSize, unsigned long long *lpNumberOfBytesRead);
}

bool evaluate_matrix_rules(bool g_IsDevelopmentMode, bool as_server, bool hasServer, bool hasDevelopment)
{
    if (as_server)
    {
        if (g_IsDevelopmentMode)
        {
            return (hasServer && hasDevelopment);
        }
        else
        {
            return (hasServer && !hasDevelopment);
        }
    }
    else
    {
        if (g_IsDevelopmentMode)
        {
            if (hasDevelopment && hasServer) {
                return true;
            }
            if (!hasDevelopment) {
                return true;
            }
            return false;
        }
        else
        {
            if (hasServer || hasDevelopment) {
                return true;
            }
            return false;
        }
    }
}

bool check_process(unsigned long pid, bool as_server = false)
{
    if (pid == GetCurrentProcessId())
    {
        wchar_t *myCmd = GetCommandLineW();
        if (myCmd == NULL) return false;

        bool selfHasServer = (wcsstr(myCmd, L"--server") != NULL);
        bool selfHasDevelopment = (wcsstr(myCmd, L"--development") != NULL);

        return evaluate_matrix_rules(g_IsDevelopmentMode, as_server, selfHasServer, selfHasDevelopment);
    }

    HMODULE hModule = GetModuleHandleA("ntdll.dll");
    if (!hModule)
        return false;

    pfnNtQueryInformationProcess NtQueryInformationProcess =
        (pfnNtQueryInformationProcess)GetProcAddress(hModule, "NtQueryInformationProcess");
    if (!NtQueryInformationProcess)
        return false;

    void *hProcess = OpenProcess(0x1000 /* PROCESS_QUERY_LIMITED_INFORMATION */ | 0x0010 /* PROCESS_VM_READ */, 0, pid);
    if (!hProcess)
    {
        hProcess = OpenProcess(0x0400 /* PROCESS_QUERY_INFORMATION */ | 0x0010 /* PROCESS_VM_READ */, 0, pid);
    }
    if (!hProcess)
        return false;

    bool isValid = false;
    PROCESS_BASIC_INFORMATION_MIN pbi;
    unsigned long retLen = 0;

    if (NtQueryInformationProcess(hProcess, 0, &pbi, sizeof(pbi), &retLen) == 0)
    {
        unsigned long long pebAddress = (unsigned long long)pbi.PebBaseAddress;
        unsigned long long processParametersAddress = 0;
        unsigned long long bytesRead = 0;

        if (ReadProcessMemory(hProcess, (const void *)(pebAddress + 0x20),
                              &processParametersAddress, sizeof(processParametersAddress), &bytesRead))
        {
            UNICODE_STRING_MIN cmdLine;
            if (ReadProcessMemory(hProcess, (const void *)(processParametersAddress + 0x70),
                                  &cmdLine, sizeof(cmdLine), &bytesRead))
            {
                size_t charactersToRead = cmdLine.Length / sizeof(wchar_t);
                if (charactersToRead > 0)
                {
                    wchar_t *cmdLineBuffer = new wchar_t[charactersToRead + 1];
                    if (ReadProcessMemory(hProcess, cmdLine.Buffer,
                                          cmdLineBuffer, cmdLine.Length, &bytesRead))
                    {
                        size_t charactersRead = bytesRead / sizeof(wchar_t);
                        cmdLineBuffer[charactersRead] = L'\0';

                        bool hasServer = (wcsstr(cmdLineBuffer, L"--server") != NULL);
                        bool hasDevelopment = (wcsstr(cmdLineBuffer, L"--development") != NULL);

                        isValid = evaluate_matrix_rules(g_IsDevelopmentMode, as_server, hasServer, hasDevelopment);
                    }
                    else
                    {
                        isValid = false;
                    }
                    delete[] cmdLineBuffer;
                }
            }
        }
    }
    
    CloseHandle(hProcess);
    return isValid;
}

extern "C"
{
    __declspec(dllexport) int get_active_process_pids(int *outPids, int maxCount)
    {
        WTS_PROCESS_INFOW *pProcesses = NULL;
        unsigned long processCount = 0;
        int foundCount = 0;

        if (WTSEnumerateProcessesW(NULL, 0, 1, &pProcesses, &processCount))
        {
            for (unsigned long i = 0; i < processCount; i++)
            {
                wchar_t *procName = pProcesses[i].pProcessName;
                unsigned long targetPid = pProcesses[i].ProcessId;

                if (procName != NULL && targetPid != 0)
                {
                    if (_wcsicmp(procName, L"jxledger.exe") == 0)
                    {
                        if (check_process(targetPid, false))
                        {
                            continue;
                        }

                        if (foundCount < maxCount)
                        {
                            outPids[foundCount++] = (int)targetPid;
                        }
                    }
                }
            }
            WTSFreeMemory(pProcesses);
        }
        return foundCount;
    }

    __declspec(dllexport) int is_server_instance_running()
    {
        WTS_PROCESS_INFOW *pProcesses = NULL;
        unsigned long processCount = 0;
        int serverFound = 0;

        if (WTSEnumerateProcessesW(NULL, 0, 1, &pProcesses, &processCount))
        {
            for (unsigned long i = 0; i < processCount; i++)
            {
                wchar_t *procName = pProcesses[i].pProcessName;
                unsigned long targetPid = pProcesses[i].ProcessId;

                if (procName != NULL && targetPid != 0)
                {
                    if (_wcsicmp(procName, L"jxledger.exe") == 0)
                    {
                        if (check_process(targetPid, true))
                        {
                            serverFound = 1;
                            break;
                        }
                    }
                }
            }
            WTSFreeMemory(pProcesses);
        }
        return serverFound;
    }
}
