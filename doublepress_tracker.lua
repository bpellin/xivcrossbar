local doublepress_tracker = {}

local function new_side_state()
    return {
        doublepressed = false,
        generation = 0,
        lifted = false,
        window_open = false,
    }
end

function doublepress_tracker.new(schedule, window_seconds)
    local tracker = {
        left = new_side_state(),
        right = new_side_state(),
        schedule = schedule,
        window_seconds = window_seconds or 0.5,
    }

    function tracker:cancel_window(side)
        local state = self[side]
        state.generation = state.generation + 1
        state.lifted = false
        state.window_open = false
    end

    function tracker:open_window(side)
        local state = self[side]
        state.generation = state.generation + 1
        local generation = state.generation
        state.lifted = false
        state.window_open = true

        self.schedule(function()
            if (state.generation == generation) then
                state.lifted = false
                state.window_open = false
            end
        end, self.window_seconds)
    end

    function tracker:reset()
        self:cancel_window('left')
        self:cancel_window('right')
        self.left.doublepressed = false
        self.right.doublepressed = false
    end

    function tracker:update(left_just_pressed, left_just_released,
            right_just_pressed, right_just_released, left_pressed, right_pressed)
        local only_left_just_pressed = left_just_pressed and not right_pressed
        local only_right_just_pressed = right_just_pressed and not left_pressed

        if (not self.left.window_open and only_left_just_pressed) then
            self:open_window('left')
            self:cancel_window('right')
        end
        if (not self.right.window_open and only_right_just_pressed) then
            self:open_window('right')
            self:cancel_window('left')
        end

        if (self.left.window_open and left_just_released and not right_pressed) then
            self.left.lifted = true
        end
        if (self.right.window_open and right_just_released and not left_pressed) then
            self.right.lifted = true
        end

        if (only_left_just_pressed and self.left.window_open and self.left.lifted) then
            self.left.doublepressed = true
            self:cancel_window('left')
        end
        if (only_right_just_pressed and self.right.window_open and self.right.lifted) then
            self.right.doublepressed = true
            self:cancel_window('right')
        end

        if (left_just_released and self.left.doublepressed) then
            self.left.doublepressed = false
        end
        if (right_just_released and self.right.doublepressed) then
            self.right.doublepressed = false
        end

        return self.left.doublepressed, self.right.doublepressed
    end

    return tracker
end

return doublepress_tracker
