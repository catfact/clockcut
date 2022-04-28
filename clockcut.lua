-- clockcut
--
-- simple clocked looper
--
-- no UI at the moment,
-- designed for MIDI mapping

local Sequins = require 'sequins'
local Taper = include 'lib/taper'
local Eq = include 'lib/eq'
local ControlSpec = require 'controlspec'

engine.name = 'None'


------------------------------------------------
---- state

-- start point in the buffer, in seconds
-- TODO: try scrubbing this around!
start_position = 1
-- ^NB: this is 1 second, nothing to do with base-1
-- that is in case negative rates are added, necessitating pre-roll

-- a sequence of clock duration multipliers
-- (scaled by our master multiplier parameter)
-- TODO: make this non-trivial!
sequence = {1}

speed_base_ratio=1
speed_tune_ratio=1

-------------------------------------------------
--- helpers

--- multiplier param display
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
    local seq = Sequins(sequence)
    while(true) do
        -- we'll simply tell softcut to jump back to the start on each tick
        softcut.position(1, start_position)
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
    local amp = Taper.amp_128[index]
    local db = Taper.db_128[index]
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

    -- speed ratio param
    params:add({type='option',id='speed_ratio', name='speed_ratio', 
        options=mul_str, default=7, action=function(index)
        local str = muls[index][2]
        speed_base_ratio =  muls[index][1]
        softcut.rate(1, speed_base_ratio * speed_tune_ratio)
        param_str['speed_ratio'] = 'speed_ratio: '..str
        screen_dirty = true
    end})

    -- speed tuning param
    params:add({type="number", id='speed_tune', name='speed_tune',
        min=-200, max=200, default=0, action=function(cents)
        speed_base_tune = 2 ^ (cents/1200)
        softcut.rate(1, speed_base_ratio * speed_base_tune)
        param_str['speed_tune'] = 'speed_tune: '..cents
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
            options=Taper.db_128, default=defaultIndex, action=function(index)    
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


--[[
    -- the EQ class is a helper abstraction over the softcut SVF
    eq = Eq.new(1)
    params:add({id='eq_mix', type='control', min=0, max=1, default=1, action=function(x)
        eq:set_mix(x); eq:apply()
    end})
    params:add({id='eq_fc', type='control', min=0, max=1, default=0, action=function(x)
        eq:set_fc(x); eq:apply()
    end, spec=ControlSpec.new(20, 16000, 'exp', 0, 1200, "hz")})
    params:add({id='eq_tilt', type='control', min=-1, max=1, default=0, action=function(x)
        eq:set_tilt(x); eq:apply()
    end})
    params:add({id='eq_gain', type='control', min=-1, max=1, default=0, action=function(x)
        eq:set_gain(x); eq:apply()
    end})
    params:add({id='eq_rez', type='control', min=0, max=1, default=0, action=function(x)
        eq:set_rez(x); eq:apply()
    end})
--]]
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
    screen.move(8, 40-2); screen.text(param_str['speed_ratio'])
    screen.move(8, 50-2); screen.text(param_str['speed_tune'])
    screen.move(8, 60-2); screen.text(param_str['fade_ms'])
    screen.update()
end

cleanup = function()
    screen_timer:stop()
end