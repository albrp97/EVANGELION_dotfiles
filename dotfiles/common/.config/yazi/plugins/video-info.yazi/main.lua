--- @since 26.8.15
--- @sync entry

local M = {}

local VIDEO_EXTENSIONS = {
	["3g2"] = true,
	["3gp"] = true,
	["asf"] = true,
	["avi"] = true,
	["divx"] = true,
	["f4v"] = true,
	["flv"] = true,
	["m2ts"] = true,
	["m4v"] = true,
	["mkv"] = true,
	["mov"] = true,
	["mp4"] = true,
	["mpeg"] = true,
	["mpg"] = true,
	["mxf"] = true,
	["ogv"] = true,
	["rm"] = true,
	["rmvb"] = true,
	["ts"] = true,
	["vob"] = true,
	["webm"] = true,
	["wmv"] = true,
}

local get_cached = ya.sync(function(st, key)
	return st.cache[key]
end)

local put_cached = ya.sync(function(st, key, signature, metadata, render)
	st.cache[key] = {
		signature = signature,
		ok = metadata ~= nil,
		metadata = metadata,
	}
	if render then
		ui.render()
	end
end)

local set_sorting = ya.sync(function(st, value)
	st.sorting = value
end)

local begin_sorting = ya.sync(function(st)
	if st.sorting then
		return false
	end
	st.sorting = true
	return true
end)

local get_context = ya.sync(function()
	local current = cx.active.current
	return tostring(current.cwd), current.hovered and tostring(current.hovered.url)
end)

local is_current_directory = ya.sync(function(_, cwd_path)
	return tostring(cx.active.current.cwd) == cwd_path
end)

local function file_signature(file)
	local cha = file.cha or {}
	return string.format("%s:%s", tostring(cha.len or 0), tostring(cha.mtime or 0))
end

local function cache_key(file)
	return tostring(file.url)
end

local function is_local_regular(file)
	if file.cha and file.cha.is_dir then
		return false
	end

	return file.url.spec.is_regular
end

local function is_video_extension(file)
	local ext = file.url.ext
	return ext and VIDEO_EXTENSIONS[ext:lower()] or false
end

local function number(value, minimum)
	local result = tonumber(value)
	if result and result == result and result >= (minimum or 0) then
		return result
	end
end

local function frame_rate(value)
	if type(value) ~= "string" then
		return number(value, 0)
	end

	local numerator, denominator = value:match("^%s*([%d%.]+)%s*/%s*([%d%.]+)%s*$")
	if numerator and denominator then
		denominator = tonumber(denominator)
		if denominator and denominator ~= 0 then
			return number(tonumber(numerator) / denominator, 0)
		end
	end

	return number(value, 0)
end

local function probe(path)
	local output = Command("ffprobe")
		:arg({
			"-v",
			"error",
			"-show_entries",
			"format=duration:stream=codec_type,codec_name,width,height,avg_frame_rate,r_frame_rate",
			"-of",
			"json=c=1",
			"--",
			tostring(path),
		})
		:output()

	if not output or not output.status.success then
		return
	end

	local decoded = ya.json_decode(output.stdout)
	if type(decoded) ~= "table" then
		return
	end

	local format = type(decoded.format) == "table" and decoded.format or {}
	local streams = type(decoded.streams) == "table" and decoded.streams or {}
	local video
	for _, stream in ipairs(streams) do
		if type(stream) == "table" and stream.codec_type == "video" then
			video = stream
			break
		end
	end
	if not video then
		return
	end

	local fps = frame_rate(video.avg_frame_rate)
	if not fps then
		fps = frame_rate(video.r_frame_rate)
	end

	return {
		duration = number(format.duration, 0),
		width = number(video.width, 1),
		height = number(video.height, 1),
		fps = fps,
		streams = streams,
	}
end

local function metadata_snapshot(file)
	local cha = file.cha
	local local_regular = file.url.spec.is_regular and not cha.is_dir
	return {
		key = tostring(file.url),
		signature = file_signature(file),
		local_regular = local_regular,
		path = local_regular and tostring(file.url.path) or nil,
		is_dir = cha.is_dir,
		is_video = is_video_extension(file),
		name = tostring(file.name),
	}
end

local function metadata_for_snapshot(snapshot, render)
	local cached = get_cached(snapshot.key)
	if cached and cached.signature == snapshot.signature then
		return cached.ok and cached.metadata or nil
	end

	local metadata
	if snapshot.local_regular then
		metadata = probe(snapshot.path)
	end
	put_cached(snapshot.key, snapshot.signature, metadata, render)
	return metadata
end

local function metadata_for(st, file, render)
	return metadata_for_snapshot(metadata_snapshot(file), render)
end

local function format_duration(seconds)
	if not seconds then
		return nil
	end

	local total = math.floor(seconds + 0.5)
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

local function format_fps(fps)
	if not fps then
		return nil
	end

	local rounded = math.floor(fps * 100 + 0.5) / 100
	if math.abs(rounded - math.floor(rounded)) < 0.005 then
		return string.format("%.0f fps", rounded)
	end
	return string.format("%.2f fps", rounded)
end

local function metadata_label(metadata)
	local parts = {}
	if metadata.width and metadata.height then
		parts[#parts + 1] = string.format("%dx%d", metadata.width, metadata.height)
	end
	local fps = format_fps(metadata.fps)
	if fps then
		parts[#parts + 1] = fps
	end
	local duration = format_duration(metadata.duration)
	if duration then
		parts[#parts + 1] = duration
	end
	return table.concat(parts, " ")
end

local function cached_metadata_snapshot(snapshot)
	local cached = get_cached(snapshot.key)
	if cached and cached.signature == snapshot.signature and cached.ok then
		return cached.metadata
	end
end

local function cached_metadata(st, file)
	return cached_metadata_snapshot(metadata_snapshot(file))
end

local function video_linemode(st, file)
	if not file.in_current or file.cha.is_dir then
		return ""
	end

	local metadata = cached_metadata(st, file)
	if not metadata then
		return ""
	end

	local label = metadata_label(metadata)
	if label == "" then
		return ""
	end
	return ui.Line { " ", ui.Span(label):style(ui.Style():fg("#D98BC4")) }
end

local function video_rows(metadata)
	local rows = {
		ui.Row({ "Video" }):style(ui.Style():fg("green")),
		ui.Row { "  Duration:", format_duration(metadata and metadata.duration) or "-" },
		ui.Row {
			"  Dimensions:",
			metadata and metadata.width and metadata.height and string.format("%dx%d", metadata.width, metadata.height) or "-",
		},
		ui.Row { "  Frame rate:", metadata and format_fps(metadata.fps) or "-" },
	}

	if not metadata then
		rows[#rows + 1] = ui.Row { "  Metadata:", "Unavailable" }
		return rows
	end

	for i, stream in ipairs(metadata.streams or {}) do
		if type(stream) == "table" and stream.codec_type then
			rows[#rows + 1] = ui.Row { string.format("  Stream %d:", i), stream.codec_type }
			if stream.codec_name then
				rows[#rows + 1] = ui.Row { "    Codec:", stream.codec_name }
			end
			if stream.codec_type == "video" then
				if stream.width and stream.height then
					rows[#rows + 1] = ui.Row { "    Size:", string.format("%dx%d", stream.width, stream.height) }
				end
				local fps = frame_rate(stream.avg_frame_rate) or frame_rate(stream.r_frame_rate)
				if fps then
					rows[#rows + 1] = ui.Row { "    Frame rate:", format_fps(fps) }
				end
			end
		end
	end
	return rows
end

local function sort_entries(st, files, reverse)
	local entries = {}
	for index, file in ipairs(files) do
		local snapshot = metadata_snapshot(file)
		entries[#entries + 1] = {
			snapshot = snapshot,
			index = index,
		}
	end

	for _, entry in ipairs(entries) do
		local snapshot = entry.snapshot
		if not snapshot.is_dir and (snapshot.is_video or cached_metadata_snapshot(snapshot)) then
			local metadata = metadata_for_snapshot(snapshot, false)
			entry.duration = metadata and metadata.duration
		end
	end

	table.sort(entries, function(a, b)
		local a_dir, b_dir = a.snapshot.is_dir, b.snapshot.is_dir
		if a_dir ~= b_dir then
			return a_dir
		end

		local a_duration, b_duration = a.duration, b.duration
		if a_duration and b_duration and a_duration ~= b_duration then
			if reverse then
				return a_duration > b_duration
			end
			return a_duration < b_duration
		elseif (a_duration ~= nil) ~= (b_duration ~= nil) then
			return a_duration ~= nil
		end

		local a_name, b_name = a.snapshot.name:lower(), b.snapshot.name:lower()
		if a_name ~= b_name then
			return a_name < b_name
		end
		return a.index < b.index
	end)
	local sorted = {}
	for index, entry in ipairs(entries) do
		sorted[index] = entry.snapshot.key
	end
	return sorted
end

local function cha_snapshot(cha)
	local kind = 0
	if cha.is_hidden then
		kind = kind + 2
	end
	if cha.is_dummy then
		kind = kind + 8
	end
	if cha.is_orphan then
		kind = kind + 1
	end

	return {
		kind = kind,
		mode = cha.mode,
		len = cha.len,
		atime = cha.atime,
		btime = cha.btime,
		ctime = cha.ctime,
		mtime = cha.mtime,
		dev = cha.dev,
		uid = cha.uid,
		gid = cha.gid,
		nlink = cha.nlink,
	}
end

local function file_snapshot(file)
	local url = tostring(file.url)
	return { url = url, cha = cha_snapshot(file.cha) }
end

local function sort_directory(st, cwd_path, hovered_path, reverse)
	if not is_current_directory(cwd_path) then
		return true
	end

	local cwd = Url(cwd_path)
	local files, err = fs.read_dir(cwd, { resolve = false })
	if not files then
		return false, err
	end
	cwd = Url(cwd_path)
	local sorted = sort_entries(st, files, reverse)
	cwd = Url(cwd_path)
	local current_files, err = fs.read_dir(cwd, { resolve = false })
	if not current_files then
		return false, err
	end
	cwd = Url(cwd_path)

	local files_by_url = {}
	local current_order = {}
	for _, file in ipairs(current_files) do
		local snapshot = file_snapshot(file)
		files_by_url[snapshot.url] = snapshot
		current_order[#current_order + 1] = snapshot.url
	end

	local ordered_files, seen = {}, {}
	for _, url in ipairs(sorted) do
		local file = files_by_url[url]
		if file then
			ordered_files[#ordered_files + 1] = {
				url = Url(file.url),
				cha = Cha(file.cha),
			}
			seen[url] = true
		end
	end
	for _, url in ipairs(current_order) do
		if not seen[url] then
			local snapshot = files_by_url[url]
			ordered_files[#ordered_files + 1] = {
				url = Url(snapshot.url),
				cha = Cha(snapshot.cha),
			}
		end
	end

	local id = ya.id("ft")
	ya.emit("sort", { by = "none" })
	ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(cwd_path), files = {} }) })
	ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(cwd_path), files = ordered_files }) })

	local cha = fs.cha(Url(cwd_path), true)
	if not cha then
		return false, Err("Failed to read metadata for '%s'", cwd_path)
	end
	ya.emit(
		"update_files",
		{ op = fs.op("done", { id = id, file = File { url = Url(cwd_path), cha = cha } }) }
	)

	if hovered_path then
		ya.emit("reveal", { Url(hovered_path) })
	end
	return true
end

function M:setup(opts)
	self.cache = self.cache or {}
	opts = opts or {}

	if not self.linemode_id then
		self.linemode_id = Linemode:children_add(function(file_line)
			return video_linemode(self, file_line._file)
		end, opts.order or 1600)
	end
end

function M:fetch(job)
	local snapshots = {}
	for _, file in ipairs(job.files) do
		snapshots[#snapshots + 1] = metadata_snapshot(file)
	end
	for _, snapshot in ipairs(snapshots) do
		metadata_for_snapshot(snapshot, true)
	end
	return require("noop"):fetch(job)
end

function M:spot(job)
	local base = require("file"):spot_base(job)
	local metadata = metadata_for(self, job.file, true)
	local rows = video_rows(metadata)
	rows[#rows + 1] = ui.Row {}

	ya.spot_table(
		job,
		ui.Table(ya.list_merge(rows, base))
			:area(ui.Pos { "center", w = 60, h = 24 })
			:row(1)
			:col(1)
			:col_style(th.spot.tbl_col)
			:cell_style(th.spot.tbl_cell)
			:widths { ui.Constraint.Length(14), ui.Constraint.Fill(1) }
	)
end

function M:entry(job)
	job = type(job) == "string" and { args = { job } } or job
	local mode = job.args[1]
	if mode ~= "duration" and mode ~= "duration-reverse" then
		return ya.notify {
			title = "Video sort",
			content = "Use duration or duration-reverse.",
			level = "error",
			timeout = 5,
		}
	end

	if not begin_sorting() then
		return ya.notify { title = "Video sort", content = "A duration sort is already running.", timeout = 3 }
	end

	local cwd_path, hovered_path = get_context()
	local reverse = mode == "duration-reverse"
	ya.async(function()
		local ok, err = sort_directory(self, cwd_path, hovered_path, reverse)
		set_sorting(false)
		if not ok then
			ya.notify {
				title = "Video sort",
				content = tostring(err),
				level = "error",
				timeout = 5,
			}
		end
	end)
end

return M
