
local sequins = require 'sequins'
local taper = include 'lib/taper'
--local eq = include 'lib/eq'

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

mul_str = {}
for i=1,#muls do 
    table.insert(mul_str, muls[i][2])
end

--- our clock routine
clock_loop = function()
    local seq = sequins(sequence)
    while(true) do
        -- we'll simply tell softcut to jump back to the start on each tick
        softcut.position(1, t0)
        clock.sync(clock_mul * seq())
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
    local amp = taper.amp_128[index]
    local db = taper.db_128[index]
    softcut[id](1, amp)
    param_str[id] = id..': '..db..'dB'
    screen_dirty = true
end

--------------------------
-- norns API overwrites

init = function()
    -- clock multiplier param
    params:add({type='option', id='clock_mul', name='clock_mul', 
        options=mul_str, default=7, action=function(index)
        clock_mul = muls[index][1]
        str = muls[index][2]
        param_str['clock_mul'] = 'clock_mul: '..str
        screen_dirty = true
    end})

    -- rate param
    params:add({type='option',id='rate', name='rate', 
        options=mul_str, default=7, action=function(index) 
        local rate = muls[index][1]
        local str = muls[index][2]
        softcut.rate(1, rate)
        param_str['rate'] = 'rate: '..str
        screen_dirty = true
    end})

    -- softcut level params
    for _,pair in ipairs({
        {'rec_level', 128},
        {'pre_level', 112}
     }) do
        local id = pair[1]
        local defaultIndex = pair[2]
        params:add({type='option', id=id, name=id, 
            options=taper.db_128, default=defaultIndex, action=function(index)    
            set_softcut_level_param(id, index)
        end})
    end

    -- fade time parameter
    params:add({type='number', id='fade_ms', name='fade_ms', 
        min=0, max=1000, default=50,  action = function(ms)
        softcut.fade_time(1, ms * 0.001)
        param_str['fade_ms'] = 'fade_ms: '..ms .. 'ms'
        screen_dirty = true
    end})

    -- TODO: more params! if you want

    -- other non-default softcut settings
	audio.level_cut(1)
	audio.level_adc_cut(1)
	audio.level_eng_cut(1)
    
    softcut.level(1,1.0)
	softcut.level_input_cut(1, 1, 1.0)
	softcut.level_input_cut(2, 1, 1.0)
	softcut.pan(1, 0.0)

	softcut.filter_dry(1, 1)
	softcut.filter_lp(1, 0)
	softcut.filter_hp(1, 0)
	softcut.filter_bp(1, 0)
	softcut.filter_br(1, 0)

    softcut.enable(1, 1)
    softcut.play(1, 1)
    softcut.rec(1, 1)

	softcut.loop_start(1, 0)
	softcut.loop_end(1, softcut.BUFFER_SIZE)
	softcut.loop(1, 0)

    -- load params
    params:default()

    -- start a screen update timer
    screen_timer = metro.init(function()
        if screen_dirty then 
            redraw()
            screen_dirty = false
        end
    end, 1/12)
    screen_timer:start()

    -- start the sequencer
    clock.run(clock_loop)
end

redraw = function()
    screen.clear()
    screen.move(8, 10-2); screen.text(param_str['rec_level'])
    screen.move(8, 20-2); screen.text(param_str['pre_level'])
    screen.move(8, 30-2); screen.text(param_str['clock_mul'])
    screen.move(8, 40-2); screen.text(param_str['rate'])
    screen.move(8, 50-2); screen.text(param_str['fade_ms'])
    screen.update()
end

cleanup = function()
    screen_timer:stop()
end