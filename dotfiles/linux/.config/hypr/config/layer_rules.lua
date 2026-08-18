-- Keep the transparent Noctalia bar sharp while retaining compositor blur elsewhere.
hl.layer_rule({
    name = "eva-noctalia-bar-no-blur",
    match = { namespace = "^noctalia-bar-default$" },
    blur = false,
    blur_popups = false,
})
