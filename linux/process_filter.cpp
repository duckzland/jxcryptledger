#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <dirent.h>
#include <unistd.h>
#include <cstring>

// EXPORT macro for statically embedded compilation inside the primary binary
#define EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))

// Helper to check if a Linux process was started with the "--server" flag
bool check_if_process_has_server_arg(const std::string &pidStr)
{
    // Current application instance checking shortcut
    if (std::stoll(pidStr) == getpid())
    {
        // Read our own arguments securely from /proc/self/cmdline
        std::ifstream cmdFile("/proc/self/cmdline");
        std::string arg;
        while (std::getline(cmdFile, arg, '\0'))
        {
            if (arg == "--server")
            {
                return true;
            }
        }
        return false;
    }

    // Remote process inspection
    std::string cmdlinePath = "/proc/" + pidStr + "/cmdline";
    std::ifstream infile(cmdlinePath);
    if (!infile.is_open())
    {
        return false; // Process closed or access denied
    }

    std::string argument;
    // Linux cmdline segments arguments with null terminators ('\0')
    while (std::getline(infile, argument, '\0'))
    {
        if (argument == "--server")
        {
            return true;
        }
    }
    return false;
}

EXPORT int get_active_process_pids(int *outPids, int maxCount)
{
    int foundCount = 0;

    // Open the /proc directory to iterate over all active system processes
    DIR *procDir = opendir("/proc");
    if (!procDir)
    {
        return 0;
    }

    struct dirent *entry;
    while ((entry = readdir(procDir)) != nullptr)
    {
        // We only care about directories that are numbers (PIDs)
        if (entry->d_type == DT_DIR && entry->d_name[0] >= '0' && entry->d_name[0] <= '9')
        {
            std::string pidStr(entry->d_name);
            std::string commPath = "/proc/" + pidStr + "/comm";

            std::ifstream commFile(commPath);
            if (commFile.is_open())
            {
                std::string procName;
                std::getline(commFile, procName);

                // Match your binary name (Linux apps drop the ".exe" suffix)
                if (procName == "jxledger")
                {
                    // If it contains '--server', exclude it from UI list matching your logic
                    if (check_if_process_has_server_arg(pidStr))
                    {
                        continue;
                    }

                    if (foundCount < maxCount)
                    {
                        outPids[foundCount++] = std::stoi(pidStr);
                    }
                }
            }
        }
    }
    closedir(procDir);
    return foundCount;
}

EXPORT int is_server_instance_running()
{
    DIR *procDir = opendir("/proc");
    if (!procDir)
    {
        return 0;
    }

    struct dirent *entry;
    while ((entry = readdir(procDir)) != nullptr)
    {
        if (entry->d_type == DT_DIR && entry->d_name[0] >= '0' && entry->d_name[0] <= '9')
        {
            std::string pidStr(entry->d_name);
            std::string commPath = "/proc/" + pidStr + "/comm";

            std::ifstream commFile(commPath);
            if (commFile.is_open())
            {
                std::string procName;
                std::getline(commFile, procName);

                if (procName == "jxledger")
                {
                    if (check_if_process_has_server_arg(pidStr))
                    {
                        closedir(procDir);
                        return 1; // Server instance matched!
                    }
                }
            }
        }
    }
    closedir(procDir);
    return 0;
}
