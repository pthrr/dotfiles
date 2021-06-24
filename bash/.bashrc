alias vi='nvim'
alias top='htop'
alias ack='ag'
alias ls='exa'
alias grep='rg'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias shutdown='systemctl poweroff'
alias reboot='systemctl reboot'
alias lla='ls -la'
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
function fmp() {
    pyflakes "$@"
    isort --profile black --atomic --line-length 79 "$@"
    black --verbose --line-length 79 "$@"
}
alias fmo='dune build @fmt --auto-promote'
alias fmc='clang-format -verbose -i -style=google'
alias cl='clear'
alias py='python3'
alias xdg='xdg-open'
alias jqp='jq "."'
alias pwgen='python -c "import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)"'
export HISTCONTROL=ignoreboth
export PROMPT_DIRTRIM=2
export PS1='\[\e[33m\]\w\[\e[0m\] \u % '
source "$HOME/z.sh"
source "$HOME/key-bindings.bash"
source "$HOME/.cargo/env"
