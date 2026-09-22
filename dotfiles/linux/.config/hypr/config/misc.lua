hl.config({
    dwindle = {
        preserve_split = true,
    },
    general = {
        layout = "lua:eva-grid",
    },
    misc = {
        col = {
            splash = CACHYLGREEN,
        },
        middle_click_paste = false,
        -- Keep the terminal visible when it launches a GUI app from the shell or Yazi.
        enable_swallow = false,
        vrr = 3,
    },
    xwayland = {
        force_zero_scaling = true
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})