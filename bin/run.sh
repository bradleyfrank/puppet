#!/bin/bash

# shellcheck disable=SC2164
set -eu


#
# --==## SETTINGS ##==--
#

GH_RAW="https://raw.githubusercontent.com"
GH_URL="https://github.com"

BREW_URL="$GH_RAW/Homebrew/install/master/install"

PUPPET_REPO="$GH_URL/bradleyfrank/puppet.git"
DOTFILES_REPO="$GH_URL/bradleyfrank/dotfiles.git"

BOOTSTRAP_SCRIPTS="$GH_RAW/bradleyfrank/puppet/master/bin"
BOOTSTRAP_ASSETS="$GH_RAW/bradleyfrank/puppet/master/files"

DICTIONARY="/usr/local/share/dict/words"
WORDS="$GH_RAW/bradleyfrank/puppet/master/modules/bmf/files/assets/words"

DOTFILES_DIR="$HOME/.dotfiles"
BASH_DOTFILES_SCRIPT="$HOME/.local/bin/generate-dotfiles"

#
# Local development structure
#
# ├── Development
# │   ├── Clients
# │   ├── Home
# │   ├── Scratch
# │   └── Snippets
# ├── .atom
# ├── .config
# │   └── dotfiles
# ├── .local
# │   ├── bin
# │   ├── etc
# │   ├── include
# │   ├── lib
# │   ├── opt
# │   ├── share
# │   │   ├── dict
# │   │   │   └── doc
# │   │   ├── doc
# │   │   └── man
# │   │       ├── man1
# │   │       ├── man2
# │   │       ├── man3
# │   │       ├── man4
# │   │       ├── man5
# │   │       ├── man6
# │   │       ├── man7
# │   │       ├── man8
# │   │       └── man9
# │   ├── srv
# │   └── var
# └── .ssh
#

HOME_DIRECTORIES=(
  "$HOME/Development/{Clients,Home,Scratch,Snippets}"
  "$HOME/.atom"
  "$HOME/.config/dotfiles/archive"
  "$HOME/.local/{bin,etc,include,lib,share,srv,opt,var}"
  "$HOME/.local/share/{bash,doc,man/man{1..9}}"
  "$HOME/.ssh"
)

SYS_DIRECTORIES=(
  "/usr/local/{bin,etc,include,lib,share,var}"
  "/usr/local/share/dict"
)

A_USER="$(id -un)"


#
# --==## FUNCTIONS ##==--
#

bootstrap_macos() {
  local brewfile settings_script

  # exempt admin group from sudo password requirement
  sudo bash -c \
    "echo '%admin ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/nopasswd"

  # install Xcode
  if ! type xcode-select >/dev/null 2>&1; then
    xcode-select --install
  fi

  # install Homebrew
  if ! type brew >/dev/null 2>&1; then
    ruby -e "$(curl -fsSL $BREW_URL)"
  fi

  # download Brewfile from GitHub
  brewfile="$(mktemp -d)/Brewfile"
  curl -o "$brewfile" -s -L "$BOOTSTRAP_ASSETS"/Brewfile

  # install Homebrew packages
  brew update
  pushd "$(dirname "$brewfile")" >/dev/null 2>&1
  brew bundle install Brewfile
  popd >/dev/null 2>&1
  brew cleanup

  # install custom dictionary
  wget "$WORDS" -qO "$DICTIONARY"
  sudo chmod 0755 "$DICTIONARY"

  # download and run system settings script
  settings_script=$(mktemp)
  curl -o "$settings_script" -s -L "$BOOTSTRAP_SCRIPTS"/macos.sh
  # shellcheck disable=SC1090
  . "$settings_script"
}


bootstrap_linux() {
  local pkg_manager pkg_update os_name os_majver puppet_rpm tmp_puppet_rpm
  local puppet_dir="/srv/puppet" puppet_apply="/usr/local/bin/puppet-apply"

  # parse OS info from /etc/os-release file
  os_name="$(sed -n 's/^NAME=\(.*\)/\1/p' /etc/os-release)"
  os_majver="$(sed -n 's/^VERSION_ID=\(\"\)\{0,1\}\([0-9]*\).*/\2/p' /etc/os-release)"

  # set proper package manager
  case "$os_name" in
    Fedora)
            pkg_manager="dnf"
            pkg_update="upgrade"
            puppet_rpm="puppet6-release-fedora-${os_majver}.noarch.rpm"
            ;;
         *)
            pkg_manager="yum"
            pkg_update="update"
            puppet_rpm="puppet6-release-el-${os_majver}.noarch.rpm"
            ;;
  esac

  # install EPEL repository if not Fedora
  if [[ "$os_name" != "Fedora" ]]; then
    sudo "$pkg_manager" install -y epel-release
  fi

  # install Puppetlabs repo
  if ! sudo rpm -qa "puppet6-release"; then
    tmp_puppet_rpm=$(mktemp)
    curl -o "$tmp_puppet_rpm" -s -L \
      https://yum.puppetlabs.com/puppet6/"$puppet_rpm"
    sudo rpm -ivh "$tmp_puppet_rpm"
  fi
  sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-puppet6-release

  # clean dnf cache and install packages required for Puppet
  sudo "$pkg_manager" clean all
  sudo "$pkg_manager" makecache
  sudo "$pkg_manager" install -y puppet-agent git augeas

  # system update
  sudo "$pkg_manager" "$pkg_update" -y

  # clone the Puppet manifest
  sudo mkdir -p "$puppet_dir"
  sudo chown "$A_USER" "$puppet_dir"
  git clone "$PUPPET_REPO" "$puppet_dir"

  # install Puppet apply script
  sudo cp "$puppet_dir"/files/puppet-apply "$puppet_apply"
  sudo chown "$A_USER" "$puppet_apply"
  sudo chmod 0755 "$puppet_apply"

  # apply Puppet manifest
  "$puppet_apply"
}


dotfiles_repo_clone() {
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  chmod 0750 "$DOTFILES_DIR"
  pushd "$DOTFILES_DIR" >/dev/null 2>&1
  git submodule update --init --recursive
  popd >/dev/null 2>&1
}


dotfiles_repo_clone_post() {
  # download and install post-merge hook
  local githook_postmerge="$DOTFILES_DIR"/.git/hooks/post-merge
  wget "$BOOTSTRAP_ASSETS"/post-merge -qO "$githook_postmerge"
  chmod u+x "$githook_postmerge"

  pushd "$DOTFILES_DIR" >/dev/null 2>&1
  # when false, executable bit changes are ignored by Git
  git config core.fileMode false
  # shellcheck disable=SC1091
  . ./.git/hooks/post-merge
  popd >/dev/null 2>&1
}


stow_packages() {
  local stow_packages flags="$1"
  shopt -s nullglob
  stow_packages=(*/)

  echo -n "Stowing"
  for pkg in "${stow_packages[@]}"; do
    _pkg=$(echo "$pkg" | cut -d '/' -f 1)
    echo -n " $_pkg"
    stow -d "$DOTFILES_DIR" -t "$HOME" "$flags" "$_pkg"
  done
  echo
}


#
# --==## MAIN ##==--
#

# trigger sudo timeout
sudo -v


# make $HOME directory structure
for directory in "${HOME_DIRECTORIES[@]}"; do
  eval "mkdir -p $directory"
done


# make system directory structure
for directory in "${SYS_DIRECTORIES[@]}"; do
  eval "sudo mkdir -p $directory"
done


# initial bootstraps
case "$(uname -s)" in
  Darwin) bootstrap_macos ;;
   Linux) bootstrap_linux ;;
esac


# fix permissions
chmod 0700 "$HOME"/.ssh
sudo chown "$A_USER" "$(dirname $DICTIONARY)"


# download Python requirements.txt and install packages
requirements=$(mktemp)
curl -o "$requirements" -s -L "$BOOTSTRAP_ASSETS"/requirements.txt
pip3 install -U --user -r "$requirements"


# download dotfiles repository
if [[ ! -d "$DOTFILES_DIR" ]]; then
  # brand new install
  dotfiles_repo_clone
  dotfiles_repo_clone_post
else
  pushd "$DOTFILES_DIR" >/dev/null 2>&1
  if ! git status >/dev/null 2>&1; then
    # remove any previous installation
    popd >/dev/null 2>&1
    rm -rf "$DOTFILES_DIR"
    dotfiles_repo_clone
    dotfiles_repo_clone_post
  else
    # exists so pull changes
    git checkout master
    git pull
    popd >/dev/null 2>&1
  fi
fi


# stow all packages in dotfiles
pushd "$DOTFILES_DIR" >/dev/null 2>&1
HOST_NAME=$(uname -n)

if git branch -a | grep -qE "$HOST_NAME" >/dev/null 2>&1; then
  # local hostname branch exists: go ahead and stow
  git checkout master
  stow_packages ""
else
  # no hostname branch: create one and backup configs
  git checkout -b "$HOST_NAME"
  stow_packages "--adopt"
  git add -A
  if git commit --dry-run >/dev/null 2>&1; then
    # only commit if there are changes to commit
    git commit -m "Backup dotfiles for $HOST_NAME."
  fi
  git checkout master
  # reset any submodules to dotfiles-specified commit
  git submodule foreach git checkout . >/dev/null 2>&1
fi

popd >/dev/null 2>&1


# Generate .bashrc and .bash_profile
$BASH_DOTFILES_SCRIPT
# shellcheck disable=SC1090
. "$HOME/.bash_profile"
