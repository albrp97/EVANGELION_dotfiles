require("full-border"):setup {
	type = ui.Border.ROUNDED,
}

require("smart-enter"):setup {
	open_multi = true,
}

require("git"):setup {
	order = 1500,
}

require("starship"):setup {
	config_file = "~/.config/starship.toml",
	flags_after_prompt = true,
	show_right_prompt = false,
}
