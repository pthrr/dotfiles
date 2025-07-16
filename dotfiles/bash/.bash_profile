# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# User specific environment and startup programs
if command -v kwriteconfig6 &> /dev/null; then
    kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatDelay 300
    kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatRate 50
    kwriteconfig6 --file kxkbrc --group Layout --key Options "caps:none"
elif command -v kwriteconfig5 &> /dev/null; then
    kwriteconfig5 --file kcminputrc --group Keyboard --key RepeatDelay 300
    kwriteconfig5 --file kcminputrc --group Keyboard --key RepeatRate 50
    kwriteconfig5 --file kxkbrc --group Layout --key Options "caps:none"
fi
