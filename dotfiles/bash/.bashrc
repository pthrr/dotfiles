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

    if [[ $1 =~ $regex_git ]] ; then
        git cloner "$1"
    elif [[ $1 =~ $regex_url ]] ; then
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
setupgdb()
{
    if [ -e "$GDBSETUP" -a ! -f "$GDBSETUP" ]; then
        printf '%s already exists and is not a file\n' "$GDBSETUP"
        exit 1
    fi
    local _setupgdb_tty=$(tty)
    printf 'dashboard -output %s\n' "$_setupgdb_tty" > "$GDBSETUP"
}
if `command -v tmux > /dev/null`; then
    [ -z "${TMUX+set}" ] || export SESSION=`tmux display-message -p '#S'`
fi
function quit
{
    if `command -v tmux > /dev/null`; then
        tmux kill-session -t $SESSION
    fi
}
function killdetached
{
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
function vrs() {
    shopt -s nullglob
    find . -type f -iname "*.rs" | xargs $EDITOR "$@"
    shopt -u nullglob
}
function ls() {
    local cmd=$(command -v eza || command -v exa || command -v ls)
    $cmd "$@"
}
function lla() {
    local cmd=$(command -v eza || command -v exa)
    $cmd -la --git --classify --color=always "$@" | less
}
function ll() {
    local cmd=$(command -v eza || command -v exa)
    $cmd -l --git --classify --color=always "$@" | less
}
function lls() {
    local cmd=$(command -v eza || command -v exa)
    $cmd -la --git --git-ignore --classify "$@"
}
function lsd() {
    local cmd=$(command -v eza || command -v exa)
    $cmd --tree --long --git --git-ignore --classify --color=always --level 6 -a -D -I ".git|venv|__pycache__|*_cache" "$@" | less
}
function lsf() {
    local cmd=$(command -v eza || command -v exa)
    $cmd --tree --long --git --git-ignore --classify --color=always --level 6 -a -I ".git|venv|__pycache__|*_cache" "$@" | less
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
alias vifm='vifm . .'
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
