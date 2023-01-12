export HISTCONTROL=ignorespace:erasedups
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTFILE="$XDG_CACHE_HOME/.bash_history"
export PROMPT_DIRTRIM=2
export PS1='\[\e[33m\]\w\[\e[0m\] \u$(if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then echo " @ \h"; else echo ""; fi) % '
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
function fpy() {
    isort --profile black --atomic "$@"
    black --verbose "$@"
    pylint "$@"
}
function fcc() {
    clang-format -verbose -i -style=webkit "$@"
    clang-tidy "$@"
}
function vo() {
    shopt -s nullglob
    $EDITOR "$@"
    shopt -u nullglob
}
function lla() {
    exa -la --git --classify --color=always "$@" | less
}
function ll() {
    exa -l --git --classify --color=always "$@" | less
}
function lls() {
    exa -la --git --git-ignore --classify "$@"
}
function lsd() {
    exa --tree --long --git --git-ignore --classify --color=always --level 6 -a -D -I ".git|venv|__pycache__|*_cache" "$@" | less
}
function lsf() {
    exa --tree --long --git --git-ignore --classify --color=always --level 6 -a -I ".git|venv|__pycache__|*_cache" "$@" | less
}
function pb() {
    "$@" | pbcopy
}
function kppw() {
    keepassxc-cli clip "$( kpdb )" "$@"
}
function kpusr() {
    keepassxc-cli lookup "$( kpdb )" "$@"
}
set -o vi
alias vi='nvim'
alias vim='nvim'
alias top='htop'
alias ls='exa'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias g='git'
alias t='task'
alias cl='clear'
alias py='python'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias pbclear='echo "" | pbcopy'
alias pbclean='pbpaste | pbcopy'
alias spot='pidof -q spotifyd || spotifyd; spt'
alias mpubl='mutt -F "$HOME/mail/public/muttrc"'
alias mpers='mutt -F "$HOME/mail/personal/muttrc"'
alias jupnote='$BROWSER http://localhost:8888/; jupyter-notebook --no-browser --notebook-dir="$XDG_DOCUMENTS_DIR/notebooks"'
alias yt='youtube-dl --recode-video mp4'
alias mirror='wget --mirror --convert-links --adjust-extension --page-requisites --no-parent'
alias com='picocom -b 115200 --echo --omap=crcrlf'
alias procs='pstree -Ap'
alias ports='netstat -pln'
alias pwgen='pb keepassxc-cli generate --lower --upper --numeric --special --length 32'
alias dotfiles='git --git-dir="$HOME/.dotfiles/.git" --work-tree="$HOME/.dotfiles"'
source "$HOME/z.sh"
source "$HOME/key-bindings.bash"
