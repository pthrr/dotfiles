# If you come from bash you might have to change your $PATH.
export GOROOT=$HOME/opt/go
export GOPATH=$HOME/Code/Go
export PATH=$HOME/.cargo/bin:$GOROOT/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
#export PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH

# Path to your oh-my-zsh installation.
export ZSH=/home/pthrr/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME=powerlevel10k/powerlevel10k

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="false"

# Uncomment the following line to change how often to auto-update (in days).
export UPDATE_ZSH_DAYS=30

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
#COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(z sudo extract)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=de_DE.UTF-8

# make sudo -A possible
export SUDO_ASKPASS=/usr/bin/ssh-askpass

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

export EDITOR=nvim

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Replacements
alias sed="sd"
alias ps="procs"
alias locate="ix"
alias cp='cp -iv' # Preferred 'cp' implementation
alias mv='mv -iv' # Preferred 'mv' implementation
alias mkdir='mkdir -pv' # Preferred 'mkdir' implementation
alias less='less -FSRXc' # Preferred 'less' implementation
alias diff="colordiff"
alias rm="rm -Iv"
alias cat="bat"
alias ls="exa -la"
alias grep="rg"
alias find="fd"
alias top="htop"
alias vim="nvim"
alias vi="nvim"
# Shortcuts
alias zshconfig="nvim ~/.zshrc"
alias ohmyzsh="nvim ~/.oh-my-zsh"
alias xdg="xdg-open"
alias todo="python3 ~/Code/Python/todo/run.py"
alias py3="python3"
alias py="python"
alias py2="python2"
alias cl="clear"
alias nvimconfig="nvim ~/.config/nvim/init.vim"
alias gitconfig="nvim ~/.gitconfig"
alias lsg="ll | grep"
alias i3config="nvim ~/.config/i3/config"
alias i3statusconfig="nvim ~/.config/i3/i3status.conf"
alias df="pydf"
alias d="dirs -v"
alias h="history"
alias pyr="python3 run.py"
alias bc="bc -l"
alias ports="netstat -tulanp"
alias ln="ln -iv"
alias hex="xxd"
alias cht="cht.sh"
alias cf="cd ~/Code/Codeforces"
alias bw="cd ~/Nextcloud/to_Cloud/Documents/Bewerbungen"
alias ar="cd ~/Projects/automotive-radar/automotive-radar"
alias mcu="sudo nodemcu-tool terminal"
alias rt="cd ~/Code/C++/RT_Cpp"
alias m="make"
alias mc="make clean"
alias mr="./bin/main"
# Tools
alias lso="ls -la | awk '{k=0;for(i=0;i<=8;i++)k+=((substr(\$1,i+2,1)~/[rwx]/)*2^(8-i));if(k)printf(\" %0o \",k);print}'"
alias lsd="find -d 3 -t d -E \"*/.git/*\" ."

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

