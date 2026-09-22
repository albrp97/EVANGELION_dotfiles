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

local MOVIE_EXTRA_PATTERNS = {
	"behind the scenes",
	"bonus",
	"commemoration",
	"commentary",
	"deleted scene",
	"featurette",
	"interview",
	"making of",
	"most powerful man",
	"old tucson",
	"q&a",
	"screen test",
	"storyboard",
	"tv spot",
	"scrapbook",
	"look of",
	"intimate chat",
	"men who made movies",
	"trailer",
	"where legends",
}

local MOVIE_LOOKUP_DISABLED = os.getenv("YAZI_VIDEO_INFO_OFFLINE") == "1"
local HOME = os.getenv("HOME") or ""
local VIDEO_ROOT = HOME .. "/Videos"
local CACHE_HOME = os.getenv("XDG_CACHE_HOME") or (HOME .. "/.cache")
local PERSISTENT_CACHE_PATH = CACHE_HOME .. "/yazi/video-info/movie-cache.json"

local function is_under_video_root(path)
	if not path then
		return false
	end
	local normalized_path = tostring(path):gsub("^file://", ""):gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)
	local root = VIDEO_ROOT:gsub("/+$", "")
	return normalized_path == root or normalized_path:sub(1, #root + 1) == root .. "/"
end

local function persistent_signature_matches(entry, signature)
	if type(entry) ~= "table" then
		return false
	end
	if tostring(entry.signature or "") == signature then
		return true
	end

	local size, mtime = signature:match("^(%d+):(%d+)")
	return size
		and tonumber(entry.size) == tonumber(size)
		and tonumber(entry.mtime) == tonumber(mtime)
end

local replace_persistent_cache = ya.sync(function(st, entries)
	local indexed = {}
	for key, entry in pairs(entries) do
		indexed[key] = entry
		local normalized_key = tostring(key):gsub("^file://", ""):gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end)
		indexed[normalized_key] = entry
		if type(entry) == "table" and entry.path then
			indexed[tostring(entry.path)] = entry
		end
	end
	st.persistent_entries = indexed
end)

local function load_persistent_cache()
	local output = Command("cat"):arg(PERSISTENT_CACHE_PATH):output()
	local decoded = output and output.status.success and ya.json_decode(output.stdout) or nil
	replace_persistent_cache(
		decoded and type(decoded.entries) == "table" and decoded.entries or {}
	)
end

local function kick_background_indexer()
	if ya.target_os() ~= "linux" then
		return
	end
	ya.async(function()
		local output = Command("systemctl")
			:arg({ "--user", "start", "--no-block", "eva-video-movie-indexer.service" })
			:output()
		if not output or not output.status.success then
			ya.err("Could not start eva-video-movie-indexer.service")
		end
	end)
end

local get_persistent_entry = ya.sync(function(st, path, signature)
	if not path then
		return
	end
	local entry = st.persistent_entries and (
		st.persistent_entries[path]
		or st.persistent_entries[tostring(path):gsub("^file://", ""):gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end)]
	)
	if persistent_signature_matches(entry, signature) then
		return entry
	end
end)

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

local get_preview_skip = ya.sync(function(st, key)
	if st.preview_key ~= key then
		st.preview_key = key
		st.preview_skip = 0
	end
	return st.preview_skip
end)

local move_preview_skip = ya.sync(function(st, key, units)
	if st.preview_key ~= key then
		st.preview_key = key
		st.preview_skip = 0
	end
	st.preview_skip = math.max(0, st.preview_skip + units)
	return st.preview_skip
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
	local mtime = tostring(cha.mtime or 0):match("^(%d+)") or "0"
	return string.format("%s:%s", tostring(cha.len or 0), mtime)
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

local function trim(value)
	if type(value) ~= "string" then
		return nil
	end
	return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function valid_year(value)
	local year = tonumber(value)
	if year and year >= 1800 and year <= 2099 then
		return string.format("%d", year)
	end
end

local function clean_title(value)
	value = trim(value)
	if not value then
		return
	end

	value = value:gsub("%b[]", " ")
	value = value:gsub("%b{}", " ")
	value = value:gsub("[%(%)]+", " ")
	value = value:gsub("%s+", " ")
	value = trim(value)
	if not value then
		return
	end

	if not value:find("%s") and value:find("[._%-]") then
		value = value:gsub("[._%-]+", " ")
	end
	return trim(value)
end

local function movie_title_and_year(value)
	local stem = tostring(value or ""):gsub("%.[^%.]+$", "")
	local year_start, year

	local open, _, parenthesized = stem:find("%((%d%d%d%d)%)")
	if open then
		year_start, year = open, valid_year(parenthesized)
	else
		for position, candidate in stem:gmatch("()(%d%d%d%d)") do
			local before = position > 1 and stem:sub(position - 1, position - 1) or ""
			local after = stem:sub(position + 4, position + 4)
			local possible_year = valid_year(candidate)
			if possible_year and before ~= "x" and after ~= "x" and after:lower() ~= "p" then
				year_start, year = position, possible_year
				break
			end
		end
	end

	local title = year_start and stem:sub(1, year_start - 1) or stem
	if not year_start then
		local lower = title:lower()
		local cut
		for _, token in ipairs({
			" 2160p",
			" 1080p",
			" 720p",
			" 576p",
			" 480p",
			" bluray",
			" web-dl",
			" webrip",
			" x264",
			" x265",
			" hevc",
			" h264",
			" h265",
		}) do
			local position = lower:find(token, 1, true)
			if position and (not cut or position < cut) then
				cut = position
			end
		end
		if cut then
			title = title:sub(1, cut - 1)
		end
	end

	title = clean_title(title)
	return title, year
end

local function is_movie_extra(name, path)
	local lower = tostring(name or ""):lower()
	local normalized_path = tostring(path or ""):lower():gsub("\\", "/")
	for _, directory in ipairs({ "featurettes", "featurette", "extras", "bonus features", "deleted scenes", "special features" }) do
		if normalized_path:find("/" .. directory .. "/", 1, true) then
			return true
		end
	end
	for _, pattern in ipairs(MOVIE_EXTRA_PATTERNS) do
		if lower:find(pattern, 1, true) then
			return true
		end
	end
	return false
end

local function tag_value(tags, wanted)
	if type(tags) ~= "table" then
		return
	end
	for key, value in pairs(tags) do
		if tostring(key):lower() == wanted then
			return tostring(value)
		end
	end
end

local function movie_identity(snapshot, metadata)
	if is_movie_extra(snapshot.name, snapshot.path) then
		return
	end

	local title, year = movie_title_and_year(snapshot.name)
	local tags = metadata and metadata.tags or {}
	local tagged_title = clean_title(tag_value(tags, "title"))
	local tagged_year = tag_value(tags, "year") or tag_value(tags, "date") or tag_value(tags, "creation_time")
	tagged_year = tagged_year and valid_year(tagged_year:match("(%d%d%d%d)")) or nil

	if not title or title:lower() == "source" or title:lower() == "video" then
		title = tagged_title
	end
	year = year or tagged_year

	if not year and snapshot.parent_name then
		local parent_title, parent_year = movie_title_and_year(snapshot.parent_name)
		local normalized = title and title:lower() or ""
		if parent_year and (normalized == "" or normalized == "movie" or normalized == "film" or normalized == "main") then
			title, year = parent_title, parent_year
		end
	end

	if not title or #title < 2 or not year and not tagged_title then
		return
	end

	return {
		title = title,
		year = year,
		key = string.format("%s:%s", title:lower(), year or "unknown"),
	}
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
			"format=duration,format_name:format_tags=title,artist,album,genre,date,year,comment:stream=index,codec_type,codec_name,width,height,channels,channel_layout,avg_frame_rate,r_frame_rate,bit_rate,profile,pix_fmt:stream_tags=title,language",
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
	local audio = {}
	for _, stream in ipairs(streams) do
		if type(stream) == "table" and stream.codec_type == "video" then
			video = stream
		elseif type(stream) == "table" and stream.codec_type == "audio" then
			audio[#audio + 1] = stream
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
		format_name = format.format_name,
		profile = video.profile,
		pix_fmt = video.pix_fmt,
		video_codec = video.codec_name,
		audio = audio,
		tags = type(format.tags) == "table" and format.tags or {},
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
		parent_name = file.url.parent and tostring(file.url.parent.name) or nil,
	}
end

local function metadata_for_snapshot(snapshot, render)
	if snapshot.local_regular and is_under_video_root(snapshot.path) then
		local persistent = get_persistent_entry(snapshot.path, snapshot.signature)
		if persistent then
			put_cached(snapshot.key, snapshot.signature, persistent.metadata, render)
			return persistent.metadata
		end
	end

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

local function audio_layout(stream)
	local layout = trim(stream.channel_layout)
	if layout and layout ~= "" then
		return (layout:gsub("%s*%b()", ""))
	end

	local channels = tonumber(stream.channels)
	local known = {
		[1] = "mono",
		[2] = "stereo",
		[6] = "5.1",
		[8] = "7.1",
	}
	return (channels and known[channels]) or (channels and string.format("%d channels", channels)) or nil
end

local function audio_description(stream)
	local parts = {}
	if stream.codec_name then
		parts[#parts + 1] = stream.codec_name
	end
	local layout = audio_layout(stream)
	if layout then
		parts[#parts + 1] = layout
	end
	local language = trim(stream.tags and tag_value(stream.tags, "language"))
	if language then
		parts[#parts + 1] = language
	end
	local title = trim(stream.tags and tag_value(stream.tags, "title"))
	if title then
		parts[#parts + 1] = title
	end
	return #parts > 0 and table.concat(parts, " / ") or "-"
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
	if snapshot.local_regular and is_under_video_root(snapshot.path) then
		local persistent = get_persistent_entry(snapshot.path, snapshot.signature)
		if persistent then
			return persistent.metadata
		end
	end

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
	return ui.Line { " ", ui.Span(label):style(ui.Style():fg("#B48DDB")) }
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
			elseif stream.codec_type == "audio" then
				rows[#rows + 1] = ui.Row { "    Layout:", audio_layout(stream) or "-" }
				local language = stream.tags and tag_value(stream.tags, "language")
				if language then
					rows[#rows + 1] = ui.Row { "    Language:", language }
				end
			end
		end
	end
	return rows
end

local function add_heading(lines, text)
	lines[#lines + 1] = ui.Line { ui.Span(text):fg("green"):bold() }
end

local DETAIL_LABEL_WIDTH = 18
local DETAIL_VALUE_WIDTH = 56

local function wrapped_value(value)
	local wrapped = {}
	for paragraph in tostring(value):gmatch("[^\n]+") do
		local line = ""
		for word in paragraph:gmatch("%S+") do
			if line == "" then
				line = word
			elseif #line + #word + 1 <= DETAIL_VALUE_WIDTH then
				line = line .. " " .. word
			else
				wrapped[#wrapped + 1] = line
				line = word
			end
		end
		if line ~= "" then
			wrapped[#wrapped + 1] = line
		end
	end
	return #wrapped > 0 and wrapped or { "" }
end

local function add_detail(lines, label, value)
	if value == nil or value == "" then
		return
	end
	local values = wrapped_value(value)
	for index, line in ipairs(values) do
		local prefix = index == 1 and (label .. ":") or ""
		lines[#lines + 1] = ui.Line {
			ui.Span(string.format("%-" .. DETAIL_LABEL_WIDTH .. "s", prefix)):fg("#B48DDB"),
			ui.Span(line),
		}
	end
end

local function movie_display_value(field, value)
	if value == nil then
		return
	end

	local text = tostring(value)
	if field == "runtime" then
		return text:match("^%s*(%d+%.?%d*%s*min)") or text
	end

	text = text:gsub("!%[[^%]]*%]%([^%)]*%)", "")
	text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
	text = text:gsub("%f[%w]Q%d+%f[%W]", "")
	text = text:gsub("%s+", " ")
	text = text:gsub("%s*,%s*", ", ")
	text = text:gsub("^%s*[,|]+%s*", ""):gsub("%s*[,|]+%s*$", "")
	text = text:gsub(",%s*,+", ",")
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	return text ~= "" and text or nil
end

local function add_movie_detail(lines, label, movie, field)
	add_detail(lines, label, movie_display_value(field, movie[field]))
end

local function add_movie_section(lines, identity, movie_state)
	if not identity then
		return
	end

	add_heading(lines, "MOVIE")
	if not movie_state or movie_state.status == "loading" or movie_state.status == "indexing" then
		add_detail(lines, "Matched title", identity.title .. (identity.year and (" (" .. identity.year .. ")") or ""))
		add_detail(lines, "Lookup", "Indexing in background...")
	elseif movie_state.status == "offline" then
		add_detail(lines, "Matched title", identity.title .. (identity.year and (" (" .. identity.year .. ")") or ""))
		add_detail(lines, "Lookup", "Offline mode enabled")
	elseif movie_state.status == "unavailable" then
		add_detail(lines, "Matched title", identity.title .. (identity.year and (" (" .. identity.year .. ")") or ""))
		add_detail(lines, "Lookup", "No online match found")
	elseif movie_state.status == "ready" then
		local movie = movie_state.movie
		add_movie_detail(lines, "Title", movie, "title")
		add_detail(lines, "FilmAffinity", movie.score and (movie.score .. "/10") or "-")
		add_movie_detail(lines, "Year of release", movie, "year")
		add_movie_detail(lines, "Director", movie, "director")
		if movie.original_title and movie.original_title ~= movie.title then
			add_movie_detail(lines, "Original title", movie, "original_title")
		end
		add_movie_detail(lines, "Runtime", movie, "runtime")
		add_movie_detail(lines, "Genre", movie, "genre")
		add_movie_detail(lines, "Cast", movie, "cast")
		add_movie_detail(lines, "Composer / Music", movie, "composer")
		add_movie_detail(lines, "Cinematography", movie, "cinematography")
		add_movie_detail(lines, "Writer", movie, "writer")
		add_movie_detail(lines, "Producer", movie, "producer")
		add_movie_detail(lines, "Country", movie, "country")
		add_movie_detail(lines, "Source", movie, "source")
		if movie.synopsis and movie.synopsis ~= "" then
			lines[#lines + 1] = ui.Line {}
			add_movie_detail(lines, "Synopsis", movie, "synopsis")
		end
	end
end

local function add_video_section(lines, snapshot, metadata, image_error)
	add_heading(lines, "VIDEO")
	add_detail(lines, "File", snapshot.name)
	add_detail(
		lines,
		"Resolution",
		metadata and metadata.width and metadata.height and string.format("%dx%d", metadata.width, metadata.height) or "-"
	)
	add_detail(lines, "Frame rate", metadata and format_fps(metadata.fps) or "-")
	add_detail(lines, "Duration", metadata and format_duration(metadata.duration) or "-")
	add_detail(lines, "Video codec", metadata and metadata.video_codec or "-")
	add_detail(lines, "Profile", metadata and metadata.profile or nil)
	add_detail(lines, "Pixel format", metadata and metadata.pix_fmt or nil)
	add_detail(lines, "Container", metadata and metadata.format_name or nil)

	if image_error then
		add_detail(lines, "Preview", tostring(image_error))
	end
end

local function add_audio_section(lines, metadata)
	local audio = metadata and metadata.audio or {}
	if #audio == 0 then
		return
	end

	lines[#lines + 1] = ui.Line {}
	add_heading(lines, "AUDIO")
	for index, stream in ipairs(audio) do
		add_detail(lines, string.format("Track %d", index), audio_description(stream))
	end
end

local function preview_text(snapshot, metadata, identity, movie_state, image_error)
	local lines = {}
	if identity then
		add_movie_section(lines, identity, movie_state)
		lines[#lines + 1] = ui.Line {}
	end
	add_video_section(lines, snapshot, metadata, image_error)
	add_audio_section(lines, metadata)
	return ui.Text(lines)
end

local function movie_preview_state(st, snapshot, metadata)
	if not is_under_video_root(snapshot.path) then
		return
	end

	local persistent = get_persistent_entry(snapshot.path, snapshot.signature)
	if persistent and persistent.movie_status == "not_movie" then
		return
	end
	local identity = persistent and persistent.identity or movie_identity(snapshot, metadata)
	if not identity then
		return
	end

	if not persistent then
		if MOVIE_LOOKUP_DISABLED then
			return identity, { status = "offline" }
		end
		return identity, { status = "indexing" }
	end

	if persistent.movie_status == "ready" and type(persistent.movie) == "table" then
		return identity, { status = "ready", movie = persistent.movie }
	elseif persistent.movie_status == "offline" then
		return identity, { status = "offline" }
	elseif persistent.movie_status == "unavailable" then
		return identity, { status = "unavailable" }
	end

	return identity, { status = "indexing" }
end

local function preview_areas(area, metadata)
	if area.h < 2 then
		return area
	end

	local minimum_details_height
	if area.h <= 12 then
		minimum_details_height = math.max(3, math.floor(area.h / 2))
	else
		minimum_details_height = 7
	end

	local details_height = math.min(
		math.min(18, math.max(minimum_details_height, math.floor(area.h * 0.4))),
		math.max(1, area.h - 1)
	)
	local width = tonumber(metadata and metadata.width)
	local height = tonumber(metadata and metadata.height)
	if width and height and width > 0 and height > 0 then
		-- Terminal cells are normally about twice as tall as they are wide.
		local image_height = math.floor(area.w * height / width * 0.5)
		image_height = math.min(math.max(1, image_height), math.max(1, area.h - minimum_details_height))
		details_height = area.h - image_height
	end

	local areas = ui.Layout()
		:direction(ui.Layout.VERTICAL)
		:constraints { ui.Constraint.Fill(1), ui.Constraint.Length(details_height) }
		:split(area)
	return areas[1], areas[2]
end

local function preview_video_frame(job, image_area)
	local frame_job = {
		args = job.args,
		file = job.file,
		mime = job.mime,
		sig = job.sig,
		skip = 0,
	}
	local cache = ya.file_cache(frame_job)
	if not cache then
		return nil
	end

	local start = os.clock()
	local native_video = require("video")
	local ok, err = native_video:preload(frame_job)
	if not ok or err then
		return err
	end

	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
	local _, image_error = ya.image_show(cache, image_area)
	return image_error
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
	self.persistent_entries = self.persistent_entries or {}
	kick_background_indexer()
	opts = opts or {}

	if not self.linemode_id then
		self.linemode_id = Linemode:children_add(function(file_line)
			return video_linemode(self, file_line._file)
		end, opts.order or 1600)
	end
end

function M:peek(job)
	if job.area.w == 0 or job.area.h == 0 then
		return
	end

	load_persistent_cache()
	local snapshot = metadata_snapshot(job.file)
	local metadata = metadata_for_snapshot(snapshot, true)
	local identity, movie_state = movie_preview_state(self, snapshot, metadata)
	local image_area, details_area = preview_areas(job.area, metadata)
	local image_error = details_area and preview_video_frame(job, image_area) or nil
	local details_skip = get_preview_skip(snapshot.key)
	local details_job = {
		area = job.area,
		file = job.file,
		mime = job.mime,
		sig = job.sig,
		skip = details_skip,
	}

	local text = preview_text(snapshot, metadata, identity, movie_state, image_error)
	ya.preview_widget(details_job, text:area(details_area or job.area):wrap(ui.Wrap.YES):scroll(0, details_skip))
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	move_preview_skip(tostring(job.file.url), job.units or 0)
	ya.emit("peek", {
		math.max(0, cx.active.preview.skip + (job.units or 0)),
		only_if = job.file.url,
	})
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
