alias vi='nvim'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -Iv'
alias cl='clear'
alias py='python3'
alias xdg='xdg-open'
alias ..='cd ../'
alias ...='cd ../../'
alias ls='ls -la --color=always'
alias lsd='find . -maxdepth 3 -not -path "*/\.*" -type d'
alias lsg='ls | grep'
alias pwgen='python3 -c "import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)"'
source "$HOME/git-prompt.sh"
export PROMPT_DIRTRIM=2
export GIT_PS1_SHOWDIRTYSTATE=1
export PS1='\u@\h:\[\e[33m\]\w\[\e[31m\]$(__git_ps1 "(%s)")\[\e[0m\]\$ '
source "$HOME/.cargo/env"
