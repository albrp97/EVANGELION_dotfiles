-- Look and feel configuration

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 3,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = {
                colors = { CACHYLGREEN, CACHYDGREEN },
                angle = 45,
            },
            inactive_border = CACHYLAVENDER,
        },
    },
    group = {
        col = {
            border_active = CACHYLAVENDER,
            border_inactive = CACHYMUTED,
            border_locked_active = CACHYDPURPLE,
            border_locked_inactive = CACHYMUTED,
        },
        groupbar = {
            col = {
                active = CACHYLGREEN,
                inactive = CACHYMUTED,
                locked_active = CACHYDPURPLE,
                locked_inactive = CACHYMUTED,
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.94,
        fullscreen_opacity = 1,
        blur = {
            enabled = true,
            size = 5,
            passes = 4,
            special = true,
        },
    },
})
