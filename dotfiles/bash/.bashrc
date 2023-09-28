export HISTCONTROL=ignorespace:erasedups
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTFILE="$XDG_CACHE_HOME/.bash_history"
export PROMPT_DIRTRIM=2
export PROMPT_COMMAND='LAST_STATUS=$(if [[ $? == 0 ]]; then echo "✓"; else echo "✗"; fi);GIT_BRANCH=$(__git_ps1)'
export PS1='\[\e[33m\]\w\[\e[0m\] \u$(if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then echo " @ \h"; else echo ""; fi)$GIT_BRANCH $LAST_STATUS '
export PS4='$0.$LINENO: '
function command_not_found_handle() {
    regex_url='(https?|ftp|file)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
    regex_git='.*.git'

    if [[ $1 =~ $regex_git ]] ; then
        git cloner "$1"
    elif [[ $1 =~ $regex_url ]] ; then
        wget "$1"
    else
        echo "Command was not found!"
    fi
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
alias em='emacs'
alias na='nano'
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
alias py='python'
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
alias pwgen='pb keepassxc-cli generate --lower --upper --numeric --special --length 32'
alias mksomespace='nix-collect-garbage -d'
alias dotfiles='git --git-dir="$HOME/.dotfiles/.git" --work-tree="$HOME/.dotfiles"'
source "$HOME/key-bindings.bash"
source "$HOME/z.sh"
source "$HOME/git-prompt.sh"
