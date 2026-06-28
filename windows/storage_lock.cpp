#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#define NULL 0
#define INVALID_HANDLE_VALUE ((void *)(long long)-1)
#define GENERIC_READ 0x80000000L
#define GENERIC_WRITE 0x40000000L
#define OPEN_ALWAYS 4
#define FILE_ATTRIBUTE_NORMAL 0x00000080

extern "C"
{
    __declspec(dllimport) void *__stdcall CreateFileA(
        const char *lpFileName,
        unsigned long dwDesiredAccess,
        unsigned long dwShareMode,
        void *lpSecurityAttributes,
        unsigned long dwCreationDisposition,
        unsigned long dwFlagsAndAttributes,
        void *hTemplateFile);

    __declspec(dllimport) int __stdcall CloseHandle(void *hObject);
}

extern "C"
{
    __declspec(dllexport) void *acquire_kernel_lock(const char *filePath)
    {
        void *hFile = CreateFileA(
            filePath,
            GENERIC_READ | GENERIC_WRITE,
            0,
            NULL,
            OPEN_ALWAYS,
            FILE_ATTRIBUTE_NORMAL,
            NULL);

        if (hFile == INVALID_HANDLE_VALUE)
        {
            return NULL;
        }
        return hFile;
    }

    __declspec(dllexport) void release_kernel_lock(void *handle)
    {
        if (handle != NULL && handle != INVALID_HANDLE_VALUE)
        {
            CloseHandle(handle);
        }
    }
}
