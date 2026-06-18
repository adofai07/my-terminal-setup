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
| 9 | Copy pre-configured `~/.config` and `~/.gemini` environment directories |
| 10 | Configure the system time zone (Asia/Seoul) and generate locales |
| 11 | Configure the git credential helper and global git user settings |

---

## AWS Container Setup

The `aws-container.sh` script is a modified, **fully non-interactive** version tailored for AWS container environments or instances (like the AWS Deep Learning AMI). It removes SSH and `sudo` configurations, allowing it to run cleanly from automated pipelines or user-data scripts.

| Step | Description |
| :---: | :--- |
| 1 | Change the specified user's home directory |
| 2 | Fix ownership and permissions for the home directory |
| 3 | Update `apt` and install essential system packages and libraries |
| 4 | Install additional CLI tools via Cargo, uv, and npm (including Rust utilities, Neovim, Fastfetch, etc.) |
| 5 | Configure the bash environment (`.bashrc`, `.bash_profile`, `.profile`) |
| 6 | Copy pre-configured `~/.config` and `~/.gemini` environment directories |
| 7 | Configure the system time zone (Asia/Seoul) and generate locales |
| 8 | Configure the git credential helper and global git user settings |

**Usage:**
```bash
sudo ./aws-container.sh \
  --user-name ubuntu \
  --chown-homedir \
  --git-name "John Doe" \
  --git-email "john@example.com" \
  --github-user "johndoe" \
  --github-token "ghp_yourtokenhere"
```
