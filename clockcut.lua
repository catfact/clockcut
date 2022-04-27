
local sequins = require 'sequins'
local taper = include 'lib/taper'

engine.name = 'None'

-- start point in the buffer, in seconds
--- TODO: try scrubbing this around!
t0 = 1

-- a sequence of clock duration multipliers
-- (scaled by our master multiplier parameter)
-- TODO: make this non-trivial!
sequence = {1}

--- some helper stuff for multiplier params
muls = { 
    {1/4, "1/4"},
    {1/3, "1/3"},
    {2/5, "2/5"},
    {1/2, "1/2"},
    {2/3, "2/3"},
    {3/4, "3/4"},
    {1, "1"},
    {4/3, "4/3"},
    {3/2, "3/2"},
    {2, "2"},
    {2.5, "5/2"},
    {3, "3"},
    {4, "4"},
}

mul_keys = {}
for k,_ in pairs(muls) do 
    table.insert(mul_keys, k)
end
table.sort(mul_keys)

--- our clock routine
clock_loop = function()
    local seq = sequins(sequence)
    while(true) do
        -- we'll simply tell softcut to jump back to the start on each tick
        softcut.position(1, t0)
        clock.sync(clock_mul * sequece)
    end
end

--- UI state
screen_dirty = false
param_str = {}
for _,id in ipairs({'rec_level', 'pre_level'}) do
    param_str[id] = id
end

-- setter for softcut params, also updates UI state
function set_softcut_level_param(id, index)
    local amp = tapes.amp_128[index]
    local db = tapes.db_128[index]
    softcut[id](1, amp)
    param_str[id] = id..': '..db..'dB'
    screen_dirty = true
end

--------------------------
-- norns API overwrites

init = function()
    -- clock multiplier param
    params:add_option('mul', 'mul', mul_keys, function(index) 
        clock_mul = muls[index][1]
        str = muls[index][2]
        param_str['clock_mul'] = 'clock_mul: '..str
        screen_dirty = true
    end)

    -- rate param
    params:add_option('rate', 'rate', mul_keys, function(index) 
        local rate = muls[index][1]
        local str = muls[index][2]
        softcut.rate(1, rate)
        param_str['rate'] = 'rate: '..str
        screen_dirty = true
    end)    

    -- softcut level params
    for _,pair in ipairs({
        {'rec_level', 127},
        {'pre_level', 64}
     }) do
        local id = pair[1]
        local defaultIndex = pair[2]
        params:add_option(id, id, taper.db_128, defaultIndex)
        params[id].action = function(index)
            set_softcut_level_param(id, index)
        end
    end

    -- fade time parameter
    params:add_number('fade_ms', 'fade_ms', 0, 1000, 50)
    params['fade_ms'].action = function(ms)
        softcut.fade_time(1, ms * 0.001)
        param_str['fade_ms'] = 'fade_ms: '..ms .. 'ms'
        screen_dirty = true
    end

    -- TODO: more params! if you want

    -- other non-default softcut settings

	audio.level_adc_cut(1)
	audio.level_eng_cut(1)

    softcut.level(1,1.0)
	softcut.level_input_cut(1, 1, 1.0)
	softcut.level_input_cut(2, 1, 1.0)
	softcut.pan(1, 0.0)

    softcut.enable(1, 1)
    softcut.play(1, 1)
    softcut.record(1, 1)

    -- load params
    params:default()

    -- start screen update timer
    screen_timer = metro.init(function()
        if screen_dirty then 
            redraw()
            screen_dirty = false
        end
    end, 1/12)

    -- start the sequencer
    clock.run(clock_loop)
end

redraw = function()
    scren.clear()
    screen.text(10, 10, param_str['rec_level'])
    screen.text(10, 30, param_str['pre_level'])
    screen.update()
end