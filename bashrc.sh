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

#make umlauts work properly 
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8


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

#download from lxplus
scpk(){
 scp -2 -r -oGSSAPIAuthentication=yes -oGSSAPIDelegateCredentials=yes -oGSSAPITrustDNS=yes tofitsch@lxplus.cern.ch:$1 $2
}

scpkr(){
 scp -2 -r -oGSSAPIAuthentication=yes -oGSSAPIDelegateCredentials=yes -oGSSAPITrustDNS=yes $1 tofitsch@lxplus.cern.ch:$2
}

#download from lxplus6
scp8k(){
 scp -2 -r -oGSSAPIAuthentication=yes -oGSSAPIDelegateCredentials=yes -oGSSAPITrustDNS=yes tofitsch@lxplus8.cern.ch:$1 $2
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
