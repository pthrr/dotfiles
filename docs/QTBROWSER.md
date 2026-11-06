# qutebrowser

qutebrowser 3.7.0 runs with its default keys. Like Vim, keys act in normal mode; typing goes into a page in insert mode
(`i`, or clicking a field), and `Esc` returns to normal mode.

## Open

| Keys                      | Action                                             |
| ------------------------- | -------------------------------------------------- |
| `o` / `O`                 | Open a URL or search, in this tab / in a new tab   |
| `go` / `gO`               | Edit the current URL, in this tab / in a new tab   |
| `Ctrl t`                  | New tab                                            |
| `Ctrl n` / `Ctrl Shift n` | New window / new private window                    |
| `pp` / `Pp`               | Open the URL in the clipboard, here / in a new tab |

## Tabs

| Keys                        | Action                                     |
| --------------------------- | ------------------------------------------ |
| `J` / `K`                   | Next / previous tab                        |
| `Alt 1` … `Alt 8` / `Alt 9` | Go to tab 1 … 8 / the last tab             |
| `gt`                        | Pick a tab by title or URL                 |
| `Ctrl Tab`                  | The tab used last                          |
| `d` / `u`                   | Close the tab / reopen the last closed one |
| `co`                        | Close all other tabs                       |
| `gJ` / `gK`                 | Move the tab right / left                  |
| `gC`                        | Duplicate the tab                          |

## On a page

| Keys                                  | Action                                   |
| ------------------------------------- | ---------------------------------------- |
| `j` `k` / `h` `l`                     | Scroll down, up / left, right            |
| `Ctrl d` `Ctrl u` / `Ctrl f` `Ctrl b` | Half a page down, up / a page down, up   |
| `gg` / `G`                            | Top / bottom                             |
| `H` / `L`                             | Back / forward                           |
| `r` / `R`                             | Reload / reload without the cache        |
| `/` `?` text, `n` / `N`               | Search the page; next / previous match   |
| `+` / `-` / `=`                       | Zoom in / out / reset                    |
| `[[` / `]]`                           | Previous / next page of a paginated site |
| `gu`                                  | Up one level in the URL                  |

## Links

`f` puts a short label on every link; type the label to follow it.

| Keys        | Action                                 |
| ----------- | -------------------------------------- |
| `f` / `F`   | Follow a link / open it in a new tab   |
| `;b`        | Open a link in a background tab        |
| `;y`        | Copy a link's URL                      |
| `;d`        | Download a link                        |
| `gi` / `;t` | Focus the first input field / pick one |

## Copy

| Keys        | Action                                                                                        |
| ----------- | --------------------------------------------------------------------------------------------- |
| `yy` / `yt` | Copy the URL / the page title                                                                 |
| `ym`        | Copy a Markdown link, `[title](url)`                                                          |
| `v`         | Caret mode: move with `h` `j` `k` `l` `w` `b`, `v` starts selecting, `y` copies, `Esc` leaves |

## Bookmarks

| Keys              | Action                                                    |
| ----------------- | --------------------------------------------------------- |
| `m` / `b` / `B`   | Save a quickmark (a short name) / open one / in a new tab |
| `M` / `gb` / `gB` | Add a bookmark / open one / in a new tab                  |

## Modes and more

| Keys                   | Action                                                         |
| ---------------------- | -------------------------------------------------------------- |
| `i` / `Esc`            | Type into the page / back to normal mode                       |
| `Ctrl v` / `Shift Esc` | Pass every key to the page / back to normal mode               |
| `:`                    | Command line; `Tab` completes, `Ctrl p` / `Ctrl n` for history |
| `.`                    | Repeat the last command                                        |
| `gd`                   | Download the page                                              |
| `wi` / `gf`            | Developer tools / page source                                  |
| `Sh`                   | History                                                        |
| `Ctrl q` / `ZZ`        | Quit / quit and keep the open tabs for next time               |
