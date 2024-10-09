# dotfiles

## Setup dotfiles on your computer

- Clone the repository to .dotfiles directory at your root level
  - `git clone https://github.com/eslutz/dotfiles.git .dotfiles`
- Run `create_links.sh` script to link dotfiles to your local configs

### Things to remember

- Update `create_links.sh` whenever a new dotfile is added

## Setup Homebrew

Install [Homebrew](https://brew.sh)

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install packages

```shell
brew install FORMULAE_NAME
```

|             |            |                 |            |             |
| ----------- | ---------- | --------------- | ---------- | ----------- |
| angular-cli | awscli     | azure-cli       | powershell | dotnet      |
| git         | git-lfs    | gh              | pinetry    | pinetry-mac |
| bfg         | typescript | zsh-completions |            |             |
