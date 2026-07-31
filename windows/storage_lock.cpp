#include "runner/utils.h"
#include <windows.h>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

extern "C"
{
    __declspec(dllexport) void* acquire_kernel_lock(const wchar_t* lockName)
    {
        if (!lockName) return nullptr;

        std::wstring fullLockName = L"Local\\" + std::wstring(lockName);

        HANDLE hMutex = CreateMutexW(nullptr, FALSE, fullLockName.c_str());
        if (hMutex == nullptr)
        {
            return nullptr;
        }

        if (GetLastError() == ERROR_ALREADY_EXISTS)
        {
            CloseHandle(hMutex);
            return nullptr; 
        }

        return (void*)hMutex;
    }

    __declspec(dllexport) void release_kernel_lock(void* handle)
    {
        if (handle != nullptr && handle != INVALID_HANDLE_VALUE)
        {
            CloseHandle((HANDLE)handle);
        }
    }
}
