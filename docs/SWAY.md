# Sway

`Super` is the modifier; directions are `h` `j` `k` `l` or the arrow keys.

## Launch

| Keys                        | Action                                                        |
| --------------------------- | ------------------------------------------------------------- |
| `Super Enter`               | Terminal (monstar)                                            |
| `Super Shift Enter`         | Floating terminal                                             |
| `Super d`                   | Launcher (rofi: apps and commands)                            |
| `Super p`                   | Screenshot of an area to the clipboard                        |
| `Super n` / `Super Shift n` | Dismiss the newest notification / all of them                 |
| `Super Shift s`             | Lock the screen                                               |
| `Super Shift i`             | Keep the screen awake; `Super -` then `Super Shift q` to stop |

## Windows

| Keys                    | Action                                  |
| ----------------------- | --------------------------------------- |
| `Super` direction       | Focus the window in that direction      |
| `Super Shift` direction | Move the window in that direction       |
| `Super Shift q`         | Close the window                        |
| `Super f`               | Fullscreen                              |
| `Super Shift space`     | Toggle floating                         |
| `Super space`           | Switch focus between floating and tiled |
| `Super a`               | Focus the parent container              |

## Layout

| Keys                  | Action                                                 |
| --------------------- | ------------------------------------------------------ |
| `Super b` / `Super v` | The next window opens beside / below the focused one   |
| `Super w` / `Super s` | Tabbed / stacked layout                                |
| `Super e`             | Back to split layout, toggling horizontal and vertical |
| `Super r`             | Resize mode: directions resize, `Enter` / `Esc` leave  |

## Workspaces

| Keys                              | Action                                                           |
| --------------------------------- | ---------------------------------------------------------------- |
| `Super 1` … `Super 0`             | Go to workspace 1 … 10; the current one's number again goes back |
| `Super Shift 1` … `Super Shift 0` | Move the window to workspace 1 … 10                              |
| `Super Tab` / `Super Shift Tab`   | Next / previous workspace                                        |
| `Super Ctrl h` / `Super Ctrl l`   | Previous / next workspace (also with arrows)                     |
| `Super Shift -` / `Super -`       | Send the window to the scratchpad / show it                      |

## Multiple screens

kanshi lays out the screens, which sway calls outputs. Whenever a screen is plugged in or out, it applies the profile in
`~/.config/kanshi/config` that names exactly the connected screens by connector, and changes nothing when no profile
does.

| Profile  | Screens                                                                |
| -------- | ---------------------------------------------------------------------- |
| `docked` | The Acer on `DP-2` on top, the laptop screen `eDP-1` centered below it |
| `laptop` | The laptop screen alone                                                |

Each screen shows one workspace at a time. `Super 1` … `Super 0` go to the screen that shows the workspace, and a new
workspace opens on the focused screen.

| Keys                        | Action                                                                          |
| --------------------------- | ------------------------------------------------------------------------------- |
| `Super` direction           | From the edge of a workspace, focus the screen in that direction                |
| `Super Shift` direction     | From the edge of a workspace, move the window to the screen in that direction   |
| `Super o` / `Super Shift o` | Move the workspace to the screen on the right / left; screens side by side only |
| Pointer                     | Moving it onto the other screen focuses the window under it                     |

Docked, the screens are stacked: `Super k` / `Super j` cross between them, and `Super o` / `Super Shift o` do nothing,
as neither screen lies wholly to the right or left of the other. Moving a tab up or down first takes it out of its tab
group; the next press takes it to the other screen. The pointer crosses where the laptop screen meets the Acer's bottom
edge.

Unplugging a screen moves its workspaces to the remaining one; plugging it back in returns them. A screen that no
profile names comes on at its preferred mode, to the right of the others.

| Command                         | Action                                                           |
| ------------------------------- | ---------------------------------------------------------------- |
| `swaymsg -t get_outputs`        | List the screens with their connector, modes, scale and position |
| `swaymsg output <name> disable` | Switch a screen off until `Super Shift c` re-applies the profile |

A new profile lists each screen with its mode, scale and position. Positions are in scaled pixels, the mode divided by
the scale: the Acer at 1.1 is 1745 × 981 and the laptop at 1.4 is 1371 wide, so `187,981` centers the laptop below the
Acer.

## Session

| Keys                 | Action                                                                             |
| -------------------- | ---------------------------------------------------------------------------------- |
| `Super Shift c`      | Reload sway and the display layout (kanshi)                                        |
| `Super Shift e`      | Exit sway, after a confirmation                                                    |
| `Ctrl Alt Backspace` | Exit sway at once                                                                  |
| Media keys           | Volume, mute, brightness, play / next / previous; they work on the lock screen too |
