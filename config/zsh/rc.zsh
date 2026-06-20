# Interactive zsh config — editable; sourced by the home-manager-managed .zshrc.
# Apply changes by opening a new shell (or: source ~/.zshrc).
bindkey -v
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey -s '^f' '~/.scripts/tmux-sessionizer\n'
