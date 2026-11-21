/* Original project code, MIT. Native supervision of Cinnamon's stock locker.
 * Cinnamon remains the sole authentication/rendering implementation. Wallpaper
 * writes run in a separate native helper so pipe EOF restores after a crash.
 * Public GLib/GIO/JSON-GLib ABI is loaded at runtime: no SDK packages required.
 */
#define _POSIX_C_SOURCE 200809L
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <limits.h>
#include <poll.h>
#include <pwd.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define NAME "org.cinnamon.ScreenSaver"
#define SCREEN_PATH "/org/cinnamon/ScreenSaver"
#define BUS "org.freedesktop.DBus"
#define BUS_PATH "/org/freedesktop/DBus"

static volatile sig_atomic_t stopping;
static void stop(int signum) { (void)signum; stopping = 1; }
static void *gio, *json;
static void *(*parser_new)(void);
static int (*parser_load)(void *, const char *, long, void **);
static void *(*parser_root)(void *);
static int (*node_type)(void *);
static unsigned long (*node_value_type)(void *);
static const char *(*type_name)(unsigned long);
static void *(*node_object)(void *);
static void *(*node_array)(void *);
static const char *(*node_string)(void *);
static int64_t (*node_int)(void *);
static void *(*object_member)(void *, const char *);
static unsigned int (*object_size)(void *);
static void (*object_set_int)(void *, const char *, int64_t);
static unsigned int (*array_length)(void *);
static void *(*array_element)(void *, unsigned int);
static char *(*json_string)(void *, int);
static void (*unref)(void *);
static void (*release)(void *);
static void (*error_free)(void *);
static void *(*bus_get)(int, void *, void **);
static void *(*bus_call)(void *, const char *, const char *, const char *, const char *, void *, const void *, int, int, void *, void **);
static int (*bus_closed)(void *);
static unsigned int (*bus_subscribe)(void *, const char *, const char *, const char *, const char *, const char *, int, void (*)(void *, const char *, const char *, const char *, const char *, void *, void *), void *, void *);
static void (*bus_unsubscribe)(void *, unsigned int);
static void *(*variant_new)(const char *, ...);
static void (*variant_get)(void *, const char *, ...);
static void (*variant_unref)(void *);
static int (*context_pending)(void *);
static int (*context_iteration)(void *, int);
static void *(*schema_default)(void);
static void *(*schema_lookup)(void *, const char *, int);
static int (*schema_has_key)(void *, const char *);
static void (*schema_unref)(void *);
static void *(*settings_new)(void *, void *, const char *);
static int (*settings_boolean)(void *, const char *);

#define SYMBOL(handle, variable, name) do { \
    *(void **)(&(variable)) = dlsym(handle, name); \
    if (!(variable)) { fprintf(stderr, "Missing runtime API: %s\n", name); return 0; } \
} while (0)
static int load_api(void)
{
    gio = dlopen("libgio-2.0.so.0", RTLD_NOW | RTLD_LOCAL);
    json = dlopen("libjson-glib-1.0.so.0", RTLD_NOW | RTLD_LOCAL);
    if (!gio || !json) { fputs("GIO and JSON-GLib runtime libraries required\n", stderr); return 0; }
    SYMBOL(gio, unref, "g_object_unref");
    SYMBOL(gio, release, "g_free");
    SYMBOL(gio, error_free, "g_error_free");
    SYMBOL(gio, type_name, "g_type_name");
    SYMBOL(json, parser_new, "json_parser_new");
    SYMBOL(json, parser_load, "json_parser_load_from_data");
    SYMBOL(json, parser_root, "json_parser_get_root");
    SYMBOL(json, node_type, "json_node_get_node_type");
    SYMBOL(json, node_value_type, "json_node_get_value_type");
    SYMBOL(json, node_object, "json_node_get_object");
    SYMBOL(json, node_array, "json_node_get_array");
    SYMBOL(json, node_string, "json_node_get_string");
    SYMBOL(json, node_int, "json_node_get_int");
    SYMBOL(json, object_member, "json_object_get_member");
    SYMBOL(json, object_size, "json_object_get_size");
    SYMBOL(json, object_set_int, "json_object_set_int_member");
    SYMBOL(json, array_length, "json_array_get_length");
    SYMBOL(json, array_element, "json_array_get_element");
    SYMBOL(json, json_string, "json_to_string");
    SYMBOL(gio, bus_get, "g_bus_get_sync");
    SYMBOL(gio, bus_call, "g_dbus_connection_call_sync");
    SYMBOL(gio, bus_closed, "g_dbus_connection_is_closed");
    SYMBOL(gio, bus_subscribe, "g_dbus_connection_signal_subscribe");
    SYMBOL(gio, bus_unsubscribe, "g_dbus_connection_signal_unsubscribe");
    SYMBOL(gio, variant_new, "g_variant_new");
    SYMBOL(gio, variant_get, "g_variant_get");
    SYMBOL(gio, variant_unref, "g_variant_unref");
    SYMBOL(gio, context_pending, "g_main_context_pending");
    SYMBOL(gio, context_iteration, "g_main_context_iteration");
    SYMBOL(gio, schema_default, "g_settings_schema_source_get_default");
    SYMBOL(gio, schema_lookup, "g_settings_schema_source_lookup");
    SYMBOL(gio, schema_has_key, "g_settings_schema_has_key");
    SYMBOL(gio, schema_unref, "g_settings_schema_unref");
    SYMBOL(gio, settings_new, "g_settings_new_full");
    SYMBOL(gio, settings_boolean, "g_settings_get_boolean");
    return 1;
}

/* Reject symbolic links in every path component, including the leaf. */
static int path_valid(const char *path, int trusted)
{
    char copy[PATH_MAX];
    struct stat info;
    size_t len = strlen(path);
    if (path[0] != '/' || len < 2 || len >= sizeof(copy)) return 0;
    memcpy(copy, path, len + 1);
    if (lstat("/", &info) || (trusted && (info.st_uid || (info.st_mode & 022)))) return 0;
    for (size_t i = 1; i <= len; ++i) {
        if (copy[i] && copy[i] != '/') continue;
        char saved = copy[i];
        copy[i] = '\0';
        if (lstat(copy, &info) || S_ISLNK(info.st_mode) ||
            (trusted && (info.st_uid || (info.st_mode & 022)))) return 0;
        copy[i] = saved;
    }
    return !stat(path, &info) && S_ISREG(info.st_mode);
}
static int private_fd(const char *path, int empty)
{
    if (!path_valid(path, 0)) return -1;
    int fd = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
    if (fd < 0) return -1;
    struct stat info;
    if (fstat(fd, &info) || !S_ISREG(info.st_mode) || info.st_uid != getuid() ||
        (info.st_mode & 07777) != 0600 || (empty && (info.st_nlink != 1 || info.st_size))) {
        close(fd); return -1;
    }
    return fd;
}
static char *read_fd(int fd)
{
    struct stat info;
    if (fstat(fd, &info) || info.st_size < 0 || info.st_size > 1024 * 1024) return NULL;
    size_t size = (size_t)info.st_size;
    char *data = malloc(size + 1);
    if (!data) return NULL;
    size_t used = 0;
    while (used < size) {
        ssize_t n = read(fd, data + used, size - used);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) { free(data); return NULL; }
        used += (size_t)n;
    }
    data[used] = 0;
    return data;
}
static void *parse_json(const char *data)
{
    void *parser = parser_new(), *error = NULL;
    if (!parser || !parser_load(parser, data, -1, &error)) {
        if (error) error_free(error);
        if (parser) unref(parser);
        return NULL;
    }
    if (!parser_root(parser) || node_type(parser_root(parser)) != 0) { unref(parser); return NULL; }
    return parser;
}
static int typed(void *node, const char *name)
{
    if (!node || node_type(node) != 2) return 0;
    const char *actual = type_name(node_value_type(node));
    return actual && !strcmp(actual, name);
}
static const char *string_member(void *object, const char *name)
{
    void *node = object_member(object, name);
    return typed(node, "gchararray") ? node_string(node) : NULL;
}
struct Config {
    char *desktop, *images[3], *helper, *state, *token, *lock_path;
    int interval, motion;
};
static void free_config(struct Config *c)
{
    free(c->desktop); free(c->helper); free(c->state); free(c->token); free(c->lock_path);
    for (int i = 0; i < 3; ++i) free(c->images[i]);
}
static int load_config(const char *path, struct Config *c)
{
    int fd = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    if (fd < 0) return 0;
    char *data = read_fd(fd); close(fd);
    if (!data) return 0;
    void *parser = parse_json(data); free(data);
    if (!parser) return 0;
    void *o = node_object(parser_root(parser));
    const char *desktop = string_member(o, "desktop_image"), *helper = string_member(o, "native_helper");
    const char *state = string_member(o, "state"), *token = string_member(o, "token");
    const char *lock = string_member(o, "lock_path"), *mode = string_member(o, "mode");
    void *images = object_member(o, "lock_images"), *interval = object_member(o, "image_interval");
    int valid = desktop && helper && state && token && lock && images && node_type(images) == 1;
    if (valid) valid = array_length(node_array(images)) == 3;
    if (object_member(o, "mode") && !mode) valid = 0;
    if (!mode) mode = "rotation";
    if (strcmp(mode, "rotation") && strcmp(mode, "motion") && strcmp(mode, "motion-cycle")) valid = 0;
    c->interval = 300;
    if (interval) {
        if (!typed(interval, "gint64") || node_int(interval) < 10 || node_int(interval) > 3600) valid = 0;
        else c->interval = (int)node_int(interval);
    }
    if (valid) {
        c->desktop = strdup(desktop); c->helper = strdup(helper); c->state = strdup(state);
        c->token = strdup(token); c->lock_path = strdup(lock); c->motion = !strcmp(mode, "motion");
        for (int i = 0; i < 3; ++i) {
            void *n = array_element(node_array(images), (unsigned int)i);
            if (!typed(n, "gchararray")) { valid = 0; break; }
            c->images[i] = strdup(node_string(n));
        }
        valid = valid && c->desktop && c->helper && c->state && c->token && c->lock_path &&
            c->images[0] && c->images[1] && c->images[2];
    }
    unref(parser);
    return valid;
}
static int read_index(const struct Config *c, void **out_parser)
{
    int fd = private_fd(c->state, 0);
    if (fd < 0) return -1;
    char *data = read_fd(fd); close(fd);
    if (!data) return -1;
    void *parser = parse_json(data); free(data);
    if (!parser) return -1;
    void *o = node_object(parser_root(parser));
    const char *token = string_member(o, "token");
    void *index = object_member(o, "next_index");
    int result = -1;
    if (object_size(o) == 2 && token && !strcmp(token, c->token) && typed(index, "gint64") &&
        node_int(index) >= 0 && node_int(index) < 3) result = (int)node_int(index);
    if (out_parser && result >= 0) *out_parser = parser;
    else unref(parser);
    return result;
}
static int write_all(int fd, const char *data, size_t size)
{
    while (size) {
        ssize_t n = write(fd, data, size);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return 0;
        data += n; size -= (size_t)n;
    }
    return 1;
}
static int save_index(const struct Config *c, int *index)
{
    void *parser = NULL;
    if (read_index(c, &parser) != *index) {
        if (parser) unref(parser);
        fputs("Rotation state changed externally\n", stderr); return 0;
    }
    int next = (*index + 1) % 3;
    object_set_int(node_object(parser_root(parser)), "next_index", next);
    char *data = json_string(parser_root(parser), 0);
    unref(parser);
    if (!data) return 0;
    char name[PATH_MAX];
    const char *slash = strrchr(c->state, '/');
    size_t prefix = slash ? (size_t)(slash - c->state + 1) : 0;
    if (!prefix || prefix + sizeof(".lock-index-XXXXXX") > sizeof(name)) { release(data); return 0; }
    memcpy(name, c->state, prefix);
    memcpy(name + prefix, ".lock-index-XXXXXX", sizeof(".lock-index-XXXXXX"));
    int fd = mkstemp(name), result = 0;
    if (fd >= 0) {
        result = write_all(fd, data, strlen(data)) && !fsync(fd);
        if (close(fd)) result = 0;
        if (result && rename(name, c->state)) result = 0;
        if (!result) unlink(name);
    }
    release(data);
    if (result) *index = next;
    return result;
}
static double monotonic(void)
{
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts)) return 0;
    return ts.tv_sec + ts.tv_nsec / 1000000000.0;
}
static int wait_child(pid_t pid, int seconds)
{
    double end = monotonic() + seconds;
    for (;;) {
        int status;
        pid_t result = waitpid(pid, &status, WNOHANG);
        if (result == pid) return WIFEXITED(status) && !WEXITSTATUS(status);
        if (result < 0 && errno != EINTR) return 0;
        if (monotonic() >= end) { kill(pid, SIGKILL); while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {} return 0; }
        struct timespec pause = {0, 10000000}; nanosleep(&pause, NULL);
    }
}
static void exec_helper(const struct Config *c, const char *action, int lock_fd)
{
    char number[32];
    snprintf(number, sizeof(number), "%d", lock_fd);
    if (lock_fd >= 0 && fcntl(lock_fd, F_SETFD, 0)) _exit(126);
    if (!strcmp(action, "--check"))
        execl(c->helper, c->helper, action, c->desktop, c->images[0], c->images[1], c->images[2], (char *)NULL);
    else execl(c->helper, c->helper, action, number, c->desktop, c->images[0], c->images[1], c->images[2], (char *)NULL);
    _exit(127);
}
static int helper_once(const struct Config *c, const char *action, int lock_fd)
{
    pid_t pid = fork();
    if (pid == 0) exec_helper(c, action, lock_fd);
    return pid > 0 && wait_child(pid, 30);
}
struct Worker {
    const struct Config *config;
    void *bus, *screensaver, *lockdown;
    pid_t locker, helper;
    int input, output, locked, index, failed;
    char *owner;
    double next_tick;
};
static int start_helper(struct Worker *w, int lock_fd)
{
    int input[2], output[2];
    if (pipe(input)) return 0;
    if (pipe(output)) { close(input[0]); close(input[1]); return 0; }
    for (int i = 0; i < 2; ++i) { fcntl(input[i], F_SETFD, FD_CLOEXEC); fcntl(output[i], F_SETFD, FD_CLOEXEC); }
    pid_t pid = fork();
    if (pid == 0) {
        if (dup2(input[0], STDIN_FILENO) < 0 || dup2(output[1], STDOUT_FILENO) < 0) _exit(126);
        close(input[0]); close(input[1]); close(output[0]); close(output[1]);
        exec_helper(w->config, "--serve", lock_fd);
    }
    close(input[0]); close(output[1]);
    if (pid < 0) { close(input[1]); close(output[0]); return 0; }
    w->helper = pid; w->input = input[1]; w->output = output[0];
    return 1;
}
static int wallpaper(struct Worker *w, int index)
{
    char command = index < 0 ? 'R' : (char)('0' + index);
    if (!write_all(w->input, &command, 1)) return 0;
    const char expected[] = "OK\n";
    double deadline = monotonic() + 5;
    for (size_t i = 0; i < sizeof(expected) - 1; ++i) {
        for (;;) {
            int remaining = (int)((deadline - monotonic()) * 1000);
            if (remaining <= 0) return 0;
            struct pollfd fd = {w->output, POLLIN, 0};
            int ready = poll(&fd, 1, remaining);
            if (ready < 0 && errno == EINTR) continue;
            if (ready <= 0) return 0;
            char value;
            ssize_t count = read(w->output, &value, 1);
            if (count < 0 && errno == EINTR) continue;
            if (count != 1 || value != expected[i]) return 0;
            break;
        }
    }
    return 1;
}
static int restore(struct Worker *w)
{
    if (!wallpaper(w, -1)) { fputs("Could not restore desktop wallpaper; inspect service journal\n", stderr); return 0; }
    w->locked = 0; w->next_tick = 0;
    free(w->owner); w->owner = NULL;
    return 1;
}
static int advance(struct Worker *w, double now)
{
    if (!wallpaper(w, w->config->motion ? 0 : w->index)) return 0;
    if (w->config->motion) { w->next_tick = 0; return 1; }
    if (!save_index(w->config, &w->index)) return 0;
    w->next_tick = now + w->config->interval;
    return 1;
}
static void *call(struct Worker *w, const char *destination, const char *path,
                  const char *interface, const char *method, void *parameters)
{
    void *error = NULL;
    /* G_DBUS_CALL_FLAGS_NO_AUTO_START = 1. */
    void *reply = bus_call(w->bus, destination, path, interface, method, parameters, NULL, 1, 5000, NULL, &error);
    if (error) error_free(error);
    return reply;
}
static int name_has_owner(struct Worker *w, int *active)
{
    void *reply = call(w, BUS, BUS_PATH, BUS, "NameHasOwner", variant_new("(s)", NAME));
    if (!reply) return 0;
    variant_get(reply, "(b)", active); variant_unref(reply); return 1;
}
static char *get_owner(struct Worker *w)
{
    void *reply = call(w, BUS, BUS_PATH, BUS, "GetNameOwner", variant_new("(s)", NAME));
    if (!reply) return NULL;
    const char *name = NULL; variant_get(reply, "(&s)", &name);
    char *owner = name ? strdup(name) : NULL;
    variant_unref(reply); return owner;
}
static int get_active(struct Worker *w, const char *owner, int *active)
{
    void *reply = call(w, owner, SCREEN_PATH, NAME, "GetActive", NULL);
    if (!reply) return 0;
    variant_get(reply, "(b)", active); variant_unref(reply); return 1;
}
static int child_alive(struct Worker *w)
{
    if (w->locker <= 0) return 0;
    int status;
    pid_t result = waitpid(w->locker, &status, WNOHANG);
    if (result == 0) return 1;
    if (result < 0 && errno == EINTR) return child_alive(w);
    w->locker = 0; return 0;
}
/* These are the checks used by xapp.os, without starting a Python runtime. */
static int restricted_session(void)
{
    char cmdline[65536];
    int fd = open("/proc/cmdline", O_RDONLY | O_CLOEXEC);
    if (fd >= 0) {
        ssize_t size;
        do { size = read(fd, cmdline, sizeof(cmdline) - 1); } while (size < 0 && errno == EINTR);
        close(fd);
        if (size < 0) return 1;
        cmdline[size] = 0;
        if (strstr(cmdline, "boot=casper") || strstr(cmdline, "boot=live")) return 1;
    } else if (errno != EACCES && errno != ENOENT) return 1;
    struct passwd *user = getpwuid(getuid());
    if (!user || !user->pw_name || !user->pw_dir) return 1;
    const char *home = getenv("HOME");
    if (!home) home = user->pw_dir;
    if (home && strstr(home, "/tmp/guest")) return 1;
    struct group *group = getgrnam("nopasswdlogin");
    if (group) for (char **member = group->gr_mem; member && *member; ++member)
        if (!strcmp(*member, user->pw_name)) return 1;
    return 0;
}
static int owner_capable(struct Worker *w, const char *owner)
{
    if (!child_alive(w) || !settings_boolean(w->screensaver, "lock-enabled") ||
        settings_boolean(w->lockdown, "disable-lock-screen") || restricted_session()) return 0;
    void *reply = call(w, BUS, BUS_PATH, BUS, "GetConnectionUnixProcessID", variant_new("(s)", owner));
    if (!reply) return -1;
    unsigned int pid = 0; variant_get(reply, "(u)", &pid); variant_unref(reply);
    return pid == (unsigned int)w->locker && child_alive(w);
}
static int start_locker(struct Worker *w)
{
    if (!path_valid("/usr/bin/cinnamon-screensaver", 1) ||
        !path_valid("/usr/share/cinnamon-screensaver/cinnamon-screensaver-main.py", 1)) {
        fputs("Untrusted or missing distribution screensaver program\n", stderr); return 0;
    }
    pid_t pid = fork();
    if (pid == 0) {
        int null = open("/dev/null", O_RDONLY);
        if (null < 0 || dup2(null, STDIN_FILENO) < 0) _exit(126);
        if (null != STDIN_FILENO) close(null);
        execl("/usr/bin/cinnamon-screensaver", "/usr/bin/cinnamon-screensaver", (char *)NULL);
        _exit(127);
    }
    if (pid < 0) return 0;
    w->locker = pid; return 1;
}
static int bus_failure(struct Worker *w)
{
    if (w->locked && !restore(w)) return 0;
    return !bus_closed(w->bus);
}
static int step(struct Worker *w, double now)
{
    int owned = 0;
    if (!name_has_owner(w, &owned)) return bus_failure(w);
    if (!owned) {
        if (w->locked) return restore(w);
        return child_alive(w) || start_locker(w);
    }
    char *owner = get_owner(w);
    if (!owner) return bus_failure(w);
    int capable = owner_capable(w, owner), result = 1, active = 0;
    if (capable < 0) { free(owner); return bus_failure(w); }
    if (!capable) { if (w->locked) result = restore(w); goto done; }
    if (!get_active(w, owner, &active)) { free(owner); return bus_failure(w); }
    if (!active || (w->locked && strcmp(w->owner, owner))) {
        if (w->locked) result = restore(w);
        goto done;
    }
    if (!w->locked) {
        /* Deliberately turn an active, unlocked screensaver into a lock. */
        void *reply = call(w, owner, SCREEN_PATH, NAME, "Lock", variant_new("(s)", ""));
        if (!reply) { free(owner); return bus_failure(w); }
        variant_unref(reply);
        char *current = get_owner(w);
        if (!current) { free(owner); return bus_failure(w); }
        int same = !strcmp(current, owner); free(current);
        if (!same) goto done;
        if (!get_active(w, owner, &active)) { free(owner); return bus_failure(w); }
        if (!active) goto done;
        w->owner = strdup(owner);
        if (!w->owner) { result = 0; goto done; }
        w->locked = 1;
        result = advance(w, now);
    } else if (w->next_tick && now >= w->next_tick) result = advance(w, now);
done:
    free(owner); return result;
}
static void active_changed(void *connection, const char *sender, const char *path,
                           const char *interface, const char *signal, void *parameters, void *data)
{
    (void)connection; (void)sender; (void)path; (void)interface; (void)signal;
    struct Worker *w = data;
    int active = 0; variant_get(parameters, "(b)", &active);
    if (!active && w->locked && !restore(w)) w->failed = 1;
}
static void owner_changed(void *connection, const char *sender, const char *path,
                          const char *interface, const char *signal, void *parameters, void *data)
{
    (void)connection; (void)sender; (void)path; (void)interface; (void)signal;
    struct Worker *w = data;
    const char *name, *previous, *current;
    variant_get(parameters, "(&s&s&s)", &name, &previous, &current);
    (void)name;
    if (w->locked && !strcmp(previous, w->owner) && strcmp(current, previous) && !restore(w)) w->failed = 1;
}
static void *boolean_settings(const char *name, const char *key)
{
    void *source = schema_default();
    void *schema = source ? schema_lookup(source, name, 1) : NULL;
    if (!schema) return NULL;
    void *settings = schema_has_key(schema, key) ? settings_new(schema, NULL, NULL) : NULL;
    schema_unref(schema); return settings;
}
static int supervise(const struct Config *c, int lock_fd, int index)
{
    struct Worker w;
    memset(&w, 0, sizeof(w)); w.config = c; w.index = index; w.input = w.output = -1;
    if (!start_helper(&w, lock_fd)) return 0;
    void *error = NULL;
    w.bus = bus_get(2, NULL, &error); /* G_BUS_TYPE_SESSION */
    if (error) error_free(error);
    w.screensaver = boolean_settings("org.cinnamon.desktop.screensaver", "lock-enabled");
    w.lockdown = boolean_settings("org.cinnamon.desktop.lockdown", "disable-lock-screen");
    unsigned int active_id = 0, owner_id = 0;
    int result = 0;
    if (!w.bus || !w.screensaver || !w.lockdown) {
        fputs("Cinnamon settings and a session bus are required\n", stderr); goto done;
    }
    active_id = bus_subscribe(w.bus, NAME, NAME, "ActiveChanged", SCREEN_PATH, NULL, 0, active_changed, &w, NULL);
    owner_id = bus_subscribe(w.bus, BUS, BUS, "NameOwnerChanged", BUS_PATH, NAME, 0, owner_changed, &w, NULL);
    if (!restore(&w)) goto done;
    result = 1;
    double next_check = 0;
    while (!stopping && !w.failed) {
        while (context_pending(NULL)) context_iteration(NULL, 0);
        if (stopping || w.failed) break;
        double now = monotonic();
        if (now >= next_check) {
            if (!step(&w, now)) { result = 0; break; }
            next_check = now + 1;
        }
        struct timespec pause = {0, 100000000}; nanosleep(&pause, NULL);
    }
    if (w.failed) result = 0;
done:
    if (active_id) bus_unsubscribe(w.bus, active_id);
    if (owner_id) bus_unsubscribe(w.bus, owner_id);
    if (!restore(&w)) result = 0;
    close(w.input); close(w.output);
    if (!wait_child(w.helper, 5)) { fputs("Native wallpaper helper failed; external wallpaper edits were preserved\n", stderr); result = 0; }
    /* Never quit or kill the inherited Cinnamon screensaver. */
    if (w.bus) unref(w.bus);
    if (w.screensaver) unref(w.screensaver);
    if (w.lockdown) unref(w.lockdown);
    free(w.owner); return result;
}
int main(int argc, char **argv)
{
    if (argc == 2 && !strcmp(argv[1], "--help")) {
        puts("lockscreen-worker CONFIG [--check|--restore|--status]\n"
             "Supervise the distribution Cinnamon locker; preserve external wallpaper edits.");
        return 0;
    }
    if (argc < 2 || argc > 3) { fputs("Use --help for usage\n", stderr); return 2; }
    const char *action = argc == 3 ? argv[2] : "";
    int check = !strcmp(action, "--check"), restore_only = !strcmp(action, "--restore");
    int status = !strcmp(action, "--status");
    if (*action && !check && !restore_only && !status) { fputs("Unsupported worker action\n", stderr); return 2; }
    if (!load_api()) return 2;
    struct Config config; memset(&config, 0, sizeof(config));
    int result = 2, lock_fd = -1;
    if (!load_config(argv[1], &config)) { fputs("Invalid lockscreen configuration\n", stderr); goto done; }
    int index;
    if (status) {
        index = read_index(&config, NULL);
        if (index < 0) { fputs("Invalid or externally changed private rotation state\n", stderr); goto done; }
        printf("{\"next_index\": %d}\n", index); result = 0; goto done;
    }
    lock_fd = private_fd(config.lock_path, 1);
    if (lock_fd < 0 || (!check && flock(lock_fd, LOCK_EX | LOCK_NB))) {
        fputs("An empty private user-owned rotation lock is required and must be available\n", stderr); goto done;
    }
    if (!path_valid(config.helper, 0)) { fputs("Native helper must be an absolute regular path without symlinks\n", stderr); goto done; }
    if (restore_only) { result = helper_once(&config, "--restore", lock_fd) ? 0 : 1; goto done; }
    index = read_index(&config, NULL);
    if (index < 0) { fputs("Invalid or externally changed private rotation state\n", stderr); goto done; }
    if (!helper_once(&config, "--check", -1)) { fputs("Native image validation failed\n", stderr); goto done; }
    if (check) { result = 0; goto done; }
    const char *session = getenv("XDG_SESSION_TYPE");
    if (session && !strcmp(session, "wayland")) { fputs("This Cinnamon screensaver integration requires an X11 session\n", stderr); goto done; }
    struct sigaction action_handler;
    memset(&action_handler, 0, sizeof(action_handler)); action_handler.sa_handler = stop;
    sigemptyset(&action_handler.sa_mask);
    sigaction(SIGTERM, &action_handler, NULL); sigaction(SIGINT, &action_handler, NULL);
    signal(SIGPIPE, SIG_IGN);
    result = supervise(&config, lock_fd, index) ? 0 : 1;
done:
    if (lock_fd >= 0) close(lock_fd);
    free_config(&config);
    if (json) dlclose(json);
    if (gio) dlclose(gio);
    return result;
}
