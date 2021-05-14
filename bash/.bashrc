alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias vi='nvim'
alias top='htop'
alias ack='ag'
alias ls='exa'
alias grep='rg'
alias lla='ls -la'
alias ll='ls -l'
alias lsd='find . -maxdepth 6 -not -path "*/\.*" -type d'
alias lsf='find . -maxdepth 6 -not -path "*/\.*" -type f'
function c() {
    curl -m 10 "https://cht.sh/$@"
}
alias s='git status -s'
alias l='git l'
alias u='git submodule update --init --recursive'
alias pl='git fetch --recurse-submodules && git pull --recurse-submodules'
alias ps='git push --recurse-submodules=on-demand'
function fmp() {
    autoflake --in-place --ignore-init-module-imports "$@"
    isort --atomic "$@"
    black --verbose --target-version py37 --line-length 79 "$@"
}
alias fmc='clang-format -verbose -i -style=google'
alias cl='clear'
alias py='python3'
alias xdg='xdg-open'
alias jqp='jq "."'
alias pwgen='python -c "import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)"'
source "$HOME/z.sh"
#source "$HOME/git-prompt.sh"
export PROMPT_DIRTRIM=2
#export GIT_PS1_SHOWDIRTYSTATE=1
#export PS1='\[\e[33m\]\w\[\e[31m\]$(__git_ps1 "(%s)")\[\e[0m\] % '
export PS1='\[\e[33m\]\w\[\e[0m\] % '
source "$HOME/.cargo/env"
