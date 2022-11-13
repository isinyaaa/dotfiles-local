-- Text buttons for mpd control using "Material Design Icons" font
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local helpers = require("helpers")

local music_prev_symbol = wibox.widget.textbox()
music_prev_symbol.markup = helpers.colorize_text("", x.foreground)
music_prev_symbol.font = "Material Icons Bold 18"
music_prev_symbol.align = "center"
music_prev_symbol.valign = "center"
local music_next_symbol = wibox.widget.textbox()
music_next_symbol.markup = helpers.colorize_text("", x.foreground)
music_next_symbol.font = "Material Icons Bold 18"
music_next_symbol.align = "center"
music_next_symbol.valign = "center"

local note_symbol = ""
local big_note = wibox.widget.textbox(note_symbol)
big_note.font = "Material Icons Bold 15"
big_note.align = "center"
local small_note = wibox.widget.textbox()
small_note.align = "center"
small_note.markup = helpers.colorize_text(note_symbol, x.foreground)
small_note.font = "Material Icons Bold 11"
-- small_note.valign = "bottom"
local double_note = wibox.widget {
    big_note,
    -- small_note,
    {
        small_note,
        top = dpi(11),
        widget = wibox.container.margin
    },
    spacing = dpi(-9),
    layout = wibox.layout.fixed.horizontal
}

local music_toggle_icon = wibox.widget {
    double_note,
    -- bg = "#00000000",
    widget = wibox.container.background
}
music_toggle_icon:buttons(gears.table.join(
    awful.button({ }, 1, function ()
        awful.spawn.with_shell("playerctl play-pause")
    end)
))

local music_prev_icon = wibox.widget {
    music_prev_symbol,
    shape = gears.shape.circle,
    widget = wibox.container.background
}
music_prev_icon:buttons(gears.table.join(
    awful.button({ }, 1, function ()
        awful.spawn.with_shell("playerctl previous")
    end)
))

local music_next_icon = wibox.widget {
    music_next_symbol,
    shape = gears.shape.circle,
    widget = wibox.container.background
}
music_next_icon:buttons(gears.table.join(
    awful.button({ }, 1, function ()
        awful.spawn.with_shell("playerctl next")
    end)
))

local music_playing_counter = 0
local last_artist
local last_title
local music_playing_colors = {
    x.color1,
    x.color2,
    x.color3,
    x.color4,
    x.color5,
    x.color6,
}
local last_color = music_playing_colors[1]

awesome.connect_signal("evil::music", function(artist, title, paused)
    local accent, small_note_color
    if paused then
        accent = x.foreground.."33"
        small_note_color = x.foreground.."55"
    else
        if artist ~= last_artist and title ~= last_title then
            accent = music_playing_colors[(music_playing_counter % #music_playing_colors) + 1]
            music_playing_counter = music_playing_counter + 1
        else
            accent = last_color
        end
        last_artist = artist
        last_title = title
        last_color = accent
        small_note_color = x.foreground
    end

    big_note.markup = helpers.colorize_text(note_symbol, accent)
    small_note.markup = helpers.colorize_text(note_symbol, small_note_color)
    -- music_prev_icon.bg = accent
    -- music_next_icon.bg = accent
    music_prev_symbol.markup = helpers.colorize_text(music_prev_symbol.text, accent)
    music_next_symbol.markup = helpers.colorize_text(music_next_symbol.text, accent)
end)

local music_buttons = wibox.widget {
    nil,
    {
        music_prev_icon,
        music_toggle_icon,
        music_next_icon,
        spacing = dpi(14),
        layout  = wibox.layout.fixed.horizontal
    },
    expand = "none",
    layout = wibox.layout.align.horizontal,
}

-- Add clickable mouse effects on some widgets
helpers.add_hover_cursor(music_next_icon, "hand1")
helpers.add_hover_cursor(music_prev_icon, "hand1")
helpers.add_hover_cursor(music_toggle_icon, "hand1")

return music_buttons
