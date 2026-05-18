export COLORTERM=truecolor

export PATH="/usr/local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

. "$HOME/.cargo/env"

eval "$(starship init bash)"
source -- ~/.local/share/blesh/ble.sh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export LD_LIBRARY_PATH=/opt/conda/lib:$LD_LIBRARY_PATH

alias gemini='gemini --yolo'

alias ls="eza --color=always --icons=always"
alias ll="eza -la --icons=always"
alias lt="eza --tree --icons=always"

alias re="source ~/.bashrc"
export BAT_THEME="gruvbox-dark"

git-acp() {
    if [ -z "$1" ]; then
        echo "Error: Commit message required."
        echo "Usage: git-acp \"Your commit message\""
        return 1
    fi
    git add -A
    git commit -m "$1"
    git push origin main
}