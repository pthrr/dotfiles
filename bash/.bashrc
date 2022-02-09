export HISTCONTROL=ignorespace:erasedups
export HISTSIZE=1000
export HISTFILESIZE=2000
export PROMPT_DIRTRIM=2
export PS1='\[\e[33m\]\w\[\e[0m\] \u$(if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then echo " @ \h"; else echo ""; fi) % '
function cht() {
    curl -m 10 "https://cht.sh/$@"
}
function gmv() { # move submodule
    mv $1 $2
    git rm $1
    git add $2
    git submodule sync
}
function fpy() {
    isort --profile black --atomic --line-length 79 "$@"
    black --verbose --line-length 79 "$@"
    pylint "$@"
}
function fcc() {
    clang-format -verbose -i -style=google "$@"
    clang-tidy "$@"
}
function fcm() {
    cmake-format -i "$@"
}
function foc() {
    ocamlformat --inplace --enable-outside-detected-project "$@"
}
function ioc() {
    dune init proj "$@" --libs "base,stdio,owl,owl-top,owl-base,owl-plplot"
}
function roc() {
    dune build && dune exec "$@"
}
function toc() {
    dune test "$@"
}
function lla() {
    exa -la --git --color=always "$@" | less
}
function ll() {
    exa -l --git --color=always "$@" | less
}
function lsd() {
    exa --tree --long --git --color=always --level 6 -D "$@" | less
}
function lsf() {
    exa --tree --long --git --color=always --level 6 -a -I '.git' "$@" | less
}
function vp() {
    shopt -s nullglob
    nvim src/*.py "$@"
    shopt -u nullglob
}
function vc() {
    shopt -s nullglob
    nvim src/*.c src/*.cc "$@"
    shopt -u nullglob
}
function vo() {
    shopt -s nullglob
    nvim bin/*.ml lib/*.ml test/*.ml "$@"
    shopt -u nullglob
}
alias vi='nvim'
alias g='git'
alias top='htop'
alias ls='exa'
alias cat='bat'
alias grep='rg'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias untar='tar vxf'
alias un7z='7z x'
alias cl='clear'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias py='python3'
alias xdg='xdg-open'
alias mirror='wget --mirror --convert-links --adjust-extension --page-requisites --no-parent'
alias com='picocom -b 115200 --echo --omap=crcrlf'
alias ports='sudo netstat -pln'
alias pwgen="python -c 'import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)'"
source "$HOME/z.sh"
source "$HOME/key-bindings.bash"
source "$HOME/.cargo/env"
eval $(opam config env)