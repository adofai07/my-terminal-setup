#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
readonly C_BLUE="\033[1;34m"
readonly C_GREEN="\033[1;32m"
readonly C_YELLOW="\033[1;33m"
readonly C_RED="\033[1;31m"
readonly C_RESET="\033[0m"


# Check for root/sudo privileges
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root. Please use sudo." 
   exit 1
fi

# ---------------------------------------------------------------------------
# setup.bash — Post-launch notebook setup for KakaoCloud NIPA GPU notebooks
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $0 --user-name <name> [--ssh-public-key "<key1>" ["<key2>" ...]] [--chown-homedir]

Required:
  --user-name       The Linux user name for this notebook (e.g. kyungminkim)

Optional:
  --ssh-public-key  One or more SSH public keys to add to authorized_keys
                    (space-separated, each key quoted). If omitted, SSH is
                    still configured but no keys are added.
  --chown-homedir   Recursively fix ownership of the entire home directory
                    in step 4. Off by default because scanning large home
                    directories (conda envs, datasets) is slow; the script
                    always chowns the paths it creates itself. Use this the
                    first time you set up, or when ownership is suspect.
  -h, --help        Show this help message
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
USER_NAME=""
SSH_KEYS=()
CHOWN_HOMEDIR=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user-name)
            [[ -z "${2:-}" ]] && { echo "ERROR: --user-name requires a value"; usage; }
            USER_NAME="$2"
            shift 2
            ;;
        --ssh-public-key)
            shift
            if [[ $# -eq 0 || "$1" == --* ]]; then
                echo "ERROR: --ssh-public-key requires at least one key value"
                usage
            fi
            while [[ $# -gt 0 && "$1" != --* ]]; do
                SSH_KEYS+=("$1")
                shift
            done
            ;;
        --chown-homedir)
            CHOWN_HOMEDIR=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            usage
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Interactive Configuration Prompts
# ---------------------------------------------------------------------------
echo "==> Please confirm or overwrite configuration:"

read -p "    Linux user name [${USER_NAME}]: " input_user_name
USER_NAME="${input_user_name:-$USER_NAME}"

while [[ -z "$USER_NAME" ]]; do
    read -p "    User name cannot be empty. Please enter a user name: " input_user_name
    USER_NAME="${input_user_name:-$USER_NAME}"
done

read -p "    Chown homedir (0/1) [${CHOWN_HOMEDIR}]: " input_chown
CHOWN_HOMEDIR="${input_chown:-$CHOWN_HOMEDIR}"

echo "    SSH public keys currently configured: ${#SSH_KEYS[@]}"
echo "    Enter SSH public keys one by one. Leave blank and press Enter when done."
if [[ ${#SSH_KEYS[@]} -gt 0 ]]; then
    read -p "    Clear existing keys parsed from arguments? (y/N) [N]: " clear_keys
    if [[ "$clear_keys" =~ ^[Yy]$ ]]; then
        SSH_KEYS=()
    fi
fi

while true; do
    read -p "    Add SSH public key (or Enter to finish): " new_key
    if [[ -z "$new_key" ]]; then
        break
    fi
    SSH_KEYS+=("$new_key")
done

if [[ ${#SSH_KEYS[@]} -eq 0 ]]; then
    echo "    (no SSH keys provided — skipping key addition to authorized_keys)"
fi

echo ""
echo "==> Git Configuration (Optional, press Enter to skip):"
read -p "    Git Display Name (e.g. John Doe): " GIT_DISPLAY_NAME
read -p "    Git Email (e.g. john@example.com): " GIT_EMAIL
read -p "    GitHub Username: " GITHUB_USERNAME
read -s -p "    GitHub Token/Password: " GITHUB_TOKEN
echo ""
echo ""

HOME_DIR="/home/${USER_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

echo "==> Setup configuration:"
echo "    user-name    : ${USER_NAME}"
echo "    home-dir     : ${HOME_DIR}"
if [[ ${#SSH_KEYS[@]} -gt 0 ]]; then
    echo "    ssh keys     : ${#SSH_KEYS[@]} key(s)"
else
    echo "    ssh keys     : (none — will skip key addition)"
fi
echo ""

# ---------------------------------------------------------------------------
# Step tracking
# ---------------------------------------------------------------------------
TOTAL_STEPS=$(grep -c "^# @STEP" "$0")
CURRENT_STEP=0

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo "==> [${CURRENT_STEP}/${TOTAL_STEPS}] $1 ..."
}

# ---------------------------------------------------------------------------
# @STEP
# Change user's home directory to /home/{user-name}
# ---------------------------------------------------------------------------
print_step "Setting home directory to ${HOME_DIR}"
mkdir -p "${HOME_DIR}"
if id "${USER_NAME}" &>/dev/null; then
    sudo usermod -d "${HOME_DIR}" "${USER_NAME}"
else
    echo "    User '${USER_NAME}' does not exist — creating ..."
    sudo useradd -d "${HOME_DIR}" -g users -s /bin/bash "${USER_NAME}"
fi
echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Grant passwordless sudo to the user
# ---------------------------------------------------------------------------
print_step "Granting passwordless sudo to ${USER_NAME}"
# sudoers.d ignores files containing '.' or ending in '~' — use underscores
SUDOERS_FILENAME="${USER_NAME//./_}"
SUDOERS_FILE="/etc/sudoers.d/${SUDOERS_FILENAME}"
echo "${USER_NAME} ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee "${SUDOERS_FILE}" > /dev/null
sudo chmod 440 "${SUDOERS_FILE}"
echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Set up SSH authorized_keys
# ---------------------------------------------------------------------------
print_step "Setting up SSH authorized_keys"
SSH_DIR="${HOME_DIR}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

sudo mkdir -p "${SSH_DIR}"

if [[ ${#SSH_KEYS[@]} -gt 0 ]]; then
    for KEY in "${SSH_KEYS[@]}"; do
        # Avoid duplicate entries
        if sudo grep -qF "$KEY" "${AUTH_KEYS}" 2>/dev/null; then
            echo "    Key already present, skipping: ${KEY:0:40}..."
        else
            echo "$KEY" | sudo tee -a "${AUTH_KEYS}" > /dev/null
            echo "    Added key: ${KEY:0:40}..."
        fi
    done
else
    echo "    No SSH keys provided — skipping key addition."
fi
echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Fix ownership and permissions
# ---------------------------------------------------------------------------
print_step "Fixing ownership and permissions"
if [[ ${CHOWN_HOMEDIR} -eq 1 ]]; then
    echo "    --chown-homedir set — scanning ${HOME_DIR} for wrong ownership ..."
    # Only chown files that don't already have the correct ownership
    sudo find "${HOME_DIR}" \( ! -user "${USER_NAME}" -o ! -group users \) -exec chown "${USER_NAME}:users" {} +
else
    # Default: only chown the paths this script itself creates/modifies
    sudo chown "${USER_NAME}:users" "${HOME_DIR}" "${SSH_DIR}"
    [[ -f "${AUTH_KEYS}" ]] && sudo chown "${USER_NAME}:users" "${AUTH_KEYS}"
fi
sudo chmod 755 "${HOME_DIR}"
sudo chmod 700 "${SSH_DIR}"
[[ -f "${AUTH_KEYS}" ]] && sudo chmod 600 "${AUTH_KEYS}"
echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Disable password authentication in sshd_config
# ---------------------------------------------------------------------------
print_step "Disabling SSH password authentication"
SSHD_CONFIG="/etc/ssh/sshd_config"

if [[ -f "${SSHD_CONFIG}" ]]; then
    # Replace or append PasswordAuthentication
    if sudo grep -qE "^\s*#?\s*PasswordAuthentication" "${SSHD_CONFIG}"; then
        sudo sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication no/' "${SSHD_CONFIG}"
    else
        echo "PasswordAuthentication no" | sudo tee -a "${SSHD_CONFIG}" > /dev/null
    fi

    # Replace or append KbdInteractiveAuthentication
    if sudo grep -qE "^\s*#?\s*KbdInteractiveAuthentication" "${SSHD_CONFIG}"; then
        sudo sed -i 's/^\s*#\?\s*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' "${SSHD_CONFIG}"
    else
        echo "KbdInteractiveAuthentication no" | sudo tee -a "${SSHD_CONFIG}" > /dev/null
    fi

    echo "    Restarting SSH service ..."
    sudo service ssh stop >/dev/null 2>&1 || true
    sudo service ssh start >/dev/null 2>&1 || true
else
    echo "    SSHD config not found at ${SSHD_CONFIG}, skipping."
fi
echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Update and install essential packages
# ---------------------------------------------------------------------------
print_step "Updating apt and installing essential packages"

# Ensure prerequisites for adding repositories are installed
echo "    Installing prerequisites for adding repositories ..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common curl gnupg lsb-release

# Add fastfetch PPA
echo "    Adding Fastfetch repository ..."
sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch

# Add Charm (glow) repository
echo "    Adding Charm repository ..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null

# Add Docker repository
echo "    Adding Docker repository ..."
sudo mkdir -p /etc/apt/keyrings
curl --retry 5 -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-change-held-packages \
    adduser \
    apt \
    apt-transport-https \
    autossh \
    base-files \
    base-passwd \
    bash \
    bsdutils \
    build-essential \
    bzip2 \
    ca-certificates \
    coreutils \
    cuda-command-line-tools-13-0 \
    cuda-compat-13-0 \
    cuda-cudart-13-0 \
    cuda-cudart-dev-13-0 \
    cuda-keyring \
    cuda-libraries-13-0 \
    cuda-libraries-dev-13-0 \
    cuda-minimal-build-13-0 \
    cuda-nsight-compute-13-0 \
    cuda-nvml-dev-13-0 \
    cuda-nvtx-13-0 \
    curl \
    dash \
    debconf \
    debianutils \
    diffutils \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    dpkg \
    e2fsprogs \
    fastfetch \
    findutils \
    fzf \
    gawk \
    glow \
    gcc \
    gcc-12-base \
    gh \
    git \
    gmp-ecm \
    gnupg \
    gnupg2 \
    gpgv \
    grep \
    gzip \
    hostname \
    htop \
    init-system-helpers \
    jq \
    kiwix-tools \
    libacl1 \
    libapt-pkg6.0 \
    libattr1 \
    libaudit-common \
    libaudit1 \
    libblkid1 \
    libbz2-1.0 \
    libc-bin \
    libc6 \
    libcap-ng0 \
    libcap2 \
    libcom-err2 \
    libcrypt1 \
    libcublas-13-0 \
    libcublas-dev-13-0 \
    libcusparse-13-0 \
    libcusparse-dev-13-0 \
    libdb5.3 \
    libdebconfclient0 \
    libeigen3-dev \
    libext2fs2 \
    libffi-dev \
    libffi8 \
    libgcc-s1 \
    libgcrypt20 \
    libgmp-dev \
    libgmp10 \
    libgnutls30 \
    libgpg-error0 \
    libgssapi-krb5-2 \
    libhogweed6 \
    libidn2-0 \
    libjpeg-dev \
    libk5crypto3 \
    libkeyutils1 \
    libkrb5-3 \
    libkrb5-dev \
    libkrb5support0 \
    liblz4-1 \
    liblzma5 \
    libmount1 \
    libmpfr-dev \
    libnccl-dev \
    libnccl2 \
    libncurses6 \
    libncursesw6 \
    libnettle8 \
    libnpp-13-0 \
    libnpp-dev-13-0 \
    libnsl2 \
    libp11-kit0 \
    libpam-modules \
    libpam-modules-bin \
    libpam-runtime \
    libpam0g \
    libpcre2-8-0 \
    libpcre3 \
    libseccomp2 \
    libselinux1 \
    libsemanage-common \
    libsemanage2 \
    libsepol2 \
    libsmartcols1 \
    libss2 \
    libssl-dev \
    libssl3 \
    libstdc++6 \
    libsystemd0 \
    libtasn1-6 \
    libtinfo6 \
    libtirpc-common \
    libtirpc3 \
    libudev1 \
    libuuid1 \
    libxxhash0 \
    libzstd1 \
    lmodern \
    locales \
    login \
    logsave \
    lsb-base \
    lsb-release \
    mawk \
    mount \
    nano \
    ncurses-base \
    ncurses-bin \
    neovim \
    net-tools \
    npm \
    p7zip-full \
    p7zip-rar \
    pandoc \
    passwd \
    perl-base \
    procps \
    python3-dev \
    python3-pip \
    rclone \
    rsync \
    sed \
    sensible-utils \
    software-properties-common \
    sudo \
    sysvinit-utils \
    tar \
    texlive-fonts-extra \
    texlive-fonts-recommended \
    texlive-plain-generic \
    texlive-xetex \
    tzdata \
    ubuntu-keyring \
    unzip \
    util-linux \
    vim \
    wget \
    xz-utils \
    zim-tools \
    zip \
    zlib1g \
    zlib1g-dev
echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Install additional command-line tools
# ---------------------------------------------------------------------------
print_step "Installing additional command-line tools (Rust, Python, Node tools, Starship)"

# 1. Rust and Cargo Tools
echo "    Installing Rust and Cargo tools ..."
sudo -u "${USER_NAME}" bash -c "curl --retry 5 --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
sudo -u "${USER_NAME}" bash -c "source \"${HOME_DIR}/.cargo/env\" && cargo install cargo-binstall"
sudo -u "${USER_NAME}" bash -c "source \"${HOME_DIR}/.cargo/env\" && cargo binstall -y zellij bat git-delta du-dust fd-find gitui procs ripgrep sd tealdeer zoxide eza bottom xh broot watchexec-cli"
sudo -u "${USER_NAME}" bash -c "source \"${HOME_DIR}/.cargo/env\" && cargo install television"

# 2. Python Tools (uv, ruff, black, huggingface_hub)
echo "    Installing Python CLI tools ..."
sudo -u "${USER_NAME}" bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
sudo -u "${USER_NAME}" bash -c "source \"${HOME_DIR}/.local/bin/env\" 2>/dev/null || true; \"${HOME_DIR}/.local/bin/uv\" tool install --force ruff && \"${HOME_DIR}/.local/bin/uv\" tool install --force huggingface_hub && \"${HOME_DIR}/.local/bin/uv\" tool install --force black"

# 3. nvm and Node.js
echo "    Installing nvm and Node.js ..."
sudo -u "${USER_NAME}" bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
sudo -u "${USER_NAME}" bash -c "export NVM_DIR=\"${HOME_DIR}/.nvm\"; [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"; nvm install --lts && nvm use --lts"

# 4. Antigravity CLI
echo "    Installing Antigravity CLI ..."
sudo -u "${USER_NAME}" bash -c "curl --retry 5 -fsSL https://antigravity.google/cli/install.sh | bash"

# 5. Miscellaneous System Tools (ble.sh, Starship)
echo "    Installing ble.sh and Starship prompt ..."
sudo -u "${USER_NAME}" bash -c "git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git /tmp/ble.sh && make -C /tmp/ble.sh install PREFIX=~/.local && rm -rf /tmp/ble.sh"
curl -sS https://starship.rs/install.sh | sh -s -- -y
echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Configure bash environment
# ---------------------------------------------------------------------------
print_step "Configuring .bashrc, .bash_profile, and .profile"

cp -r "${SCRIPT_DIR}/ubuntu/.bashrc" "${HOME_DIR}/.bashrc"
cp -r "${SCRIPT_DIR}/ubuntu/.bash_profile" "${HOME_DIR}/.bash_profile"
cp -r "${SCRIPT_DIR}/ubuntu/.profile" "${HOME_DIR}/.profile"
chown "${USER_NAME}:users" "${HOME_DIR}/.bashrc" "${HOME_DIR}/.bash_profile" "${HOME_DIR}/.profile"
echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Configure ~/.config and ~/.gemini environments
# ---------------------------------------------------------------------------
print_step "Copying ~/.config and ~/.gemini environments"

mkdir -p "${HOME_DIR}/.config"
mkdir -p "${HOME_DIR}/.gemini"

cp -r "${SCRIPT_DIR}/ubuntu/.config/." "${HOME_DIR}/.config/"
cp -r "${SCRIPT_DIR}/ubuntu/.gemini/." "${HOME_DIR}/.gemini/"
chown -R "${USER_NAME}:users" "${HOME_DIR}/.config" "${HOME_DIR}/.gemini"

echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Configure system time zone and locales
# ---------------------------------------------------------------------------
print_step "Setting system time zone to Asia/Seoul and generating locales"
ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
echo "Asia/Seoul" > /etc/timezone

locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
echo -e "    ${C_GREEN}Done.${C_RESET}"

# ---------------------------------------------------------------------------
# @STEP
# Configure git credential helper
# ---------------------------------------------------------------------------
print_step "Configuring git and credentials"
sudo -u "${USER_NAME}" git config --global credential.helper store
if [[ -n "$GIT_DISPLAY_NAME" ]]; then
    sudo -u "${USER_NAME}" git config --global user.name "${GIT_DISPLAY_NAME}"
fi
if [[ -n "$GIT_EMAIL" ]]; then
    sudo -u "${USER_NAME}" git config --global user.email "${GIT_EMAIL}"
fi
if [[ -n "$GITHUB_USERNAME" && -n "$GITHUB_TOKEN" ]]; then
    sudo -u "${USER_NAME}" bash -c "echo 'https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com' > \"${HOME_DIR}/.git-credentials\""
    sudo -u "${USER_NAME}" chmod 600 "${HOME_DIR}/.git-credentials"
fi
echo -e "    ${C_GREEN}Done.${C_RESET}"

echo ""
echo -e "${C_GREEN}==> Setup complete!${C_RESET}"
