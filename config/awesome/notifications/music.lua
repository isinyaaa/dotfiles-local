local naughty = require("naughty")
local icons = require("icons")
local notifications = require("notifications")

notifications.music = {}

local notif
local first_time = true
local timeout = 2

local old_artist, old_song
local send_music_notif = function (artist, song, paused)
    if first_time then
        first_time = false
    else
        if  paused or (sidebar and sidebar.visible)
            or (client.focus and (client.focus.instance == "music" or client.focus.class == "music")) then
            -- Sidebar and already shows music info, so
            -- destroy notification if it exists
            -- Also destroy it if music pauses
            if notif then
                notif:destroy()
            end
        else
            -- Since the evil::music signal is also emitted when seeking, only
            -- send a notification when the song and artist are different than
            -- before.
            if artist ~= old_artist and song ~=old_song then
                notif = notifications.notify_dwim(
                    {
                        title = "Now playing:",
                        message = "<b>"..song.."</b> by <b>"..artist.."</b>",
                        icon = icons.image.music,
                        timeout = timeout,
                        app_name = "music"
                    },
                    notif)
            end
        end
        old_artist = artist
        old_song = song
    end
end

-- Allow dynamically toggling music notifications
notifications.music.enable = function()
    awesome.connect_signal("evil::music", send_music_notif)
    notifications.music.enabled = true
end
notifications.music.disable = function()
    awesome.disconnect_signal("evil::music", send_music_notif)
    notifications.music.enabled = false
end
notifications.music.toggle = function()
    if notifications.music.enabled then
        notifications.music.disable()
    else
        notifications.music.enable()
    end
end

-- Start with music notifications enabled
notifications.music.enable()
