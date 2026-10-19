# Set up dotfiles on WSL

These instructions assume Windows 10/11 and Ubuntu on WSL2. Commands are
labelled by the terminal where they should be run.

## 1. Install Ubuntu (if it is not already installed)

Open **Windows PowerShell** and run:

```powershell
wsl --install -d Ubuntu
```

If prompted, restart Windows, then open Ubuntu from the Start menu and complete
the first-run prompts to create your Linux username and password.

## 2. Install the dotfiles

In the **Ubuntu terminal**, run each command:

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y git
```

```bash
git clone https://github.com/apeoverflow/dotfiles-wsl.git ~/dotfiles-wsl
```

```bash
cd ~/dotfiles-wsl
```

```bash
./bootstrap.sh
```

The bootstrap installs dependencies, links the dotfiles, attempts to set zsh
as your default shell, and runs the diagnostic script. Any existing files that
need to be replaced are backed up under `~/.dotfiles-backup/`.

## 3. Install and configure GitHub Copilot CLI

In the **Ubuntu terminal**, install Copilot:

```bash
npm install -g @github/copilot
```

Sign in:

```bash
copilot login
```

Register the Copilot hooks now that the CLI is installed:

```bash
cd ~/dotfiles-wsl
```

```bash
./install.sh
```

Check the installation:

```bash
./doctor.sh
```

## 4. Start using zsh and tmux

Start zsh in the current terminal:

```bash
exec zsh
```

Start tmux:

```bash
tmux
```

To install the tmux plugins, press **Ctrl+Space**, then **I** (capital i).
On the first launch, Neovim bootstraps its configured plugins:

```bash
nvim
```

If the bootstrap could not set zsh as the default shell, run this in Ubuntu:

```bash
chsh -s "$(which zsh)"
```

Then close and reopen the Ubuntu terminal.

## Optional: WezTerm on Windows

Install WezTerm on Windows first. Then, from the **Ubuntu terminal**, run:

```bash
~/dotfiles-wsl/install.sh
```

The script copies the WezTerm configuration into your Windows user profile.
