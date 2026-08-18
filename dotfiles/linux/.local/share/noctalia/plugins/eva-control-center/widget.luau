--!nonstrict

local kind = noctalia.getConfig("metric") or "cpu"
local CLOSE_GRACE_MS = 350
local UPDATE_INTERVAL_MS = 500

local PANEL_TARGETS = {
  power = {
    panel = "session",
    color = "#C4A7E7",
    glyph = "power",
  },
  clock = {
    panel = "control-center",
    context = "calendar",
    color = "#C4A7E7",
    glyph = "calendar",
  },
  cpu = {
    panel = "control-center",
    context = "system",
    color = "#C4A7E7",
    glyph = "cpu",
  },
  ram = {
    panel = "control-center",
    context = "system",
    color = "#C4A7E7",
    glyph = "server",
  },
  gpu = {
    panel = "control-center",
    context = "system",
    color = "#C4A7E7",
    glyph = "cpu-2",
  },
  download = {
    panel = "control-center",
    context = "network",
    color = "#C4A7E7",
    glyph = "download-speed",
  },
  upload = {
    panel = "control-center",
    context = "network",
    color = "#C4A7E7",
    glyph = "upload-speed",
  },
  workspace = {
    panel = "control-center",
    context = "home",
    color = "#C4A7E7",
  },
  media = {
    panel = "control-center",
    context = "media",
    color = "#C4A7E7",
    glyph = "music",
  },
  volume = {
    panel = "control-center",
    context = "audio",
    color = "#C4A7E7",
    glyph = "volume-high",
  },
  weather = {
    panel = "control-center",
    context = "weather",
    color = "#C4A7E7",
    glyph = "weather-cloud",
  },
  notifications = {
    panel = "control-center",
    context = "notifications",
    color = "#C4A7E7",
    glyph = "bell",
  },
}

local PROFILE_ORDER = { "performance", "balanced", "power-saver" }
local PROFILE_STYLES = {
  ["power-saver"] = {
    label = "SAVE",
    color = "#A3D977",
    glyph = "leaf",
  },
  balanced = {
    label = "BAL",
    color = "#C4A7E7",
    glyph = "scale",
  },
  performance = {
    label = "PERF",
    color = "#F6C177",
    glyph = "cpu",
  },
}
local DEFAULT_PROFILE_STYLE = {
  label = "--",
  color = "#C4A7E7",
  glyph = "cpu",
}

local target = PANEL_TARGETS[kind] or PANEL_TARGETS.cpu
local CLOSE_PROBE = [[
cursor="$(hyprctl cursorpos -j 2>/dev/null)"
hyprctl layers -j 2>/dev/null | jq -c --argjson cursor "$cursor" '
  [.. | objects
    | select(.namespace == "noctalia-attached-panel" or .namespace == "noctalia-panel")
    | select(
        $cursor.x >= .x
        and $cursor.x < (.x + .w)
        and $cursor.y >= .y
        and $cursor.y < (.y + .h)
      )
  ] | length > 0
'
]]

local hovering = false
local panelRequested = false
local closeDeadline = nil
local panelProbePending = false
local stats = nil
local workspaceIds = { 1, 2, 3 }
local activeWorkspace = 1
local workspaceRequestPending = false
local commandPending = false
local volumePercent = nil
local volumeMuted = false
local mediaAvailable = false
local mediaTitle = ""
local weatherTemperature = nil
local weatherGlyph = "weather-cloud"
local hasUnreadNotifications = false
local powerProfile = nil
local profileSamplePending = false
local profileChangePending = false

local function requestCommand(command, callback)
  if commandPending then
    return
  end

  commandPending = noctalia.runAsync(command, function(result)
    commandPending = false
    callback(result)
  end)
end

local function samplePowerProfile()
  if profileSamplePending or profileChangePending then
    return
  end

  profileSamplePending = noctalia.runAsync("powerprofilesctl get 2>/dev/null", function(result)
    profileSamplePending = false
    if result.exitCode ~= 0 then
      return
    end

    local profile = (result.stdout or ""):match("([%w%-]+)")
    if PROFILE_STYLES[profile] ~= nil then
      powerProfile = profile
    end
  end)
end

local function cyclePowerProfile()
  if profileChangePending then
    return
  end

  local currentIndex = 0
  for index, profile in ipairs(PROFILE_ORDER) do
    if profile == powerProfile then
      currentIndex = index
      break
    end
  end

  local nextProfile = PROFILE_ORDER[(currentIndex % #PROFILE_ORDER) + 1]
  profileChangePending = noctalia.runAsync("powerprofilesctl set " .. nextProfile, function(result)
    profileChangePending = false
    if result.exitCode == 0 then
      powerProfile = nextProfile
    end
  end)
end

local function openPanel()
  local command = "$HOME/.local/bin/eva-vclick-current"
  if target.context ~= nil then
    command = command
      .. "; sleep 0.20; noctalia msg panel-open "
      .. target.panel
      .. " "
      .. target.context
  end
  noctalia.runAsync(command)
  panelRequested = true
end

local function closePanel()
  noctalia.runAsync("noctalia msg panel-close " .. target.panel)
  panelRequested = false
  closeDeadline = nil
end

local function clampPercent(value)
  if value == nil then
    return nil
  end
  return math.max(0, math.min(100, value))
end

local function handleHover(state)
  hovering = state == true or state == "true"

  if hovering then
    closeDeadline = nil
    if not panelRequested then
      openPanel()
    end
    return
  end

  if panelRequested then
    closeDeadline = noctalia.nowMs() + CLOSE_GRACE_MS
  end
end

local function formatPercent(value)
  local percent = clampPercent(value)
  if percent == nil then
    return "--"
  end
  return string.format("%.0f%%", percent)
end

local function formatRate(value)
  if value == nil then
    return "--"
  end
  if value >= 1024 * 1024 then
    return string.format("%.1fM/s", value / (1024 * 1024))
  end
  if value >= 1024 then
    return string.format("%.0fK/s", value / 1024)
  end
  return string.format("%.0fB/s", value)
end

local function metric(group, key)
  if stats == nil or stats[group] == nil then
    return nil
  end
  return stats[group][key]
end

local ENGLISH_MONTHS = {
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
}

local function clockText()
  local now = os.date("*t")
  return string.format("%02d:%02d", now.hour, now.min),
    string.format("%d %s", now.day, ENGLISH_MONTHS[now.month])
end

local function renderMetric()
  local color = target.color
  if kind == "power" then
    barWidget.render(ui.row(
      {
        gap = 4,
        align = "center",
        onHover = handleHover,
      },
      {
        ui.glyph({ name = target.glyph, size = 16, color = color }),
      }
    ))
    return
  end

  if kind == "clock" then
    local timeText, dateText = clockText()
    barWidget.render(ui.row(
      {
        gap = 8,
        align = "center",
        onHover = handleHover,
      },
      {
        ui.label({ text = timeText, color = color, fontSize = 11, fontWeight = "bold" }),
        ui.label({ text = dateText, color = color, fontSize = 11, fontWeight = "bold" }),
      }
    ))
    return
  end

  local value = "--"
  if kind == "cpu" then
    value = formatPercent(metric("cpu", "usagePercent"))
  elseif kind == "ram" then
    value = formatPercent(metric("ram", "usagePercent"))
  elseif kind == "gpu" then
    value = formatPercent(metric("gpu", "usagePercent"))
  elseif kind == "download" then
    value = formatRate(metric("net", "rxBytesPerSec"))
  elseif kind == "upload" then
    value = formatRate(metric("net", "txBytesPerSec"))
  end

  barWidget.render(ui.row(
    {
      gap = 4,
      align = "center",
      onHover = handleHover,
    },
    {
      ui.glyph({ name = target.glyph, size = 14, color = color }),
      ui.label({ text = value, color = color, fontSize = 11, fontWeight = "bold" }),
    }
  ))
end

local function renderWorkspaces()
  local dots = {}
  for _, id in ipairs(workspaceIds) do
    local active = id == activeWorkspace
    table.insert(dots, ui.box({
      key = "workspace-" .. tostring(id),
      width = 10,
      height = 10,
      fill = active and "#A3D977" or "#C4A7E7",
      radius = 99,
    }))
  end

  barWidget.render(ui.row(
    {
      gap = 14,
      align = "center",
      paddingH = 2,
      onHover = handleHover,
    },
    dots
  ))
end

local function weatherGlyphForCode(code, isDay)
  if code == nil then
    return "weather-cloud"
  end
  if code == 0 then
    return isDay and "weather-sun" or "weather-moon"
  end
  if code == 1 or code == 2 then
    return isDay and "weather-cloud-sun" or "weather-moon-stars"
  end
  if code == 3 then
    return "weather-cloud"
  end
  if code == 45 or code == 48 then
    return "weather-cloud-haze"
  end
  if (code >= 51 and code <= 67) or (code >= 80 and code <= 82) then
    return "weather-cloud-rain"
  end
  if (code >= 71 and code <= 77) or code == 85 or code == 86 then
    return "weather-cloud-snow"
  end
  if code >= 95 then
    return "weather-cloud-lightning"
  end
  return "weather-cloud"
end

local function renderExternal()
  if kind == "media" then
    if not mediaAvailable then
      barWidget.render(ui.row({ visible = false, width = 0, height = 0 }, {}))
      return
    end
    barWidget.render(ui.row(
      {
        gap = 4,
        align = "center",
        onHover = handleHover,
      },
      {
        ui.glyph({ name = target.glyph, size = 15, color = target.color }),
        ui.label({ text = mediaTitle, color = target.color, fontSize = 11, fontWeight = "bold" }),
      }
    ))
    return
  end

  if kind == "volume" then
    local glyph = volumeMuted and "volume-mute" or target.glyph
    local value = volumePercent == nil and "--" or string.format("%.0f%%", volumePercent)
    barWidget.render(ui.row(
      {
        gap = 4,
        align = "center",
        onHover = handleHover,
      },
      {
        ui.glyph({ name = glyph, size = 15, color = target.color }),
        ui.label({ text = value, color = target.color, fontSize = 11, fontWeight = "bold" }),
      }
    ))
    return
  end

  if kind == "weather" then
    local value = weatherTemperature == nil and "--" or string.format("%.0f°C", weatherTemperature)
    barWidget.render(ui.row(
      {
        gap = 4,
        align = "center",
        onHover = handleHover,
      },
      {
        ui.glyph({ name = weatherGlyph, size = 15, color = target.color }),
        ui.label({ text = value, color = target.color, fontSize = 11, fontWeight = "bold" }),
      }
    ))
    return
  end

  local color = target.color
  if kind == "notifications" and hasUnreadNotifications then
    color = "#F6C177"
  end

  barWidget.render(ui.row(
    {
      gap = 4,
      align = "center",
      onHover = handleHover,
    },
    {
      ui.glyph({ name = target.glyph, size = 15, color = color }),
    }
  ))
end

local function renderPowerProfile()
  local style = PROFILE_STYLES[powerProfile] or DEFAULT_PROFILE_STYLE
  barWidget.render(ui.row(
    {
      gap = 4,
      align = "center",
      onClick = cyclePowerProfile,
    },
    {
      ui.glyph({ name = style.glyph, size = 15, color = style.color }),
      ui.label({ text = style.label, color = style.color, fontSize = 11, fontWeight = "bold" }),
    }
  ))
end

local function render()
  if kind == "power-profile" then
    renderPowerProfile()
  elseif kind == "workspace" then
    renderWorkspaces()
  elseif kind == "media" or kind == "volume" or kind == "weather" or kind == "notifications" then
    renderExternal()
  else
    renderMetric()
  end
end

local function sample()
  local current = noctalia.systemStats()
  if current ~= nil then
    stats = current
  end
end

local function sampleExternal()
  if kind == "volume" then
    requestCommand("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null", function(result)
      if result.exitCode ~= 0 then
        return
      end
      local raw = result.stdout or ""
      local value = tonumber(raw:match("Volume:%s*([%d.]+)"))
      if value ~= nil then
        volumePercent = value * 100
      end
      volumeMuted = raw:match("%[MUTED%]") ~= nil
    end)
  elseif kind == "media" then
    requestCommand(
      [[
player="$(busctl --user call dev.noctalia.Mpris /dev/noctalia/Mpris dev.noctalia.Mpris GetActivePlayer 2>/dev/null)"
if printf '%s\n' "$player" | grep -q '^ba{sv} true '; then
  title="$(printf '%s\n' "$player" | sed -n 's/.*"title" s "\(.*\)" "track_id".*/\1/p')"
  if [ -z "$title" ]; then
    title="$(printf '%s\n' "$player" | sed -n 's/.*"identity" s "\(.*\)" "length_us".*/\1/p')"
  fi
  if [ -n "$title" ]; then
    printf 'present\t%s\n' "$title"
    exit 0
  fi
fi
]],
      function(result)
        if result.exitCode ~= 0 then
          return
        end
        local title = (result.stdout or ""):match("^present\t(.+)%s*$")
        mediaAvailable = title ~= nil and title ~= ""
        mediaTitle = title or ""
      end
    )
  elseif kind == "weather" then
    requestCommand(
      [[jq -r '.snapshot.current // empty | "\(.temperature_c)\t\(.weather_code)\t\(.is_day)"' "$HOME/.cache/noctalia/weather.json" 2>/dev/null]],
      function(result)
        if result.exitCode ~= 0 then
          return
        end
        local temperature, code, isDay = (result.stdout or ""):match("([%d.-]+)\t([%d.-]+)\t(%w+)")
        if temperature == nil or code == nil then
          return
        end
        weatherTemperature = tonumber(temperature)
        weatherGlyph = weatherGlyphForCode(tonumber(code), isDay == "true")
      end
    )
  elseif kind == "notifications" then
    requestCommand(
      [[jq -r '[.entries[]? | select(.seen == false)] | length' "$HOME/.local/state/noctalia/notification_history.json" 2>/dev/null]],
      function(result)
        if result.exitCode ~= 0 then
          return
        end
        local count = tonumber((result.stdout or ""):match("%d+"))
        if count ~= nil then
          hasUnreadNotifications = count > 0
        end
      end
    )
  end
end

local function updateWorkspaces(result)
  workspaceRequestPending = false
  if result.exitCode ~= 0 then
    return
  end

  local raw = result.stdout or ""
  local workspaceList, activeId = raw:match("([%d,]+)%s+([%d.-]+)")
  if workspaceList == nil then
    return
  end

  local known = {}
  for idText in workspaceList:gmatch("%d+") do
    local id = tonumber(idText)
    if id ~= nil and id > 0 and id < 1000 then
      known[id] = true
    end
  end

  for id = 1, 3 do
    known[id] = true
  end

  local nextIds = {}
  for id in pairs(known) do
    table.insert(nextIds, id)
  end
  table.sort(nextIds)
  workspaceIds = nextIds

  activeWorkspace = tonumber(activeId) or activeWorkspace
end

local function requestWorkspaces()
  if workspaceRequestPending then
    return
  end

  workspaceRequestPending = noctalia.runAsync(
    "hyprctl workspaces -j 2>/dev/null | jq -r '[.[].id] | join(\",\")'; hyprctl activeworkspace -j 2>/dev/null | jq -r '.id'",
    updateWorkspaces
  )
end

local function closeIfPointerLeftPanel(result)
  panelProbePending = false

  if hovering or closeDeadline == nil then
    return
  end

  if result.exitCode == 0 and result.stdout:match("true") then
    closeDeadline = noctalia.nowMs() + CLOSE_GRACE_MS
    return
  end

  closePanel()
end

function update()
  if kind == "power-profile" then
    samplePowerProfile()
  elseif kind == "workspace" then
    requestWorkspaces()
  elseif kind == "media" or kind == "volume" or kind == "weather" or kind == "notifications" then
    sampleExternal()
  else
    sample()
  end
  render()

  if not hovering and closeDeadline ~= nil and noctalia.nowMs() >= closeDeadline and not panelProbePending then
    panelProbePending = noctalia.runAsync(CLOSE_PROBE, closeIfPointerLeftPanel)
  end
end

function onHover(state)
  handleHover(state)
end

if kind == "workspace" then
  UPDATE_INTERVAL_MS = 300
elseif kind == "weather" then
  UPDATE_INTERVAL_MS = 1000
elseif kind == "notifications" then
  UPDATE_INTERVAL_MS = 1000
else
  UPDATE_INTERVAL_MS = 1000
end

noctalia.setUpdateInterval(UPDATE_INTERVAL_MS)
if kind == "power-profile" then
  samplePowerProfile()
elseif kind == "workspace" then
  requestWorkspaces()
elseif kind == "media" or kind == "volume" or kind == "weather" or kind == "notifications" then
  sampleExternal()
else
  sample()
end
render()
