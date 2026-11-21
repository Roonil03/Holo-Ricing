/* Original project code, MIT. Read-only primary-monitor work area query.
 * GDK 3 reports application pixels; the caller converts to Cinnamon stage
 * pixels with the monitor scale. Runtime loading needs no GTK development kit.
 * API reference: https://docs.gtk.org/gdk3/class.Monitor.html
 */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef struct { int x, y, width, height; } Rectangle;
typedef int (*Init)(int *, char ***);
typedef void *(*GetDisplay)(void);
typedef void *(*GetPrimary)(void *);
typedef void *(*GetMonitor)(void *, int);
typedef void (*GetWorkarea)(void *, Rectangle *);
typedef int (*GetScale)(void *);

int main(int argc, char **argv)
{
    void *library, *display, *monitor;
    Init init;
    GetDisplay get_display;
    GetPrimary get_primary;
    GetMonitor get_monitor;
    GetWorkarea get_workarea;
    GetScale get_scale;
    Rectangle area;
    int scale;
    if (argc == 2 && strcmp(argv[1], "--help") == 0) {
        puts("Read-only monitor query: widget-position --workarea (x y width height scale)");
        return 0;
    }
    if (argc != 2 || strcmp(argv[1], "--workarea") != 0) {
        fputs("Usage: widget-position --workarea\n", stderr);
        return 2;
    }
    library = dlopen("libgdk-3.so.0", RTLD_NOW | RTLD_LOCAL);
    if (library == NULL) {
        fputs("Required runtime library missing: libgdk-3.so.0\n", stderr);
        return 2;
    }
    init = (Init)dlsym(library, "gdk_init_check");
    get_display = (GetDisplay)dlsym(library, "gdk_display_get_default");
    get_primary = (GetPrimary)dlsym(library, "gdk_display_get_primary_monitor");
    get_monitor = (GetMonitor)dlsym(library, "gdk_display_get_monitor");
    get_workarea = (GetWorkarea)dlsym(library, "gdk_monitor_get_workarea");
    get_scale = (GetScale)dlsym(library, "gdk_monitor_get_scale_factor");
    if (init == NULL || get_display == NULL || get_primary == NULL ||
        get_monitor == NULL || get_workarea == NULL || get_scale == NULL) {
        fputs("Required GDK 3 monitor functions are unavailable\n", stderr);
        dlclose(library);
        return 2;
    }
    if (!init(NULL, NULL) || (display = get_display()) == NULL) {
        fputs("No display available to query the primary monitor\n", stderr);
        dlclose(library);
        return 1;
    }
    monitor = get_primary(display);
    if (monitor == NULL) monitor = get_monitor(display, 0);
    if (monitor == NULL) {
        fputs("No monitor available\n", stderr);
        dlclose(library);
        return 1;
    }
    get_workarea(monitor, &area);
    scale = get_scale(monitor);
    if (area.width <= 0 || area.height <= 0 || scale < 1 || scale > 4) {
        fputs("Invalid monitor dimensions or scale\n", stderr);
        dlclose(library);
        return 1;
    }
    printf("%d %d %d %d %d\n", area.x, area.y, area.width, area.height, scale);
    dlclose(library);
    return 0;
}
