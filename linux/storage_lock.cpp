#include <fcntl.h>
#include <unistd.h>
#include <sys/file.h>

// Use extern "C" and visibility/used attributes so DynamicLibrary.executable()
// can find the exact strings 'acquire_kernel_lock' and 'release_kernel_lock'
extern "C" __attribute__((visibility("default"))) __attribute__((used)) void *acquire_kernel_lock(const char *filePath)
{
    // 1. Open or create the marker file
    int fd = open(filePath, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if (fd == -1)
    {
        return 0; // Maps to Dart's 'nullptr'
    }

    // 2. Apply the exclusive lock. If a slave instance is running, this fails instantly.
    if (flock(fd, LOCK_EX | LOCK_NB) == -1)
    {
        close(fd); // Clean up the file descriptor to prevent leaks
        return 0;  // Maps to Dart's 'nullptr'
    }

    // 3. Success: Cast the integer file descriptor to a pointer representation
    return (void *)(long long)fd;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used)) void release_kernel_lock(void *handle)
{
    // Replicate Dart's nullptr guard check safely inside C++
    if (handle == 0)
    {
        return;
    }

    // Convert the pointer tracking context back into the Linux integer file descriptor
    int fd = (int)(long long)handle;

    flock(fd, LOCK_UN); // Remove the kernel file lock
    close(fd);          // Close the file descriptor
}
