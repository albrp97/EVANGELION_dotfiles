--- @since 26.5.6

local current_cwd = ya.sync(function()
	return cx.active.current.cwd
end)

local function notify(level, format, ...)
	ya.notify {
		title = "Smart create",
		content = string.format(format, ...),
		level = level,
		timeout = 5,
	}
end

local function has_extension(name)
	return name:match("%.[^%.]+$") ~= nil
end

local function create_parent(url)
	local parent = url.parent
	if not parent then
		return true
	end

	local ok, err = fs.create("dir_all", parent)
	if not ok then
		notify("error", "Could not create the parent directory:\n%s", tostring(err))
		return false
	end
	return true
end

return {
	entry = function()
		local value, event = ya.input {
			title = "Create:",
			pos = { "top-center", y = 3, w = 50 },
		}
		if event == 2 then
			return
		end
		if event ~= 1 or not value or value == "" then
			notify("warn", "A name is required")
			return
		end

		local explicit_dir = value:sub(-1) == "/" or value:sub(-1) == "\\"
		local name = value:gsub("[/\\]+$", "")
		local leaf = name:match("([^/\\]+)$")
		if not leaf or leaf == "." or leaf == ".." then
			notify("error", "Enter a valid file or folder name")
			return
		end

		local target = current_cwd():join(name)
		local is_dir = explicit_dir or not has_extension(leaf)

		if not create_parent(target) then
			return
		end

		if is_dir then
			local ok, err = fs.create("dir", target)
			if not ok then
				notify("error", "Could not create folder:\n%s", tostring(err))
				return
			end
		else
			local fd, err = fs.access():write(true):create_new(true):open(target)
			if not fd then
				notify("error", "Could not create file:\n%s", tostring(err))
				return
			end
		end

		ya.emit("refresh", {})
		ya.emit("reveal", { target = Url(target) })
	end,
}
