local crossbar_selector = {}

-- Resolve the active crossbar from the shared trigger state. The caller supplies
-- the current value because pressing both triggers only changes bars on the
-- transition where the second trigger is pressed.
function crossbar_selector.get_active_crossbar(max_hotbars, left_pressed, right_pressed,
        left_just_pressed, right_just_pressed, left_doublepressed, right_doublepressed,
        current_crossbar, inactive_crossbar)
    if (left_pressed and right_pressed) then
        if (max_hotbars > 3) then
            if (left_just_pressed) then
                return 3
            elseif (right_just_pressed) then
                return 4
            end

            return current_crossbar
        end

        return 3
    elseif (left_pressed) then
        if (max_hotbars >= 5 and left_doublepressed) then
            return 5
        end

        return 1
    elseif (right_pressed) then
        if (max_hotbars >= 6 and right_doublepressed) then
            return 6
        end

        return 2
    end

    return inactive_crossbar
end

return crossbar_selector
