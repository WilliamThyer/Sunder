-- Test script to verify input edge detection fix
-- This simulates the keyboard edge detection logic

function love.load()
    local keyboardJustPressed = {
        a = false,
        b = false,
        x = false,
        y = false,
        start = false,
        back = false,
        up = false,
        down = false,
        left = false,
        right = false
    }

    local keyboardPrevState = {
        a = false,
        b = false,
        x = false,
        y = false,
        start = false,
        back = false,
        up = false,
        down = false,
        left = false,
        right = false
    }

    -- Simulate key states (true = pressed, false = not pressed)
    local simulateKeyStates = {
        a = {false, true, true, true, false, true, false}, -- Key press pattern
        b = {false, false, false, false, false, false, false},
        x = {false, false, false, false, false, false, false},
        y = {false, false, false, false, false, false, false},
        start = {false, false, false, false, false, false, false},
        back = {false, false, false, false, false, false, false},
        up = {false, false, false, false, false, false, false},
        down = {false, false, false, false, false, false, false},
        left = {false, false, false, false, false, false, false},
        right = {false, false, false, false, false, false, false}
    }

    local frame = 1

    local function updateKeyboardEdgeDetection()
        -- Simulate the fixed edge detection logic
        for key, _ in pairs(keyboardJustPressed) do
            local currentState = simulateKeyStates[key][frame] or false
            
            -- Set justPressed only when key transitions from not pressed to pressed
            keyboardJustPressed[key] = currentState and not keyboardPrevState[key]
            
            -- Update previous state
            keyboardPrevState[key] = currentState
        end
    end

    local function clearKeyboardEdgeDetection()
        for key, _ in pairs(keyboardJustPressed) do
            keyboardJustPressed[key] = false
        end
    end

    print("Testing input edge detection fix:")
    print("Frame | Key A Current | Key A Prev | Key A JustPressed")
    print("------|---------------|------------|------------------")

    for frame = 1, 7 do
        updateKeyboardEdgeDetection()
        
        local currentA = simulateKeyStates.a[frame] or false
        local prevA = keyboardPrevState.a
        local justPressedA = keyboardJustPressed.a
        
        print(string.format("%5d | %12s | %10s | %16s", 
            frame, 
            tostring(currentA), 
            tostring(prevA), 
            tostring(justPressedA)
        ))
        
        -- Clear justPressed after processing (simulate what happens in the game)
        clearKeyboardEdgeDetection()
    end

    print("\nTest completed. Key A should only be 'justPressed' on frame 2 (first press) and frame 6 (after release and repress).")
    
    -- Exit after test
    love.event.quit()
end

function love.update(dt)
    -- Not needed for this test
end

function love.draw()
    -- Not needed for this test
end 