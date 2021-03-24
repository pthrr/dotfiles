alias vi='nvim'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias ack='ag'
alias ls='exa -l'
alias grep='rg'
alias lsd='find . -maxdepth 6 -not -path "*/\.*" -type d'
alias s='git status -s'
alias pl='git fetch && git pull'
alias ps='git push'
alias fm='autopep8 --in-place --recursive --aggressive *.py'
alias cl='clear'
alias py='python3'
alias xdg='xdg-open'
alias pwgen='python -c "import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)"'
alias jqp='jq "."'
source "$HOME/z.sh"
source "$HOME/git-prompt.sh"
export PROMPT_DIRTRIM=2
export GIT_PS1_SHOWDIRTYSTATE=1
export PS1='\[\e[33m\]\w\[\e[31m\]$(__git_ps1 "(%s)")\[\e[0m\] % '
source "$HOME/.cargo/env"
