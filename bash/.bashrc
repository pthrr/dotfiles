alias vi='nvim'
alias top='htop'
alias ack='ag'
alias ls='exa'
alias grep='rg'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias untar='tar vxf'
alias lla='ls -la'
alias ll='ls -l'
alias lsd='tree -d -L 6 | less'
alias lsf='tree -a -L 6 -I ".git" | less'
alias h='history | less'
alias cl='clear'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
function cht() {
    curl -m 10 "https://cht.sh/$@"
}
alias g='git'
alias s='g ssb'
alias l='g ld'
alias u='g smuir'
alias pl='g frs && git prs'
alias ph='g ph'
alias gc='g cleaner' # clean -fdx
function gmv() { # move submodule
    mv $1 $2
    git rm $1
    git add $2
    git submodule sync
}
function fmp() {
    isort --profile black --atomic --line-length 79 "$@"
    black --verbose --line-length 79 "$@"
    pyflakes "$@"
}
alias fmc='clang-format -verbose -i -style=google'
alias fmo='dune build @fmt --auto-promote --enable-outside-detected-project'
alias fmm='cmake-format -i'
alias vs='vi src/*.*'
alias oc='dune build && dune exec'
alias ot='dune runtest'
function op() {
    dune init proj $@ --libs base,stdio,owl,owl-top,owl-base,owl-plplot,owl-zoo
}
alias py='python3'
alias xdg='xdg-open'
alias jqp='jq "."'
alias lrts='sudo watch -n 1 "journalctl -u rts -u lxi -u nginx -u mdns | tail -n $(($LINES - 15))"'
alias mirror='wget --mirror --convert-links --adjust-extension --page-requisites --no-parent'
alias pc='picocom -b 115200 --echo --omap=crcrlf'
alias ports='lsof -i -P -n | grep LISTEN'
alias pwgen='python -c "import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)"'
export HISTCONTROL=ignoreboth
export HISTSIZE=1000
export HISTFILESIZE=2000
export PROMPT_DIRTRIM=2
export PS1='\[\e[33m\]\w\[\e[0m\] \u$(if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then echo " @ \h"; else echo ""; fi) % '
source "$HOME/z.sh"
source "$HOME/key-bindings.bash"
source "$HOME/.cargo/env"
eval $(opam config env)
