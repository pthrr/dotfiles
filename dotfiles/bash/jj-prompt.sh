# bash/zsh jj prompt support
#
# Based on git-prompt.sh but adapted for Jujutsu (jj)
# Optimized for speed - only shows bookmark/change ID
#
# To enable:
#    1) Copy this file to somewhere (e.g. ~/jj-prompt.sh).
#    2) Add the following line to your .bashrc/.zshrc:
#        source ~/jj-prompt.sh
#    3) Call __jj_ps1 as command-substitution in your PS1/PROMPT_COMMAND

# Main prompt function for jj
__jj_ps1 ()
{
    # preserve exit status
    local exit=$?
    local printf_format=' (%s)'

    case "$#" in
        0|1)    printf_format="${1:-$printf_format}"
        ;;
        *)      return $exit
        ;;
    esac

    # Check if we're in a jj repository
    # Use fast check with minimal output
    jj root >/dev/null 2>&1 || return $exit

    # Get bookmark name or change ID in a single call
    # Returns either a bookmark name or change ID (without parens)
    local b=$(jj log --no-graph --no-pager -r @ -T 'coalesce(bookmarks.join(" "), change_id.shortest(8))' 2>/dev/null | head -n1)

    [ -z "$b" ] && return $exit

    printf -- "$printf_format" "$b"
    return $exit
}

