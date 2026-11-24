/* Original project code, MIT. Read-only static image validation.
 * API references: https://docs.gtk.org/gdk-pixbuf/class.PixbufAnimation.html
 * Runtime loading uses Mint's existing image decoder without development headers.
 */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef void *(*LoadImage)(const char *, void **);
typedef int (*IsStatic)(void *);
typedef void (*Release)(void *);

int main(int argc, char **argv)
{
    void *library, *image, *error = NULL;
    LoadImage load;
    IsStatic is_static;
    Release unref, error_free;
    int valid;
    if (argc == 2 && strcmp(argv[1], "--help") == 0) {
        puts("Read-only validation: image-check --check FILE or --dry-run FILE");
        return 0;
    }
    if (argc != 3 || (strcmp(argv[1], "--check") != 0 &&
                      strcmp(argv[1], "--dry-run") != 0)) {
        fputs("Usage: image-check --check FILE\n", stderr);
        return 2;
    }
    library = dlopen("libgdk_pixbuf-2.0.so.0", RTLD_NOW | RTLD_LOCAL);
    if (library == NULL) {
        fputs("Required runtime library missing: libgdk_pixbuf-2.0.so.0\n", stderr);
        return 2;
    }
    load = (LoadImage)dlsym(library, "gdk_pixbuf_animation_new_from_file");
    is_static = (IsStatic)dlsym(library, "gdk_pixbuf_animation_is_static_image");
    unref = (Release)dlsym(library, "g_object_unref");
    error_free = (Release)dlsym(library, "g_error_free");
    if (load == NULL || is_static == NULL || unref == NULL || error_free == NULL) {
        fputs("Required GdkPixbuf runtime functions are unavailable\n", stderr);
        dlclose(library);
        return 2;
    }
    image = load(argv[2], &error);
    if (image == NULL) {
        fprintf(stderr, "Image cannot be decoded: %s\n", argv[2]);
        if (error != NULL) error_free(error);
        dlclose(library);
        return 1;
    }
    valid = is_static(image);
    unref(image);
    dlclose(library);
    if (!valid) {
        fprintf(stderr, "Select a static image: %s\n", argv[2]);
        return 1;
    }
    return 0;
}
