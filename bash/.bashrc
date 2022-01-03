alias vi='nvim'
alias top='htop'
alias ls='exa'
alias cat='bat'
alias grep='rg'
alias less='less -r'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias untar='tar vxf'
alias lla='ls -la --git'
alias ll='ls -l --git'
alias lsd='exa --tree --long --git --color=always --level 6 -D | less'
alias lsf='exa --tree --long --git --color=always --level 6 -a -I '.git' | less'
alias cl='clear'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias g='git'
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
alias fmo='dune build @fmt --auto-promote --enable-outside-detected-project'
alias fmm='cmake-format -i'
alias vp='vi src/*.py'
alias vc='vi src/*.c src/*.cc'
alias vo='vi src/*.ml'
alias oc='dune build && dune exec'
alias ot='dune runtest'
function op() {
    dune init proj $@ --libs base,stdio,owl,owl-top,owl-base,owl-plplot,owl-zoo
}
alias py='python3'
alias xdg='xdg-open'
alias mirror='wget --mirror --convert-links --adjust-extension --page-requisites --no-parent'
alias pc='picocom -b 115200 --echo --omap=crcrlf'
alias ports='lsof -i -P -n | grep LISTEN'
alias pwgen='python -c "import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)"'
export HISTCONTROL=ignoreboth:erasedups
export HISTSIZE=1000
export HISTFILESIZE=2000
export PROMPT_DIRTRIM=2
export PS1='\[\e[33m\]\w\[\e[0m\] \u$(if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then echo " @ \h"; else echo ""; fi) % '
source "$HOME/z.sh"
source "$HOME/key-bindings.bash"
source "$HOME/.cargo/env"
eval $(opam config env)
