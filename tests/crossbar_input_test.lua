package.path = './?.lua;' .. package.path

local crossbar_selector = require('crossbar_selector')
local doublepress_tracker = require('doublepress_tracker')

local function assert_equal(expected, actual, message)
    if (expected ~= actual) then
        error((message or 'values differ') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
    end
end

local function select_bar(max_hotbars, left_pressed, right_pressed,
        left_just_pressed, right_just_pressed, left_doublepressed, right_doublepressed,
        current_crossbar)
    return crossbar_selector.get_active_crossbar(
        max_hotbars,
        left_pressed,
        right_pressed,
        left_just_pressed,
        right_just_pressed,
        left_doublepressed,
        right_doublepressed,
        current_crossbar,
        0)
end

assert_equal(1, select_bar(6, true, false, true, false, false, false, 0), 'single left')
assert_equal(2, select_bar(6, false, true, false, true, false, false, 0), 'single right')
assert_equal(3, select_bar(6, true, true, true, false, false, false, 2), 'right then left')
assert_equal(4, select_bar(6, true, true, false, true, false, false, 1), 'left then right')
assert_equal(5, select_bar(6, true, false, true, false, true, false, 1), 'double left')
assert_equal(6, select_bar(6, false, true, false, true, false, true, 2), 'double right')
assert_equal(1, select_bar(4, true, false, true, false, true, false, 1), 'bar 5 disabled')
assert_equal(2, select_bar(5, false, true, false, true, false, true, 2), 'bar 6 disabled')
assert_equal(3, select_bar(3, true, true, true, false, false, false, 2), 'three-bar combined triggers')
assert_equal(0, select_bar(6, false, false, false, false, false, false, 2), 'triggers released')

local scheduled = {}
local tracker = doublepress_tracker.new(function(callback)
    scheduled[#scheduled + 1] = callback
end, 0.5)

local left_doublepressed, right_doublepressed = tracker:update(true, false, false, false, true, false)
assert_equal(false, left_doublepressed, 'first left press')
tracker:update(false, true, false, false, false, false)
left_doublepressed = tracker:update(true, false, false, false, true, false)
assert_equal(true, left_doublepressed, 'second left press')
left_doublepressed = tracker:update(false, true, false, false, false, false)
assert_equal(false, left_doublepressed, 'left doublepress clears on release')

tracker:update(true, false, false, false, true, false)
tracker:update(false, true, false, false, false, false)
tracker:update(true, false, false, false, true, false)
tracker:reset()
assert_equal(false, tracker.left.doublepressed, 'reset clears left doublepress')
assert_equal(false, tracker.left.window_open, 'reset clears left window')

tracker:reset()
tracker:update(false, false, true, false, false, true)
tracker:update(false, false, false, true, false, false)
right_doublepressed = select(2, tracker:update(false, false, true, false, false, true))
assert_equal(true, right_doublepressed, 'second right press')

tracker:reset()
tracker:update(true, false, false, false, true, false)
scheduled[#scheduled]()
tracker:update(false, true, false, false, false, false)
left_doublepressed = tracker:update(true, false, false, false, true, false)
assert_equal(false, left_doublepressed, 'expired left window')

tracker:reset()
tracker:update(true, false, false, false, true, false)
local stale_callback = scheduled[#scheduled]
tracker:reset()
tracker:update(true, false, false, false, true, false)
stale_callback()
tracker:update(false, true, false, false, false, false)
left_doublepressed = tracker:update(true, false, false, false, true, false)
assert_equal(true, left_doublepressed, 'stale timer does not close a new window')

-- Mirror xivcrossbar.lua's event ordering: calculate transitions, update the
-- physical trigger state, update doublepress state, then select the bar.
scheduled = {}
tracker = doublepress_tracker.new(function(callback)
    scheduled[#scheduled + 1] = callback
end, 0.5)
local input_state = {left = false, right = false, active_bar = 0}
local function trigger(side, pressed)
    local left_just_pressed = side == 'left' and pressed and not input_state.left
    local left_just_released = side == 'left' and not pressed and input_state.left
    local right_just_pressed = side == 'right' and pressed and not input_state.right
    local right_just_released = side == 'right' and not pressed and input_state.right
    input_state[side] = pressed

    local left_double, right_double = tracker:update(
        left_just_pressed,
        left_just_released,
        right_just_pressed,
        right_just_released,
        input_state.left,
        input_state.right)
    input_state.active_bar = select_bar(
        6,
        input_state.left,
        input_state.right,
        left_just_pressed,
        right_just_pressed,
        left_double,
        right_double,
        input_state.active_bar)
    return input_state.active_bar
end

assert_equal(1, trigger('left', true), 'event sequence first left press')
assert_equal(0, trigger('left', false), 'event sequence first left release')
assert_equal(5, trigger('left', true), 'event sequence second left press')
assert_equal(0, trigger('left', false), 'event sequence second left release')
assert_equal(2, trigger('right', true), 'event sequence first right press')
assert_equal(0, trigger('right', false), 'event sequence first right release')
assert_equal(6, trigger('right', true), 'event sequence second right press')

print('crossbar input tests passed')
