local active_address
local active_bias = 0

local function recalculate(ctx)
    local count = #ctx.targets
    if count == 0 then
        return
    end

    local gap = 3
    local column_counts
    if count == 1 then
        column_counts = { 1 }
    else
        column_counts = { math.floor(count / 2), math.ceil(count / 2) }
    end

    local column_weights = {}
    local active_column
    local active_row

    local index = 1
    for column, rows in ipairs(column_counts) do
        for row = 1, rows do
            local target = ctx.targets[index]
            if active_address and target.window and target.window.address == active_address then
                active_column = column
                active_row = row
            end
            index = index + 1
        end
    end

    for column = 1, #column_counts do
        column_weights[column] = column == active_column and 1 + active_bias or 1
    end

    local total_column_weight = 0
    for _, weight in ipairs(column_weights) do
        total_column_weight = total_column_weight + weight
    end

    local column_positions = {}
    local column_sizes = {}
    local x = ctx.area.x
    for column, weight in ipairs(column_weights) do
        column_positions[column] = x
        column_sizes[column] = ctx.area.w * weight / total_column_weight
        x = x + column_sizes[column]
    end

    index = 1
    for column, rows in ipairs(column_counts) do
        local row_weights = {}
        local total_row_weight = 0
        for row = 1, rows do
            row_weights[row] = column == active_column and row == active_row and 1 + active_bias or 1
            total_row_weight = total_row_weight + row_weights[row]
        end

        local row_positions = {}
        local row_sizes = {}
        local y = ctx.area.y
        for row, weight in ipairs(row_weights) do
            row_positions[row] = y
            row_sizes[row] = ctx.area.h * weight / total_row_weight
            y = y + row_sizes[row]
        end

        for row = 1, rows do
            local target = ctx.targets[index]
            local left_gap = column > 1 and gap / 2 or 0
            local right_gap = column < #column_counts and gap / 2 or 0
            local top_gap = row > 1 and gap / 2 or 0
            local bottom_gap = row < rows and gap / 2 or 0

            target:place({
                x = column_positions[column] + left_gap,
                y = row_positions[row] + top_gap,
                w = column_sizes[column] - left_gap - right_gap,
                h = row_sizes[row] - top_gap - bottom_gap,
            })
            index = index + 1
        end
    end
end

hl.layout.register("eva-grid", {
    recalculate = recalculate,
    layout_msg = function()
        return true
    end,
})

local function window_center(window)
    local at = window.at
    local size = window.size
    return at.x + size.x / 2, at.y + size.y / 2
end

local function ranges_overlap(first_start, first_size, second_start, second_size)
    return first_start < second_start + second_size
        and second_start < first_start + first_size
end

EVA_GRID_FOCUS = function(direction)
    local active = hl.get_active_window()
    if not active or not active.workspace then
        return
    end

    local active_at = active.at
    local active_size = active.size
    local active_x, active_y = window_center(active)
    local best
    local best_aligned
    local best_primary
    local best_perpendicular
    local best_tie_position

    for _, target in ipairs(hl.get_windows({
        workspace = active.workspace,
        floating = false,
    })) do
        if target.address ~= active.address and target.visible and not target.hidden and target.accepts_input then
            local target_x, target_y = window_center(target)
            local delta_x = target_x - active_x
            local delta_y = target_y - active_y
            local primary
            local perpendicular
            local aligned
            local tie_position

            if direction == "left" and delta_x < 0 then
                primary = -delta_x
                perpendicular = math.abs(delta_y)
                aligned = ranges_overlap(active_at.y, active_size.y, target.at.y, target.size.y)
                tie_position = target_y
            elseif direction == "right" and delta_x > 0 then
                primary = delta_x
                perpendicular = math.abs(delta_y)
                aligned = ranges_overlap(active_at.y, active_size.y, target.at.y, target.size.y)
                tie_position = target_y
            elseif direction == "up" and delta_y < 0 then
                primary = -delta_y
                perpendicular = math.abs(delta_x)
                aligned = ranges_overlap(active_at.x, active_size.x, target.at.x, target.size.x)
                tie_position = target_x
            elseif direction == "down" and delta_y > 0 then
                primary = delta_y
                perpendicular = math.abs(delta_x)
                aligned = ranges_overlap(active_at.x, active_size.x, target.at.x, target.size.x)
                tie_position = target_x
            end

            if primary and (
                not best
                or (aligned and not best_aligned)
                or (aligned == best_aligned and primary < best_primary)
                or (aligned == best_aligned and primary == best_primary and perpendicular < best_perpendicular)
                or (aligned == best_aligned and primary == best_primary and perpendicular == best_perpendicular and tie_position < best_tie_position)
            ) then
                best = target
                best_aligned = aligned
                best_primary = primary
                best_perpendicular = perpendicular
                best_tie_position = tie_position
            end
        end
    end

    if best then
        hl.dispatch(hl.dsp.focus({ window = best }))
    end
end

local function schedule_recalculate()
    hl.timer(function()
        hl.dispatch(hl.dsp.layout("eva-grid-refresh"))
    end, {
        timeout = 100,
        type = "oneshot",
    })
end

EVA_GRID_RESIZE = function(amount)
    local active = hl.get_active_window()
    if not active then
        return
    end

    if active_address ~= active.address then
        active_address = active.address
        active_bias = 0
    end

    active_bias = math.max(-0.35, math.min(0.35, active_bias + amount))
    hl.dispatch(hl.dsp.layout("eva-grid-resize"))
end

hl.on("window.open", schedule_recalculate)
hl.on("window.close", schedule_recalculate)
hl.on("window.move_to_workspace", schedule_recalculate)
hl.on("window.active", function()
    active_address = nil
    active_bias = 0
    schedule_recalculate()
end)
