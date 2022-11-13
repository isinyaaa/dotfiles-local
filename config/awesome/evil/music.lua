-- Provides:
-- evil::music
--      artist (string)
--      song (string)
--      paused (boolean)
-- evil::music_volume
--      value (integer from 0 to 100)
-- evil::music_options
--      loop (boolean)
--      random (boolean)
local awful = require("awful")

local function emit_info()
    local paused
    awful.spawn.easy_async_with_shell("playerctl status;\
                                       playerctl metadata xesam:artist;\
                                       playerctl metadata xesam:title",
        function(stdout)
            if stdout:match('^(.*)%c.*') == "Playing" then
                paused = false
            else
                paused = true
            end

            local artist = stdout:match('.*%c(.*)%c.*')
            if not artist or artist == "" then
                artist = "N/A"
            end

            local title = stdout:match('.*%c.*%c(.*)')
            if not title or title == "" then
                title = "N/A"
            end

            awesome.emit_signal("evil::music", artist, title, paused)
        end)
end

-- Run once to initialize widgets
emit_info()

----------------------------------------------------------

-- MPD Volume
local function emit_volume_info()
    awful.spawn.easy_async_with_shell("playerctl volume",
        function(stdout)
            awesome.emit_signal("evil::music_volume", tonumber(stdout))
        end
    )
end

-- Run once to initialize widgets
emit_volume_info()

-- Sleeps until music volume changes
-- >> We use `sed '1~2d'` to remove every other line since the mixer event
-- is printed twice for every volume update.
-- >> The `-u` option forces sed to work in unbuffered mode in order to print
-- without waiting for `mpc idleloop mixer` to finish
local music_volume_script = [[
  sh -c "
    mpc idleloop mixer | sed -u '1~2d'
  "]]

-- Kill old mpc idleloop mixer process
awful.spawn.easy_async_with_shell("ps x | grep \"mpc idleloop mixer\" | grep -v grep | awk '{print $1}' | xargs kill", function ()
    -- Emit song info with each line printed
    awful.spawn.with_line_callback(music_volume_script, {
        stdout = function()
            emit_volume_info()
        end
    })
end)

local music_options_script = [[
  sh -c "
    mpc idleloop options
  "]]

local function emit_options_info()
    awful.spawn.easy_async_with_shell("mpc | tail -1",
        function(stdout)
            local loop = stdout:match('repeat: (.*)')
            local random = stdout:match('random: (.*)')
            awesome.emit_signal("evil::music_options", loop:sub(1, 2) == "on", random:sub(1, 2) == "on")
        end
    )
end

-- Run once to initialize widgets
emit_options_info()

-- Kill old mpc idleloop options process
awful.spawn.easy_async_with_shell("ps x | grep \"mpc idleloop options\" | grep -v grep | awk '{print $1}' | xargs kill", function ()
    -- Emit song info with each line printed
    awful.spawn.with_line_callback(music_options_script, {
        stdout = function()
            emit_options_info()
        end
    })
end)
