local wezterm = require 'wezterm'
return {
    font = wezterm.font 'Ubuntu Mono',
    font_size = 11,
    color_scheme = "Solarized Dark (base16)",
    check_for_updates = false,
    animation_fps = 1,
    cursor_blink_rate = 0,
    enable_wayland = false,
    hide_tab_bar_if_only_one_tab = false,
    window_padding = {
        left = 5,
        right = 5,
        top = 5,
        bottom = 0,
    },
    use_fancy_tab_bar = false,
    exit_behavior = "CloseOnCleanExit",
    tab_bar_at_bottom = true,
    window_close_confirmation = "AlwaysPrompt",
}
