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

8z() {
    if [ -z "$1" ]; then
        echo "Error: Directory name required."
        echo "Usage: 8z <dirname>"
        return 1
    fi
    local target="${1%/}"
    7z a "${target}.7z" "$target" -t7z -m0=lzma2 -mx=9 -mfb=273 -md=1536m -ms=on -mqs=on -mmt=4
}

6z() {
    if [ -z "$1" ]; then
        echo "Error: Directory name required."
        echo "Usage: 6z <dirname>"
        return 1
    fi
    local target="${1%/}"
    7z a "${target}.7z" "$target" -t7z -m0=lzma2 -mx=1 -ms=off -mmt=4
}