/*
 * fd-guard: evita que gnome-remote-desktop-daemon cierre stdin (fd 0) y que el
 * listener de VNC herede ese descriptor. En contenedores sin systemd, hilos
 * internos del daemon cierran fd 0 y el listener acaba usando el fd 0; cierres
 * posteriores (dobles cierres de GLib/libvncserver) matan el listener y el
 * puerto VNC desaparece.
 *
 * Al interceptar close(0) y reabrir /dev/null sobre fd 0, el descriptor sigue
 * siempre ocupado y el listener recibe un fd normal.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <unistd.h>

typedef int (*close_fn)(int);

int
close (int fd)
{
  static close_fn real_close;

  if (!real_close)
    real_close = (close_fn) dlsym (RTLD_NEXT, "close");

  if (fd == 0)
    {
      int nul = open ("/dev/null", O_RDONLY);

      if (nul >= 0)
        {
          if (nul != 0)
            {
              dup2 (nul, 0);
              real_close (nul);
            }
          return 0;
        }
      return 0;
    }

  return real_close (fd);
}
