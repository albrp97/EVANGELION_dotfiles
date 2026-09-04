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
	"trailer",
	"where legends",
}

local MOVIE_LOOKUP_DISABLED = os.getenv("YAZI_VIDEO_INFO_OFFLINE") == "1"
local MOVIE_LOOKUP_STALE_AFTER = 15
local WIKIDATA_API = "https://www.wikidata.org/w/api.php"
local FILMAFFINITY_URL = "https://r.jina.ai/http://www.filmaffinity.com/en/film%s.html"

local get_cached = ya.sync(function(st, key)
	return st.cache[key]
end)

local get_movie_cached = ya.sync(function(st, key)
	return st.movies[key]
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

local begin_movie_lookup = ya.sync(function(st, key)
	local cached = st.movies[key]
	if cached and cached.status ~= "loading" then
		return false
	end
	if cached and cached.started_at and os.time() - cached.started_at < MOVIE_LOOKUP_STALE_AFTER then
		return false
	end
	st.movies[key] = { status = "loading", started_at = os.time() }
	return true
end)

local put_movie_cached = ya.sync(function(st, key, value)
	st.movies[key] = value
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

local function is_movie_extra(name)
	local lower = tostring(name or ""):lower()
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
	if is_movie_extra(snapshot.name) then
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

local function curl(url, query)
	local args = {
		"-fsSL",
		"--connect-timeout",
		"3",
		"--max-time",
		"8",
		"--user-agent",
		"yazi-video-info/1.0",
	}

	if query then
		args[#args + 1] = "--get"
		args[#args + 1] = url
		for key, value in pairs(query) do
			args[#args + 1] = "--data-urlencode"
			args[#args + 1] = string.format("%s=%s", key, tostring(value))
		end
	else
		args[#args + 1] = url
	end

	local output = Command("curl"):arg(args):output()
	if not output or not output.status.success then
		return
	end
	return output.stdout
end

local function curl_json(url, query)
	local output = curl(url, query)
	if not output then
		return
	end
	local decoded = ya.json_decode(output)
	return type(decoded) == "table" and decoded or nil
end

local function normalized_title(value)
	return tostring(value or ""):lower():gsub("[^%w]+", "")
end

local function claim_values(claims, property, limit)
	local values = {}
	for _, statement in ipairs(claims[property] or {}) do
		if statement.rank ~= "deprecated" then
			local snak = statement.mainsnak
			local datavalue = snak and snak.datavalue
			local value = datavalue and datavalue.value
			local result
			if type(value) == "table" then
				result = value.id or value.text or value.amount
			elseif value ~= nil then
				result = tostring(value)
			end
			if result and result ~= "" then
				values[#values + 1] = tostring(result)
				if limit and #values >= limit then
					break
				end
			end
		end
	end
	return values
end

local function first_claim_value(claims, property)
	return claim_values(claims, property, 1)[1]
end

local function entity_labels(ids)
	if #ids == 0 then
		return {}
	end

	local data = curl_json(WIKIDATA_API, {
		action = "wbgetentities",
		ids = table.concat(ids, "|"),
		props = "labels",
		languages = "en",
		languagefallback = "1",
		format = "json",
	})
	if not data or type(data.entities) ~= "table" then
		return {}
	end

	local labels = {}
	for _, id in ipairs(ids) do
		local entity = data.entities[id]
		local label = entity and entity.labels and entity.labels.en and entity.labels.en.value
		if label then
			labels[id] = label
		end
	end
	return labels
end

local function join_claim_labels(ids, labels)
	local values = {}
	local seen = {}
	for _, id in ipairs(ids) do
		local label = labels[id]
		if label and not seen[label] then
			seen[label] = true
			values[#values + 1] = label
		end
	end
	return #values > 0 and table.concat(values, ", ") or nil
end

local function search_wikidata_movie(identity)
	local data = curl_json(WIKIDATA_API, {
		action = "wbsearchentities",
		search = identity.title,
		language = "en",
		format = "json",
		limit = "10",
		type = "item",
	})
	if not data or type(data.search) ~= "table" then
		return
	end

	local best, best_score = nil, -1
	for _, result in ipairs(data.search) do
		local label = tostring(result.label or "")
		local description = tostring(result.description or "")
		local lower_description = description:lower()
		local score = 0

		if lower_description:find("film", 1, true) or lower_description:find("movie", 1, true) then
			score = score + 4
		end
		if identity.year and description:find(identity.year, 1, true) then
			score = score + 5
		end
		if normalized_title(label) == normalized_title(identity.title) then
			score = score + 3
		end

		if score > best_score then
			best, best_score = result, score
		end
	end

	if best and best_score >= 4 then
		return best.id
	end
end

local function lookup_wikidata_movie(identity)
	local qid = search_wikidata_movie(identity)
	if not qid then
		return
	end

	local data = curl_json(WIKIDATA_API, {
		action = "wbgetentities",
		ids = qid,
		props = "claims|labels",
		languages = "en",
		languagefallback = "1",
		format = "json",
	})
	local entity = data and data.entities and data.entities[qid]
	if not entity then
		return
	end

	local claims = entity.claims or {}
	local role_specs = {
		director = { property = "P57", limit = 4 },
		genre = { property = "P136", limit = 8 },
		cast = { property = "P161", limit = 12 },
		composer = { property = "P86", limit = 5 },
		cinematography = { property = "P344", limit = 5 },
		writer = { property = "P58", limit = 5 },
		producer = { property = "P162", limit = 5 },
		country = { property = "P495", limit = 5 },
	}
	local roles, all_ids, seen_ids = {}, {}, {}
	for role, spec in pairs(role_specs) do
		roles[role] = claim_values(claims, spec.property, spec.limit)
		for _, id in ipairs(roles[role]) do
			if not seen_ids[id] then
				seen_ids[id] = true
				all_ids[#all_ids + 1] = id
			end
		end
	end

	local labels = entity_labels(all_ids)
	local title = entity.labels and entity.labels.en and entity.labels.en.value or identity.title
	local release_time = first_claim_value(claims, "P577")
	local release_year = release_time and release_time:match("(%d%d%d%d)") or nil
	local original_title = first_claim_value(claims, "P1476")
	local runtime = first_claim_value(claims, "P2047")

	return {
		title = title,
		original_title = original_title,
		year = release_year or identity.year,
		runtime = runtime and string.format("%d min", math.floor(tonumber(runtime) or 0)) or nil,
		director = join_claim_labels(roles.director, labels),
		genre = join_claim_labels(roles.genre, labels),
		cast = join_claim_labels(roles.cast, labels),
		composer = join_claim_labels(roles.composer, labels),
		cinematography = join_claim_labels(roles.cinematography, labels),
		writer = join_claim_labels(roles.writer, labels),
		producer = join_claim_labels(roles.producer, labels),
		country = join_claim_labels(roles.country, labels),
		film_affinity_id = first_claim_value(claims, "P480"),
		imdb_id = first_claim_value(claims, "P345"),
		wikidata_id = qid,
	}
end

local function markdown_names(section)
	if not section then
		return
	end

	section = section:gsub("!%[[^%]]*%]%([^%)]+%)", "")
	local names, seen = {}, {}
	for raw_name in section:gmatch("%[([^%]]+)%]%([^%)]+%)") do
		local name = trim(raw_name)
		if name and name ~= "" and not seen[name] then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	return #names > 0 and table.concat(names, ", ") or nil
end

local function section_between(text, start_marker, end_marker)
	local start = text:find(start_marker, 1, true)
	if not start then
		return
	end
	start = start + #start_marker
	local finish = end_marker and text:find(end_marker, start, true) or nil
	return text:sub(start, finish and finish - 1 or #text)
end

local function parse_film_affinity(text, movie)
	if not text or not text:find("Original title", 1, true) then
		return
	end

	local credits_start = text:find("Original title", 1, true) or 1
	local credits = text:sub(credits_start)
	local genre_section = section_between(credits, "Genre", "Synopsis")
	local writer_section = section_between(credits, "Screenwriter", "Cast")

	local parsed = {
		title = text:match("\n#%s*(.-)%s*\n") or movie.title,
		original_title = credits:match("Original title%s+(.-)%s+Year") or nil,
		year = credits:match("Year%s+(%d%d%d%d)") or nil,
		runtime = credits:match("Running time%s+(%d+)%s+min") and (credits:match("Running time%s+(%d+)%s+min") .. " min") or nil,
		score = text:match("Rating[^\n]*\n%s*([%d%.]+)"),
		director = markdown_names(section_between(credits, "Director", "Screenwriter")),
		writer = markdown_names(writer_section),
		cast = markdown_names(section_between(credits, "Cast", "See all credits")),
		composer = markdown_names(section_between(credits, "Music", "Cinematography")),
		cinematography = markdown_names(section_between(credits, "Cinematography", "Producer")),
		producer = markdown_names(section_between(credits, "Producer", "Genre")),
		genre = markdown_names(genre_section),
		synopsis = credits:match("Synopsis%s+(.-)%s+About similar"),
	}

	for key, value in pairs(parsed) do
		if type(value) == "string" then
			parsed[key] = trim(value)
		end
	end
	return parsed
end

local function lookup_film_affinity(movie)
	if not movie.film_affinity_id then
		return
	end

	for _, suffix in ipairs({ "?lang=en", "?output=1" }) do
		local page = curl(string.format(FILMAFFINITY_URL, movie.film_affinity_id) .. suffix)
		local parsed = parse_film_affinity(page, movie)
		if parsed then
			parsed.url = string.format(
				"https://www.filmaffinity.com/en/film%s.html?lang=en",
				movie.film_affinity_id
			)
			return parsed
		end
	end
end

local function lookup_movie(identity)
	local movie = lookup_wikidata_movie(identity)
	if not movie then
		return
	end

	local film_affinity = lookup_film_affinity(movie)
	if film_affinity then
		for key, value in pairs(film_affinity) do
			if value and value ~= "" then
				movie[key] = value
			end
		end
		movie.source = "FilmAffinity + Wikidata"
	else
		movie.source = "Wikidata"
	end
	return movie
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

local function add_detail(lines, label, value)
	if value == nil or value == "" then
		return
	end
	lines[#lines + 1] = ui.Line {
		ui.Span(string.format("%-15s", label .. ":")):fg("#D98BC4"),
		ui.Span(tostring(value)),
	}
end

local function preview_text(snapshot, metadata, identity, movie_state, image_error)
	local lines = {}
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

	local audio = metadata and metadata.audio or {}
	if #audio > 0 then
		lines[#lines + 1] = ui.Line {}
		add_heading(lines, "AUDIO")
		for index, stream in ipairs(audio) do
			add_detail(lines, string.format("Track %d", index), audio_description(stream))
		end
	end

	if not identity then
		return ui.Text(lines)
	end

	lines[#lines + 1] = ui.Line {}
	add_heading(lines, "MOVIE")
	add_detail(lines, "Matched title", identity.title .. (identity.year and (" (" .. identity.year .. ")") or ""))

	if not movie_state or movie_state.status == "loading" then
		add_detail(lines, "Lookup", "Searching Wikidata and FilmAffinity...")
	elseif movie_state.status == "offline" then
		add_detail(lines, "Lookup", "Offline mode enabled")
	elseif movie_state.status == "unavailable" then
		add_detail(lines, "Lookup", "No online match found")
	elseif movie_state.status == "ready" then
		local movie = movie_state.movie
		add_detail(lines, "Title", movie.title)
		add_detail(lines, "Original title", movie.original_title)
		add_detail(lines, "Year", movie.year)
		add_detail(lines, "FilmAffinity", movie.score and (movie.score .. "/10") or nil)
		add_detail(lines, "Runtime", movie.runtime)
		add_detail(lines, "Director", movie.director)
		add_detail(lines, "Genre", movie.genre)
		add_detail(lines, "Cast", movie.cast)
		add_detail(lines, "Composer / Music", movie.composer)
		add_detail(lines, "Cinematography", movie.cinematography)
		add_detail(lines, "Writer", movie.writer)
		add_detail(lines, "Producer", movie.producer)
		add_detail(lines, "Country", movie.country)
		add_detail(lines, "Source", movie.source)
		if movie.synopsis then
			lines[#lines + 1] = ui.Line {}
			add_detail(lines, "Synopsis", movie.synopsis)
		end
	end

	return ui.Text(lines)
end

local function movie_preview_state(st, snapshot, metadata)
	local identity = movie_identity(snapshot, metadata)
	if not identity then
		return
	end
	if MOVIE_LOOKUP_DISABLED then
		return identity, { status = "offline" }
	end

	local cached = get_movie_cached(identity.key)
	if cached then
		return identity, cached
	end

	return identity, { status = "loading" }, begin_movie_lookup(identity.key)
end

local function preview_areas(area)
	if area.h < 2 then
		return area
	end

	local details_height
	if area.h <= 12 then
		details_height = math.max(3, math.floor(area.h / 2))
	else
		details_height = math.min(18, math.max(7, math.floor(area.h * 0.4)))
	end
	details_height = math.min(details_height, math.max(1, area.h - 1))

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
	self.movies = self.movies or {}
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

	local snapshot = metadata_snapshot(job.file)
	local metadata = metadata_for_snapshot(snapshot, true)
	local identity, movie_state, lookup = movie_preview_state(self, snapshot, metadata)
	local image_area, details_area = preview_areas(job.area)
	local image_error = details_area and preview_video_frame(job, image_area) or nil
	local details_skip = get_preview_skip(snapshot.key)
	local details_job = {
		area = job.area,
		file = job.file,
		mime = job.mime,
		sig = job.sig,
		skip = details_skip,
	}

	if lookup then
		local movie = lookup_movie(identity)
		movie_state = movie and { status = "ready", movie = movie } or { status = "unavailable" }
		put_movie_cached(identity.key, movie_state)
	end

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
