# Neovim

Leader is `,`. `jk` leaves insert mode.

## Moving

| Keys                      | Action                                            |
| ------------------------- | ------------------------------------------------- |
| `w` / `b` / `e`           | Next word / previous word / end of word           |
| `0` / `^` / `$`           | Line start / first character / line end           |
| `gg` / `G`                | First / last line                                 |
| `{` / `}`                 | Previous / next paragraph                         |
| `%`                       | Matching bracket                                  |
| `f` `x` / `t` `x`, `;`    | Jump to / before the next `x` on the line; repeat |
| `Ctrl d` / `Ctrl u`, `zz` | Half page down / up; centre the cursor line       |
| `Ctrl o` / `Ctrl i`       | Back / forward in the jump list                   |

## Editing

| Keys                        | Action                                                                         |
| --------------------------- | ------------------------------------------------------------------------------ |
| `i` `a` / `I` `A` / `o` `O` | Insert before / after cursor, at line start / end, new line below / above      |
| `ciw` `ci"` `ci(` `cit`     | Change word / inside quotes / brackets / tag (`d` deletes, `y` yanks the same) |
| `dd` / `yy` / `p` `P`       | Delete line / yank line / paste after / before                                 |
| `x` / `r` / `J`             | Delete character / replace character / join lines                              |
| `>>` / `<<`                 | Indent / unindent                                                              |
| `u` / `Ctrl r` / `.`        | Undo / redo / repeat the last change                                           |
| `v` / `V` / `Ctrl v`, `gv`  | Select characters / lines / a block; reselect                                  |
| `gcc` / `gc` + motion       | Toggle comment on the line / the motion or selection                           |
| `,p`                        | Paste the last yank, not the last delete                                       |
| `,d`                        | Delete without overwriting the yank (normal and visual)                        |
| `,p` in visual mode         | Replace the selection without overwriting the yank                             |
| `:w` / `:q` / `:wq` / `:qa` | Save / close window / save and close / quit all                                |

## Windows, buffers, tabs

| Keys                | Action                                             |
| ------------------- | -------------------------------------------------- |
| `ss` / `sv`         | Split below / to the right, cursor in the new half |
| `sh` `sj` `sk` `sl` | Move to the window left / below / above / right    |
| `]b` / `[b`         | Next / previous buffer                             |
| `]t` / `[t`         | Next / previous tab                                |
| `:e` file / `:bd`   | Open a file / close the buffer                     |

## Finding

| Keys / command             | Action                                                        |
| -------------------------- | ------------------------------------------------------------- |
| `,ss` / `,sS`              | Pick a symbol of this file / of the whole workspace           |
| `,sd`                      | Pick from every diagnostic Neovim knows, worst first          |
| `/` `?` text, `n` `N`, `*` | Search forward / backward, next / previous, word under cursor |

Inside a picker: type to filter, `Ctrl n` / `Ctrl p` move, `Enter` opens, `Ctrl s` / `Ctrl v` / `Ctrl t` open in a split
/ vertical split / tab, `Tab` previews, `Ctrl x` marks and `Alt Enter` opens all marked, `Esc` closes.

## Code

| Keys                                    | Action                                                    |
| --------------------------------------- | --------------------------------------------------------- |
| `gd` / `gr` / `gi`                      | Go to definition / list references / go to implementation |
| `K`                                     | Show the type and docs under the cursor                   |
| `,rn` / `,ca`                           | Rename the symbol / pick a code action                    |
| `]d` / `[d`, `Ctrl w` `d`               | Next / previous diagnostic; show it in a float            |
| `Ctrl x` `Ctrl o`                       | Complete from the language server                         |
| `Ctrl n` `Ctrl p` / `Ctrl y` / `Ctrl e` | Move in the menu / accept / cancel                        |
| `Alt o`                                 | C and C++: switch between source and header               |

Rust only: `,cl` / `,cd` / `,cb` hide or show line / doc / block comments, `,cc` all of them; `h` / `l` close / open a
fold, or move when there is none.

## Git with Neogit

`,g` (or `:Neogit`) opens the status buffer:

| Keys            | Action                                                                |
| --------------- | --------------------------------------------------------------------- |
| `s` / `u` / `x` | Stage / unstage / discard the file or hunk                            |
| `Tab`           | Fold or unfold the diff                                               |
| `c` `c`         | Commit; `Ctrl c` `Ctrl c` saves the message, `Ctrl c` `Ctrl k` aborts |
| `P` / `p` / `f` | Push / pull / fetch (each opens a menu; pick a target)                |
| `l` / `d`       | Log / diff menus                                                      |
| `?` / `q`       | All keys / close                                                      |

## Terminal

`:terminal` (or `:split | terminal`) opens a shell; `i` starts typing; `jk` or `Esc` goes back to normal mode.
