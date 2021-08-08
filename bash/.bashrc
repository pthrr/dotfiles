alias vi='nvim'
alias top='htop'
alias ack='ag'
alias ls='exa'
alias grep='rg'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias shutdown='systemctl poweroff -i'
alias reboot='systemctl reboot -i'
alias lla='ls -la'
alias untar='tar xf'
alias h='history'
alias ll='ls -l'
alias lsd='tree -d -L 6'
alias lsf='tree -a -L 6 -I ".git"'
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
alias ps='g ph'
alias gc='g cleaner' # clean -fdx
function fmp() {
    pyflakes "$@"
    isort --profile black --atomic --line-length 79 "$@"
    black --verbose --line-length 79 "$@"
}
alias fmc='clang-format -verbose -i -style=google'
alias fmo='dune build @fmt --auto-promote --enable-outside-detected-project'
alias cl='clear'
alias vo='vi src/*.*'
alias oc='dune build && dune exec'
alias ot='dune runtest'
function op() {
    dune init proj $@ --libs base,stdio,owl,owl-top,owl-base,owl-plplot,owl-zoo
}
alias py='python3'
alias xdg='xdg-open'
alias jqp='jq "."'
alias mirror='wget --mirror --convert-links --adjust-extension --page-requisites --no-parent'
alias pc='picocom -b 115200 --echo --omap=crcrlf'
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
