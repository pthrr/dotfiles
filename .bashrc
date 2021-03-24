alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias vi='nvim'
alias ack='ag'
alias ls='exa'
alias grep='rg'
alias lsa='ls -la'
alias lsd='find . -maxdepth 6 -not -path "*/\.*" -type d'
alias s='git status -s'
alias pl='git fetch --recurse-submodules && git pull --recurse-submodules'
alias ps='git push --recurse-submodules=on-demand'
alias fm='autopep8 --in-place --recursive --aggressive *.py'
alias cl='clear'
alias py='python3'
alias xdg='xdg-open'
alias jqp='jq "."'
alias pwgen='python -c "import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)"'
source "$HOME/z.sh"
source "$HOME/git-prompt.sh"
export PROMPT_DIRTRIM=2
export GIT_PS1_SHOWDIRTYSTATE=1
export PS1='\[\e[33m\]\w\[\e[31m\]$(__git_ps1 "(%s)")\[\e[0m\] % '
source "$HOME/.cargo/env"
