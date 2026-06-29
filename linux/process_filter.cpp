#include "runner/my_application.h" // Gives access to your global: g_IsDevelopmentMode
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <dirent.h>
#include <unistd.h>
#include <cstring>

#define EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))

bool evaluate_matrix_rules(bool g_IsDevelopmentMode, bool as_server, bool hasServer, bool hasDevelopment)
{
    if (as_server)
    {
        // LOGIC #2: Finding a running background IPC Server instance
        if (g_IsDevelopmentMode)
        {
            // Dev Mode: Target server must strictly carry BOTH arguments
            return (hasServer && hasDevelopment);
        }
        else
        {
            // Production Mode: Target server must match --server and strictly FORBID --development
            return (hasServer && !hasDevelopment);
        }
    }
    else
    {
        // LOGIC #1: Finding other conflicting active UI Client windows
        if (g_IsDevelopmentMode)
        {
            // Dev Mode Client Rules:
            if (hasDevelopment && hasServer) {
                return true; // Skip dev server from UI list
            }
            if (!hasDevelopment) {
                return true; // Skip foreign prod windows/servers completely
            }
            return false; // Keep alternative companion dev clients!
        }
        else
        {
            // Production Mode Client Rules:
            // Skip the process if it's a server (hasServer) OR if it belongs to the dev environment (hasDevelopment)
            // This leaves only plain, standard production UI windows to be registered as conflicts.
            if (hasServer || hasDevelopment) {
                return true; // Skip servers and dev instances from the production client conflict check
            }
            return false; // Register as a true conflicting production UI client instance!
        }
    }
}


bool check_process(const std::string &pidStr, bool as_server = false)
{
    if (std::stoll(pidStr) == getpid())
    {
        std::ifstream selfCmdFile("/proc/self/cmdline");
        bool selfHasServer = false;
        bool selfHasDevelopment = false;
        std::string selfArg;

        if (selfCmdFile.is_open()) {
            while (std::getline(selfCmdFile, selfArg, '\0')) {
                if (selfArg.find("--server") != std::string::npos) {
                    selfHasServer = true;
                }
                if (selfArg.find("--development") != std::string::npos) {
                    selfHasDevelopment = true;
                }
            }
            selfCmdFile.close();
        }

        // FIX: Route through the exact same logic matrix function to ensure 
        // that local and remote processes evaluate with absolute rule parity
        return evaluate_matrix_rules(g_IsDevelopmentMode, as_server, selfHasServer, selfHasDevelopment);
    }

    std::string cmdlinePath = "/proc/" + pidStr + "/cmdline";
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
        if (argument.find("--server") != std::string::npos)
        {
            hasServer = true;
        }
        if (argument.find("--development") != std::string::npos)
        {
            hasDevelopment = true;
        }
    }
    infile.close();

    return evaluate_matrix_rules(g_IsDevelopmentMode, as_server, hasServer, hasDevelopment);
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
