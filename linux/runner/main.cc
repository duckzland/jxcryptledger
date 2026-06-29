#include "my_application.h"
#include <string>

bool g_IsDevelopmentMode = false;

int main(int argc, char **argv)
{
  for (int i = 0; i < argc; ++i)
  {
    if (std::string(argv[i]) == "--development")
    {
      g_IsDevelopmentMode = true;
      break;
    }
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
