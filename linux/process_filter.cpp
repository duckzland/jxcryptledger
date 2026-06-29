#include "my_application.h" // Gives access to your global: g_IsDevelopmentMode
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <dirent.h>
#include <unistd.h>
#include <cstring>

#define EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))

bool check_process(const std::string &pidStr, bool as_server = false)
{
    std::string cmdlinePath;

    if (std::stoll(pidStr) == getpid())
    {
        cmdlinePath = "/proc/self/cmdline";
    }
    else
    {
        cmdlinePath = "/proc/" + pidStr + "/cmdline";
    }

    std::ifstream infile(cmdlinePath);
    if (!infile.is_open())
    {
        return false;
    }

    bool hasServer = false;
    bool hasDevelopment = false;
    std::string argument;

    while (std::getline(infile, argument, '\0'))
    {
        if (argument == "--server")
        {
            hasServer = true;
        }
        else if (argument == "--development")
        {
            hasDevelopment = true;
        }
    }
    infile.close();

    bool isValid = false;

    if (as_server)
    {
        if (g_IsDevelopmentMode)
        {
            isValid = (hasServer && hasDevelopment);
        }
        else
        {
            isValid = (hasServer && !hasDevelopment);
        }
    }
    else
    {
        if (g_IsDevelopmentMode)
        {
            isValid = hasDevelopment;
        }
        else
        {
            isValid = (hasServer && !hasDevelopment);
        }
    }

    return isValid;
}

EXPORT int get_active_process_pids(int *outPids, int maxCount)
{
    int foundCount = 0;

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
                    if (check_process(pidStr, false))
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
                    if (check_process(pidStr, true))
                    {
                        closedir(procDir);
                        return 1;
                    }
                }
            }
        }
    }
    closedir(procDir);
    return 0;
}
