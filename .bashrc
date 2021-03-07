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
alias ls='ls -l'
alias lsd='find . -maxdepth 6 -not -path "*/\.*" -type d'
alias lsg='ls | grep'
alias grep='grep -Hn'
alias piprun='pipenv run python'
alias pwgen='python -c "import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)"'
alias jqp='jq "."'
alias matlab-cmd='matlab -batch'
source "$HOME/z.sh"
source "$HOME/git-prompt.sh"
export PROMPT_DIRTRIM=2
export GIT_PS1_SHOWDIRTYSTATE=1
export PS1='\[\e[33m\]\w\[\e[31m\]$(__git_ps1 "(%s)")\[\e[0m\] % '
source "$HOME/.cargo/env"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
