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
alias lsd='find . -maxdepth 6 -not -path "*/\.*" -type d'
alias lsf='find . -maxdepth 6 -not -path "*/\.*" -type f'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
function c() {
    curl -m 10 "https://cht.sh/$@"
}
alias s='git status -s'
alias l='git l'
alias u='git submodule update --init --recursive'
alias pl='git fetch --recurse-submodules && git pull --recurse-submodules'
alias ps='git push --recurse-submodules=on-demand'
function fmp() {
    pyflakes "$@"
    isort --profile black --atomic --line-length 79 "$@"
    black --verbose --line-length 79 "$@"
}
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
