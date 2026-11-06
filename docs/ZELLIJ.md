# Zellij

Every session starts **locked**: keys go to the program in the pane. `Ctrl g` switches to the tmux-style mode for one
command, then zellij locks again. `Esc` or `Ctrl g` cancels without doing anything.

## Panes

| Keys                              | Action                                                        |
| --------------------------------- | ------------------------------------------------------------- |
| `Ctrl g` `%`                      | New pane to the right                                         |
| `Ctrl g` `"`                      | New pane below                                                |
| `Ctrl g` `h` `j` `k` `l` / arrows | Move focus left / down / up / right                           |
| `Ctrl g` `z`                      | Toggle the focused pane fullscreen                            |
| `Ctrl g` `x`                      | Close the focused pane                                        |
| `Ctrl g` `H` `J` `K` `L`          | Grow the pane left / down / up / right; repeat, `Esc` to stop |
| Mouse click / mouse selection     | Focus a pane / copy text (`wl-copy`)                          |

## Tabs

| Keys               | Action                                                  |
| ------------------ | ------------------------------------------------------- |
| `Ctrl g` `c`       | New tab                                                 |
| `Ctrl g` `n` / `p` | Next / previous tab                                     |
| `Ctrl g` `1` … `9` | Go to tab 1 … 9                                         |
| `Ctrl g` `,`       | Rename the tab: type, `Enter`; `Esc` keeps the old name |
| `Ctrl g` `&`       | Close the tab with all its panes                        |

## Scroll and search

`Ctrl g` `[` enters scroll mode:

| Keys                   | Action                                               |
| ---------------------- | ---------------------------------------------------- |
| `j` / `k`              | Line down / up                                       |
| `d` / `u`              | Half page down / up                                  |
| `Ctrl f` / `Ctrl b`    | Page down / up                                       |
| `g` / `G`              | Top / bottom                                         |
| `/`, text, `Enter`     | Search; then `n` / `N` for the next / previous match |
| `q` / `Esc` / `Ctrl g` | Back to locked                                       |

## Sessions

| Keys / command  | Action                                    |
| --------------- | ----------------------------------------- |
| `Ctrl g` `d`    | Detach; the session keeps running         |
| `zellij` / `zj` | Attach to the session `main`, or start it |

## Handy commands

| Command          | Action                                                    |
| ---------------- | --------------------------------------------------------- |
| `ide`            | Lay out the current tab: a 70% main pane over three panes |
| `viddy -n 2 lst` | A self-updating, scrollable folder tree (in its own pane) |
