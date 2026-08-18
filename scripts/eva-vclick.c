#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <wayland-client.h>

#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

struct app {
    struct wl_display *display;
    struct zwlr_virtual_pointer_manager_v1 *manager;
    struct zwlr_virtual_pointer_v1 *pointer;
};

static void registry_global(void *data, struct wl_registry *registry, uint32_t name,
                            const char *interface, uint32_t version) {
    struct app *app = data;
    if (strcmp(interface, zwlr_virtual_pointer_manager_v1_interface.name) != 0) {
        return;
    }

    app->manager = wl_registry_bind(
        registry, name, &zwlr_virtual_pointer_manager_v1_interface,
        version < 2 ? version : 2
    );
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static uint32_t now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint32_t)((ts.tv_sec * 1000ULL + ts.tv_nsec / 1000000ULL) & 0xffffffffU);
}

static int parse_coordinate(const char *value, uint32_t *coordinate) {
    char *end = NULL;
    unsigned long parsed = strtoul(value, &end, 10);
    if (*value == '\0' || *end != '\0' || parsed > UINT32_MAX) {
        return 0;
    }

    *coordinate = (uint32_t)parsed;
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "usage: %s X Y X_EXTENT Y_EXTENT\n", argv[0]);
        return 2;
    }

    uint32_t x;
    uint32_t y;
    uint32_t x_extent;
    uint32_t y_extent;
    if (!parse_coordinate(argv[1], &x)
        || !parse_coordinate(argv[2], &y)
        || !parse_coordinate(argv[3], &x_extent)
        || !parse_coordinate(argv[4], &y_extent)
        || x_extent == 0
        || y_extent == 0
        || x > x_extent
        || y > y_extent) {
        fprintf(stderr, "coordinates must fit within positive compositor extents\n");
        return 2;
    }

    struct app app = {0};
    app.display = wl_display_connect(NULL);
    if (app.display == NULL) {
        fprintf(stderr, "could not connect to Wayland: %s\n", strerror(errno));
        return 1;
    }

    struct wl_registry *registry = wl_display_get_registry(app.display);
    wl_registry_add_listener(registry, &registry_listener, &app);
    if (wl_display_roundtrip(app.display) < 0 || app.manager == NULL) {
        fprintf(stderr, "compositor does not provide wlr virtual-pointer-v1\n");
        wl_display_disconnect(app.display);
        return 1;
    }

    app.pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(app.manager, NULL);
    if (app.pointer == NULL) {
        fprintf(stderr, "could not create a virtual pointer\n");
        zwlr_virtual_pointer_manager_v1_destroy(app.manager);
        wl_display_disconnect(app.display);
        return 1;
    }

    const uint32_t time = now_ms();
    zwlr_virtual_pointer_v1_motion_absolute(app.pointer, time, x, y, x_extent, y_extent);
    zwlr_virtual_pointer_v1_button(app.pointer, time + 1, 272, WL_POINTER_BUTTON_STATE_PRESSED);
    zwlr_virtual_pointer_v1_button(app.pointer, time + 2, 272, WL_POINTER_BUTTON_STATE_RELEASED);
    zwlr_virtual_pointer_v1_frame(app.pointer);
    if (wl_display_roundtrip(app.display) < 0) {
        fprintf(stderr, "failed to send virtual pointer click: %s\n", strerror(errno));
        zwlr_virtual_pointer_v1_destroy(app.pointer);
        zwlr_virtual_pointer_manager_v1_destroy(app.manager);
        wl_display_disconnect(app.display);
        return 1;
    }

    zwlr_virtual_pointer_v1_destroy(app.pointer);
    zwlr_virtual_pointer_manager_v1_destroy(app.manager);
    wl_display_disconnect(app.display);
    return 0;
}
