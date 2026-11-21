/* Original project code, MIT. Native Cinnamon wallpaper transport.
 * Cinnamon owns the screen, crossfades and authentication. The supervising
 * worker verifies its locker before sending an image index. No PAM/kernel API.
 * Load the distribution's public GLib/GIO/GdkPixbuf ABI without dev packages.
 */
#define _POSIX_C_SOURCE 200809L
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

static volatile sig_atomic_t stopping;
static volatile sig_atomic_t signal_write = -1;
static void stop(int signum)
{
    (void)signum;
    int saved = errno;
    stopping = 1;
    /* GLib may have threads: wake the input wait even if another thread
     * receives the signal. The nonblocking pipe also closes the wait race. */
    if (signal_write >= 0) {
        char byte = 0;
        ssize_t ignored = write(signal_write, &byte, 1);
        (void)ignored;
    }
    errno = saved;
}
static void *gio, *pixbuf;
static void *(*schema_default)(void);
static void *(*schema_lookup)(void *, const char *, int);
static int (*schema_has_key)(void *, const char *);
static void (*schema_unref)(void *);
static void *(*settings_new)(void *, void *, const char *);
static int (*settings_writable)(void *, const char *);
static int (*settings_set)(void *, const char *, const char *);
static char *(*settings_get)(void *, const char *);
static void (*settings_sync)(void);
static int (*context_pending)(void *);
static int (*context_iteration)(void *, int);
static void *(*image_load)(const char *, void **);
static int (*image_static)(void *);
static char *(*uri_escape)(const char *, const char *, int);
static void (*unref)(void *);
static void (*release)(void *);
static void (*error_free)(void *);

#define SYMBOL(handle, var, name) do { \
    *(void **)(&(var)) = dlsym(handle, name); \
    if (!(var)) { fprintf(stderr, "Missing runtime API: %s\n", name); return 0; } \
} while (0)
static int load_api(void)
{
    gio = dlopen("libgio-2.0.so.0", RTLD_NOW | RTLD_LOCAL);
    pixbuf = dlopen("libgdk_pixbuf-2.0.so.0", RTLD_NOW | RTLD_LOCAL);
    if (!gio || !pixbuf) { fputs("GLib/GIO/GdkPixbuf runtime libraries required\n", stderr); return 0; }
    SYMBOL(gio, schema_default, "g_settings_schema_source_get_default");
    SYMBOL(gio, schema_lookup, "g_settings_schema_source_lookup");
    SYMBOL(gio, schema_has_key, "g_settings_schema_has_key");
    SYMBOL(gio, schema_unref, "g_settings_schema_unref");
    SYMBOL(gio, settings_new, "g_settings_new_full");
    SYMBOL(gio, settings_writable, "g_settings_is_writable");
    SYMBOL(gio, settings_set, "g_settings_set_string");
    SYMBOL(gio, settings_get, "g_settings_get_string");
    SYMBOL(gio, settings_sync, "g_settings_sync");
    SYMBOL(gio, context_pending, "g_main_context_pending");
    SYMBOL(gio, context_iteration, "g_main_context_iteration");
    SYMBOL(gio, uri_escape, "g_uri_escape_string");
    SYMBOL(gio, unref, "g_object_unref");
    SYMBOL(gio, release, "g_free");
    SYMBOL(gio, error_free, "g_error_free");
    SYMBOL(pixbuf, image_load, "gdk_pixbuf_animation_new_from_file");
    SYMBOL(pixbuf, image_static, "gdk_pixbuf_animation_is_static_image");
    return 1;
}

/* Check every path component, including parents. No relative paths or links. */
static int real_path(const char *path)
{
    char copy[PATH_MAX];
    struct stat info;
    size_t len = strlen(path);
    if (path[0] != '/' || len >= sizeof(copy) || len < 2) return 0;
    memcpy(copy, path, len + 1);
    for (size_t i = 1; i <= len; ++i) {
        if (copy[i] != '/' && copy[i] != '\0') continue;
        char saved = copy[i];
        copy[i] = '\0';
        if (lstat(copy, &info) || S_ISLNK(info.st_mode)) return 0;
        copy[i] = saved;
    }
    return !stat(path, &info) && S_ISREG(info.st_mode);
}

static char *image_uri(const char *path)
{
    void *error = NULL;
    if (!real_path(path)) { fputs("Expected an absolute regular image path without symlinks\n", stderr); return NULL; }
    void *image = image_load(path, &error);
    if (!image) {
        if (error) error_free(error);
        fputs("Image cannot be decoded\n", stderr);
        return NULL;
    }
    int valid = image_static(image);
    unref(image);
    if (!valid) { fputs("Select a static image\n", stderr); return NULL; }
    /* Match Python Path.as_uri(), including reserved filename characters.
     * g_filename_to_uri() leaves apostrophe/@/:/& unescaped; the supervisor
     * writes their escaped forms and ownership comparisons must agree. */
    char *escaped = uri_escape(path, "/", 0);
    if (!escaped) return NULL;
    size_t size = strlen(escaped) + 8;
    char *uri = malloc(size);
    if (uri) snprintf(uri, size, "file://%s", escaped);
    release(escaped);
    return uri;
}

static int lock_valid(const char *text)
{
    char *end;
    errno = 0;
    long number = strtol(text, &end, 10);
    if (errno || !*text || *end || number < 3 || number > INT_MAX) return 0;
    struct stat info;
    int fd = (int)number;
    if (fstat(fd, &info) || !S_ISREG(info.st_mode) || info.st_uid != getuid() ||
        (info.st_mode & 07777) != 0600 || info.st_nlink != 1 || info.st_size) return 0;
    return !flock(fd, LOCK_EX | LOCK_NB);
}

static int set_wallpaper(void *settings, const char *target, const char *expected,
                         char **allowed, int count)
{
    while (context_pending(NULL)) context_iteration(NULL, 0);
    char *current = settings_get(settings, "picture-uri");
    int owned = 0;
    if (current) {
        if (expected) owned = !strcmp(current, expected);
        else for (int i = 0; i < count; ++i) if (!strcmp(current, allowed[i])) owned = 1;
        release(current);
    }
    if (!owned) {
        fputs("Wallpaper changed externally; preserving it\n", stderr);
        return 0;
    }
    if (!settings_writable(settings, "picture-uri") || !settings_set(settings, "picture-uri", target)) {
        fputs("Could not update Cinnamon wallpaper\n", stderr);
        return 0;
    }
    settings_sync();
    return 1;
}

int main(int argc, char **argv)
{
    if (argc == 2 && !strcmp(argv[1], "--help")) {
        puts("lockscreen-native --check DESKTOP IMAGE1 IMAGE2 IMAGE3\n"
             "lockscreen-native --serve LOCK_FD DESKTOP IMAGE1 IMAGE2 IMAGE3\n"
             "lockscreen-native --restore LOCK_FD DESKTOP IMAGE1 IMAGE2 IMAGE3\n"
             "Supervisor protocol: R restores, 0/1/2 selects a static lock image, Q exits.\n"
             "Cinnamon supplies the crossfade; this helper does not render video or authenticate.");
        return 0;
    }
    int check = argc == 6 && !strcmp(argv[1], "--check");
    int serve = argc == 7 && !strcmp(argv[1], "--serve");
    int restore = argc == 7 && !strcmp(argv[1], "--restore");
    if (!check && !serve && !restore) { fputs("Use --help for usage\n", stderr); return 2; }
    if (!check && !lock_valid(argv[2])) { fputs("An inherited private rotation lock is required\n", stderr); return 2; }
    if (!load_api()) return 2;
    char *uris[4] = {NULL, NULL, NULL, NULL};
    int result = 2, offset = check ? 2 : 3;
    struct stat identities[4];
    for (int i = 0; i < 4; ++i) {
        uris[i] = image_uri(argv[offset + i]);
        if (!uris[i] || stat(argv[offset + i], &identities[i])) goto done;
        for (int j = 0; j < i; ++j) {
            if (identities[i].st_dev == identities[j].st_dev && identities[i].st_ino == identities[j].st_ino) {
                fputs("Desktop and all three lock images must be distinct files\n", stderr);
                goto done;
            }
        }
    }
    if (check) { result = 0; goto done; }
    void *source = schema_default();
    void *schema = source ? schema_lookup(source, "org.cinnamon.desktop.background", 1) : NULL;
    if (!schema || !schema_has_key(schema, "picture-uri")) {
        if (schema) schema_unref(schema);
        fputs("Cinnamon background settings schema is unavailable\n", stderr);
        goto done;
    }
    void *settings = settings_new(schema, NULL, NULL);
    schema_unref(schema);
    if (!settings) goto done;
    if (restore) {
        result = set_wallpaper(settings, uris[0], NULL, uris, 4) ? 0 : 1;
        unref(settings);
        goto done;
    }
    int wake[2];
    if (pipe(wake)) { unref(settings); goto done; }
    for (int i = 0; i < 2; ++i) {
        if (fcntl(wake[i], F_SETFD, FD_CLOEXEC) ||
            fcntl(wake[i], F_SETFL, O_NONBLOCK)) {
            close(wake[0]); close(wake[1]); unref(settings); goto done;
        }
    }
    signal_write = wake[1];
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = stop;
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    signal(SIGPIPE, SIG_IGN);
    const char *last = uris[0];
    result = 0;
    while (!stopping) {
        struct pollfd input[2] = {{STDIN_FILENO, POLLIN, 0}, {wake[0], POLLIN, 0}};
        int ready = poll(input, 2, -1);
        if (ready < 0) { if (errno == EINTR) continue; result = 1; break; }
        if (stopping || input[1].revents) break;
        char command;
        ssize_t size = read(STDIN_FILENO, &command, 1);
        if (size < 0 && errno == EINTR) continue;
        if (size == 0) break; /* Supervisor crash closes its end of the pipe. */
        if (size < 0) { result = 1; break; }
        if (command == 'Q') break;
        int index = command == 'R' ? 0 : command >= '0' && command <= '2' ? command - '0' + 1 : -1;
        if (index < 0) { fputs("Invalid supervisor command\n", stderr); result = 2; break; }
        if (!set_wallpaper(settings, uris[index], last, uris, 4)) { result = 1; break; }
        last = uris[index];
        if (fputs("OK\n", stdout) == EOF || fflush(stdout)) { result = 1; break; }
    }
    if (!set_wallpaper(settings, uris[0], last, uris, 4)) result = 1;
    signal_write = -1;
    close(wake[0]); close(wake[1]);
    unref(settings);
done:
    for (int i = 0; i < 4; ++i) if (uris[i]) free(uris[i]);
    if (pixbuf) dlclose(pixbuf);
    if (gio) dlclose(gio);
    return result;
}
