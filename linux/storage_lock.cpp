#include <fcntl.h>
#include <unistd.h>
#include <sys/file.h>

extern "C" __attribute__((visibility("default"))) __attribute__((used)) void *acquire_kernel_lock(const char *filePath)
{
    int fd = open(filePath, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if (fd == -1)
    {
        return 0;
    }

    if (flock(fd, LOCK_EX | LOCK_NB) == -1)
    {
        close(fd);
        return 0;
    }

    return (void *)(long long)(fd + 1);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used)) void release_kernel_lock(void *handle)
{
    if (handle == 0)
    {
        return;
    }

    int fd = (int)(long long)handle;
    fd = fd - 1;

    flock(fd, LOCK_UN);
    close(fd);
}
