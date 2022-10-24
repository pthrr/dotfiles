export HISTCONTROL=ignorespace:erasedups
export HISTSIZE=1000
export HISTFILESIZE=2000
export HISTFILE="$XDG_CACHE_HOME/.bash_history"
export PROMPT_DIRTRIM=2
export PS1='\[\e[33m\]\w\[\e[0m\] \u$(if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then echo " @ \h"; else echo ""; fi) % '
function command_not_found_handle() {
    regex_url='(https?|ftp|file)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
    regex_git='.*.git'
    if [[ $1 =~ $regex_git ]]
    then
        git cloner "$1"
    elif [[ $1 =~ $regex_url ]]
    then
        wget "$1"
    fi
}
function fpy() {
    isort --profile black --atomic --line-length 79 "$@"
    black --verbose --line-length 79 "$@"
    pylint "$@"
}
function fcc() {
    clang-format -verbose -i -style=chromium "$@"
    clang-tidy "$@"
}
function vpy() {
    shopt -s nullglob
    nvim src/*.py "$@"
    shopt -u nullglob
}
function vcc() {
    shopt -s nullglob
    nvim src/*.c src/*.cc "$@"
    shopt -u nullglob
}
function lla() {
    exa -la --git --classify --color=always "$@" | less
}
function lls() {
    exa -la --git --classify "$@"
}
function ll() {
    exa -l --git --classify --color=always "$@" | less
}
function lsd() {
    exa --tree --long --git --classify --color=always --level 6 -D -I ".git|venv|__pycache__|*_cache" "$@" | less
}
function lsf() {
    exa --tree --long --git --classify --color=always --level 6 -a -I ".git|venv|__pycache__|*_cache" "$@" | less
}
alias vi='nvim'
alias vim='nvim'
alias top='htop'
alias ls='exa'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias g='git'
alias cl='clear'
alias py='python3'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias mpubl='mutt -F "$HOME/mail/public/muttrc"'
alias mpers='mutt -F "$HOME/mail/personal/muttrc"'
alias jupnote='$BROWSER http://localhost:8888/; jupyter-notebook --no-browser --notebook-dir="$XDG_DOCUMENTS_DIR/notebooks"'
alias mirror='wget --mirror --convert-links --adjust-extension --page-requisites --no-parent'
alias com='picocom -b 115200 --echo --omap=crcrlf'
alias procs='pstree -Ap'
alias ports='sudo netstat -pln'
alias pwgen="python3 -c 'import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)'"
source "$HOME/z.sh"
source "$HOME/key-bindings.bash"
