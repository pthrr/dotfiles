# Setup fzf
# ---------
if [[ ! "$PATH" == */home/pthrr/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/home/pthrr/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/pthrr/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/pthrr/.fzf/shell/key-bindings.zsh"
