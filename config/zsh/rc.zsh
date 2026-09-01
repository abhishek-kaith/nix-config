# Interactive zsh config — editable; sourced by the home-manager-managed .zshrc.
# Apply changes by opening a new shell (or: source ~/.zshrc).
bindkey -v
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey -s '^f' '~/.scripts/tmux-sessionizer\n'

# ── colours: follow the terminal, don't fight it ─────────────────────
# bat ships truecolor themes (default: Monokai) that ignore the terminal palette
# entirely, so file previews sat in their own colour scheme regardless of what
# alacritty was set to. The "ansi" theme makes bat draw with the terminal's own
# 16 colours instead — so it matches, and it follows automatically when
# cosmic-theme-sync swaps the palette for light mode. delta reads BAT_THEME too,
# so `git diff` comes along with it.
export BAT_THEME=ansi
