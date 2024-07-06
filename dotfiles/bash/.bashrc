# set PATH so it includes bin if it exists
if [ -d "/usr/sbin" ]; then
    export PATH="/usr/sbin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ]; then
    export PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# include Rust environment
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

if [ -d "$HOME/.cargo/bin" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# include Haskell environment
if [ -d "$HOME/.cabal/bin" ]; then
    export PATH="$HOME/.cabal/bin:$PATH"
fi

# include LV2 plugins
if [ -d "$HOME/.lv2" ]; then
    export LV2_PATH="$HOME/.lv2:$LV2_PATH"
fi

if [ -d "$HOME/.nix-profile/lib/lv2" ]; then
    export LV2_PATH="$HOME/.nix-profile/lib/lv2:$LV2_PATH"
fi

# include Nix environment
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

# include pyenv
if command -v pyenv >/dev/null 2>&1; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
fi

# create standard dirs
if [ ! -d "$HOME/.lv2" ]; then
    mkdir "$HOME/.lv2" 2>/dev/null
fi

if [ ! -d "$HOME/.clap" ]; then
    mkdir "$HOME/.clap" 2>/dev/null
fi

if [ ! -d "$HOME/tmp" ]; then
    mkdir "$HOME/tmp" 2>/dev/null
fi

if [ ! -d "$HOME/bin" ]; then
    mkdir "$HOME/bin" 2>/dev/null
fi

if [ ! -d "$HOME/opt" ]; then
    mkdir "$HOME/opt" 2>/dev/null
fi

if [ ! -d "$HOME/datasets" ]; then
    mkdir "$HOME/datasets" 2>/dev/null
fi

if [ ! -d "$HOME/fun" ]; then
    mkdir "$HOME/fun" 2>/dev/null
fi

if [ ! -d "$HOME/analysis" ]; then
    mkdir "$HOME/analysis" 2>/dev/null
fi

if [ ! -d "$HOME/business" ]; then
    mkdir "$HOME/business" 2>/dev/null
fi

if [ ! -d "$HOME/job" ]; then
    mkdir "$HOME/job" 2>/dev/null
fi

if [ ! -d "$HOME/Drive" ]; then
    mkdir "$HOME/Drive" 2>/dev/null
fi

if [ ! -d "$HOME/Dokumente/notes" ]; then
    mkdir -p "$HOME/Dokumente/notes" 2>/dev/null
fi

if [ ! -d "$HOME/Dokumente/notebooks" ]; then
    mkdir -p "$HOME/Dokumente/notebooks" 2>/dev/null
fi

if [ ! -d "$HOME/Dokumente/letters" ]; then
    mkdir -p "$HOME/Dokumente/letters" 2>/dev/null
fi

if [ ! -d "$HOME/Vorlagen/slides" ]; then
    mkdir -p "$HOME/Vorlagen/slides" 2>/dev/null
fi

if [ ! -d "$HOME/Vorlagen/snippets" ]; then
    mkdir -p "$HOME/Vorlagen/snippets" 2>/dev/null
fi

if [ ! -d "$HOME/Audio" ]; then
    mkdir -p "$HOME/Audio" 2>/dev/null
fi

export LANG=de_DE.UTF-8
export LC_ALL=C.UTF-8
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DESKTOP_DIR="$HOME/Schreibtisch"
export XDG_DOCUMENTS_DIR="$HOME/Dokumente"
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export XDG_MUSIC_DIR="$HOME/Musik"
export XDG_AUDIO_DIR="$HOME/Audio"
export XDG_PICTURES_DIR="$HOME/Bilder"
export XDG_PUBLICSHARE_DIR="$HOME/Öffentlich"
export XDG_TEMPLATES_DIR="$HOME/Vorlagen"
export XDG_VIDEOS_DIR="$HOME/Video"
export SHELL='bash'
export EDITOR='nvim'
export BROWSER='firefox'
export MAILCLIENT='thunderbird'
export TERMINAL='foot'
export PDFVIEWER='zathura'
export IMAGEVIEWER='nsxiv'
export MEDIAPLAYER='vlc'
export FILEMANAGER='spacefm'
export FZF_DEFAULT_COMMAND='rg --files'
export FZF_DEFAULT_OPTS='-m --height 50% --border'
export SYSTEMC_HOME='$HOME/opt/systemc'
export LESS='-r'
export NO_AT_BRIDGE=1
export DO_NOT_TRACK=1
export _JAVA_AWT_WM_NONREPARENTING=1
export MC_XDG_OPEN="$HOME/bin/xdg"
export MC_SKIN="$HOME/.config/mc/solarized.ini"
export QT_LOGGING_RULES="kwin_*.debug=true"
export CPM_SOURCE_CACHE="$XDG_CACHE_HOME/CPM"
export TMPDIR="/tmp"
export SYSTEMC_HOME="/opt/systemc"
export SYSTEMC_AMS_HOME="/opt/systemc-ams"
export ICSC_HOME="$HOME/opt/sc_tools"
export HISTCONTROL=ignorespace:erasedups
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTFILE="$XDG_CACHE_HOME/.bash_history"
export PROMPT_DIRTRIM=2
export PROMPT_COMMAND='LAST_STATUS=$(if [[ $? == 0 ]]; then echo "✓"; else echo "✗"; fi);NIX_SHELL=$(if [ ! -z "$IN_NIX_SHELL" ]; then echo " (nix-shell)"; else echo ""; fi);GIT_BRANCH=$(__git_ps1)'
export PS1='\[\e[33m\]\w\[\e[0m\] \u$(if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then echo " @ \h"; else echo ""; fi)${GIT_BRANCH}${NIX_SHELL} $LAST_STATUS '
export PS4='$0.$LINENO: '
function command_not_found_handle() {
    regex_url='(https?|ftp|file)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
    regex_git='.*.git'

    if [[ $1 =~ $regex_git ]]; then
        git cloner "$1"
    elif [[ $1 =~ $regex_url ]]; then
        wget "$1"
    else
        echo "Command was not found: ${1}"
    fi
}
# eval "$(_TMUXP_COMPLETE=source tmuxp)"
# _tmuxp_project_completions() {
#     local word
#     local files=$(ls $HOME/.tmuxp/${COMP_WORDS[1]}*.yaml 2> /dev/null)
#     for f in $files; do
#         COMPREPLY+=($(basename "$f" .yaml))
#     done
#     if [ "$COMP_CWORD" -gt 1 ]; then
#         local offset=0
#         for (( i=1; i < COMP_CWORD; i++ )); do
#             word="${COMP_WORDS[i]}"
#             if [ "$word" != -* ]; then
#                 offset=$(printf "$i + 1" | bc)
#                 break
#             fi
#         done
#         if [ $offset -ne 0 ]; then
#             COMPREPLY=()
#             _command_offset "$offset"
#         fi
#     fi
# }
# alias mux='tmuxp load'
# complete -F _tmuxp_project_completions mux
export GDBSETUP=".gdbsetup"
setupgdb() {
    if [ -e "$GDBSETUP" -a ! -f "$GDBSETUP" ]; then
        printf '%s already exists and is not a file\n' "$GDBSETUP"
        exit 1
    fi
    local _setupgdb_tty=$(tty)
    printf 'dashboard -output %s\n' "$_setupgdb_tty" >"$GDBSETUP"
}
if $(command -v tmux >/dev/null); then
    [ -z "${TMUX+set}" ] || export SESSION=$(tmux display-message -p '#S')
fi
function quit {
    if $(command -v tmux >/dev/null); then
        tmux kill-session -t $SESSION
    fi
}
function killdetached {
    tmux list-sessions | grep -E -v '\(attached\)$' - | while IFS='\n' read line; do
        line="${line#*:}"
        tmux kill-session -t "${line%%:*}"
    done
}
function vo() {
    shopt -s nullglob
    $EDITOR "$@"
    shopt -u nullglob
}
function ls() {
    local cmd=$(command -v eza || command -v exa || command -v ls)
    $cmd "$@"
}
function ll() {
    local cmd=$(command -v eza || command -v exa)
    $cmd -l --classify --color=always "$@" | less
}
function lla() {
    local cmd=$(command -v eza || command -v exa)
    $cmd -la --classify --color=always "$@" | less
}
function lls() {
    local cmd=$(command -v eza || command -v exa)
    $cmd -la --classify "$@"
}
function lsd() {
    local cmd=$(command -v eza || command -v exa)
    $cmd --tree --long --classify --color=always --level 6 -a -D -I ".git|venv|__pycache__|*_cache" "$@" | less
}
function lsf() {
    local cmd=$(command -v eza || command -v exa)
    $cmd --tree --long --classify --color=always --level 6 -a -I ".git|venv|__pycache__|*_cache" "$@" | less
}
function fgs() {
    if command -v fd >/dev/null 2>&1; then
        fd -t d -HI "\.git$" "$@" | while read -r dir; do
            git -C "$(dirname "$dir")" status -s | grep -q . && pwd
        done
    else
        find . -type d -name .git "$@" -exec "cd \"{}\"/../ && git status -s | grep -q . && pwd" \;
    fi
}
function pmd() {
    pandoc -t plain "$@" | less
}
function pb() {
    "$@" | pbcopy
}
function kppw() {
    keepassxc-cli clip "$(kpdb)" "$@"
}
function kpusr() {
    pb keepassxc-cli search "$(kpdb)" "$@"
}
function jupnote() {
    killall "jupyter-lab"
    jupyter-lab --no-browser --notebook-dir="${@:-"$XDG_DOCUMENTS_DIR/notebooks"}" &
    sleep 2
    $BROWSER http://localhost:8888/
}
set -o vi
alias vi='nvim'
alias vim='nvim'
alias fm='mc . .'
alias top='htop'
alias cat='bat'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias g='git'
alias t='task'
alias j='jobs'
alias c='clear'
alias py='python3'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias pbclear='echo "" | pbcopy'
alias pbclean='pbpaste | pbcopy'
alias yt='yt-dlp --recode-video mp4'
alias mirror='wget --mirror --convert-links --adjust-extension --page-requisites --no-parent'
alias com='picocom -b 115200 --echo --omap=crcrlf'
alias procs='pstree -Ap'
alias ports='netstat -pln'
alias weather='curl wttr.in/munich'
alias wifi='nmcli dev wifi show-password'
alias ddg='w3m lite.duckduckgo.com'
alias pwgen='pb keepassxc-cli generate --lower --upper --numeric --special --length 32'
alias mksomespace='nix-collect-garbage -d'
alias dotfiles='git --git-dir="$HOME/.dotfiles/.git" --work-tree="$HOME/.dotfiles"'
source "$HOME/key-bindings.bash"
source "$HOME/z.sh"
source "$HOME/git-prompt.sh"
source "$ICSC_HOME/setenv.sh"
