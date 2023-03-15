local wezterm = require 'wezterm'
return {
    check_for_updates = false,
    font = wezterm.font 'Ubuntu Mono',
    font_size = 12,
    color_scheme = "Solarized Dark (base16)",
    cursor_blink_rate = 0,
    use_fancy_tab_bar = false,
    tab_bar_at_bottom = true,
    window_padding = {
        left = 5,
        right = 5,
        top = 5,
        bottom = 0,
    },
}
