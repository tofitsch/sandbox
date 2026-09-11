#/!/bin/bash

#prompt format: "[hh:mm:ss]$ " 
PS1="\[\e[36m\][\t]$\[\e[m\] "

#vim-like key-bindings
set -o vi

# set defaults
export EDITOR='nvim'
export TERM=xterm-256color

#colourfull commands
export GREP_COLOR='1;35'
alias grep='grep --color=auto'
alias ls='ls --color=auto'
alias pacman='pacman --color=auto'

#source local atlas software and cvmfs installation
export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
export ALRB_localConfigDir=$HOME/.config/atlasLocalRootBase
alias setupATLAS='source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh'

#aliases
alias vim='nvim'
alias vdiff='git difftool -t vimdiff'
alias rg='ranger'
alias rf='rifle'
alias alert='echo -e "\a"'

#functions
#highlight pattern
hl(){
 grep --color -E "^|${1}|"
}

#copy stdin (or args) to the host system clipboard via OSC 52 -- works through
#docker/ssh with no display server or socket forwarding, as long as the
#terminal emulator supports it (e.g. kitty)
copy(){
 local data seq
 if [ $# -gt 0 ]; then data="$*"; else data=$(cat); fi
 seq="\033]52;c;$(printf '%s' "$data" | base64 | tr -d '\n')\a"
 if [ -n "$TMUX" ]; then seq="\033Ptmux;\033${seq}\033\\"; fi
 printf "$seq" > /dev/tty
}

# use git user name for the scp commands below (assumes it is the same as lxplus login name). Just to have a way to get it automatically
LXP_USER=`git config user.name`

#download from lxplus
scpk(){
 scp -2 -r -oGSSAPIAuthentication=yes -oGSSAPIDelegateCredentials=yes -oGSSAPITrustDNS=yes ${LXP_USER}@lxplus.cern.ch:$1 $2
}

#upload to lxplus
scpkr(){
 scp -2 -r -oGSSAPIAuthentication=yes -oGSSAPIDelegateCredentials=yes -oGSSAPITrustDNS=yes $1 ${LXP_USER}@lxplus.cern.ch:$2
}

# navigation
alias l='lll'
alias b='cd ..'
lll(){
 if [[ "" == $1 ]]; then
  ls -ltr --time-style="+%Y-%m-%d_%H:%M:%S" | awk 'NF>2{printf $6"\t%3s ",NR-2; for(i=7;i<=NF;i++) printf "%s ",$i; printf "\n"}'
 else
  idx=$1
  ((idx++))
  echo `lll | sed -n ${idx}p | awk '{print $3}'`
 fi
}
c(){
 if [[ "" == $1 ]]; then
  echo "> .."
  cd ..
 else
  target=`lll $1`
  if [ -d $target ]; then
   echo "> $target"
   cd $target    
  else
   rifle $target
  fi
 fi
}
