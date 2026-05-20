# my-terminal-setup

My personal scripts to configure a new notebook

## Setup Steps

The `ubuntu-notebook.sh` script automates the provisioning of the environment through the following steps:

| Step | Description |
| :---: | :--- |
| 1 | Change the specified user's home directory |
| 2 | Grant passwordless `sudo` privileges to the user |
| 3 | Set up SSH `authorized_keys` |
| 4 | Fix ownership and permissions for the home directory and SSH files |
| 5 | Disable SSH password authentication in `sshd_config` |
| 6 | Update `apt` and install essential system packages and libraries |
| 7 | Install additional CLI tools via Cargo, uv, and npm (including Rust utilities, Neovim, Fastfetch, etc.) |
| 8 | Configure the bash environment (`.bashrc`, `.bash_profile`, `.profile`) |
| 9 | Copy pre-configured `~/.config` environment directories |
| 10 | Configure the system time zone (Asia/Seoul) and generate locales |
| 11 | Configure the git credential helper and global git user settings |
