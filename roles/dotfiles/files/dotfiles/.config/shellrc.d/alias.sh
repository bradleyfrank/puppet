alias bw="bitwise --no-color"
alias condense='grep -Erv "(^#|^$)"'
alias e='extract'
alias glances='glances --theme-white'
alias groot='cd $(git rev-parse --show-toplevel)'
alias ipa='ip -c a'
alias isodate='date --iso-8601=seconds'
alias l1='ls -1 --color --classify --human-readable'
alias la='ls -la --color --classify --human-readable'
alias lg='ls -Gg --color --classify --human-readable'
alias ll='ls -l --color --classify --human-readable'
alias lt='ls -1AS --color --classify --human-readable --group-directories-first --size'
alias lsblk='lsblk -o "NAME,FSTYPE,SIZE,UUID,MOUNTPOINT"'
alias lsmnt='mount | column -t'
alias pipi='python3 -m pip install --user'
alias proc='ps -e --forest -o pid,ppid,user,time,cmd'
alias pipu='pip_upgrade_outdated -3 --user --verbose'
alias pubip='dig myip.opendns.com @resolver1.opendns.com'
alias steep='brew update ; brew upgrade ; brew cask upgrade ; brew cleanup ; brew doctor'
alias tmuxl='tmux -f ~/.tmux.min.conf'