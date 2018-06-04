# System-wide .bashrc file for interactive bash(1) shells.

# To enable the settings / commands in this file for login shells as well,
# this file has to be sourced in /etc/profile.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, overwrite the one in /etc/profile)
PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

# Commented out, don't overwrite xterm -T "title" -n "icontitle" by default.
# If this is an xterm set the title to user@host:dir
#case "$TERM" in
#xterm*|rxvt*)
#    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"'
#    ;;
#*)
#    ;;
#esac

# enable bash completion in interactive shells
#if ! shopt -oq posix; then
#  if [ -f /usr/share/bash-completion/bash_completion ]; then
#    . /usr/share/bash-completion/bash_completion
#  elif [ -f /etc/bash_completion ]; then
#    . /etc/bash_completion
#  fi
#fi

# sudo hint
if [ ! -e "$HOME/.sudo_as_admin_successful" ] && [ ! -e "$HOME/.hushlogin" ] ; then
    case " $(groups) " in *\ admin\ *)
    if [ -x /usr/bin/sudo ]; then
	cat <<-EOF
	To run a command as administrator (user "root"), use "sudo <command>".
	See "man sudo_root" for details.
	
	EOF
    fi
    esac
fi

# if the command-not-found package is installed, use it
if [ -x /usr/lib/command-not-found -o -x /usr/share/command-not-found/command-not-found ]; then
	function command_not_found_handle {
	        # check because c-n-f could've been removed in the meantime
                if [ -x /usr/lib/command-not-found ]; then
		   /usr/lib/command-not-found -- "$1"
                   return $?
                elif [ -x /usr/share/command-not-found/command-not-found ]; then
		   /usr/share/command-not-found/command-not-found -- "$1"
                   return $?
		else
		   printf "%s: command not found\n" "$1" >&2
		   return 127
		fi
	}
fi

function ssh_agent {
    which ssh-agent >/dev/null 2>&1 && which ssh-add >/dev/null 2>&1 || return
    [ -d /tmp/ssh-${UID} ] || { mkdir /tmp/ssh-${UID} 2>/dev/null && chmod 0700 /tmp/ssh-${UID}; }
    [ $(ps x |awk '$5 == "ssh-agent" && $7 == "'/tmp/ssh-${UID}/agent@${HOSTNAME}'"' |wc -l) -eq 0 ] && rm -f /tmp/ssh-${UID}/agent@${HOSTNAME} && ssh-agent -a /tmp/ssh-${UID}/agent@${HOSTNAME} 2>/dev/null > ${HOME}/.ssh/agent@${HOSTNAME}
    export SSH_AUTH_SOCK="/tmp/ssh-${UID}/agent@${HOSTNAME}"
    ssh-add -l >/dev/null 2>&1 || for file in ${HOME}/.ssh/*; do
        [ -f "$file" ] && grep "PRIVATE KEY" ${file} >/dev/null 2>&1 && ssh-add $file 2>/dev/null;
    done
}

function attach_screen {
    which screen >/dev/null 2>&1 || return
    if [ -z "$STY" ]; then
        echo -n 'Attaching screen.' && sleep 1 && echo -n '.' && sleep 1 && echo -n '.' && sleep 1 && screen -xRR -S "${USER}" 2>/dev/null
    fi
}

function attach_tmux {
    which tmux >/dev/null 2>&1 || return
    if [ -z "$TMUX" ]; then
        echo -n 'Attaching tmux.' && sleep 1 && echo -n '.' && sleep 1 && echo -n '.' && sleep 1 && tmux -L$USER@$HOSTNAME -q has-session >/dev/null 2>&1 && tmux -L$USER@$HOSTNAME attach-session -d || tmux -L$USER@$HOSTNAME new-session -n$USER -s@$USER
    fi
}

function git_branch {
    git branch --no-color 2>/dev/null |awk '$1 == "*" {match($0, "("FS")+"); print substr($0, RSTART+RLENGTH);}'
}

function process_count {
    ps ax 2>/dev/null |awk 'BEGIN {r_count=d_count=0}; $3 ~ /R/ {r_count=r_count+1}; $3 ~ /D/ {d_count=d_count+1}; END {print r_count"/"d_count"/"NR-1}'
}

function load_average {
    awk '{print $1}' /proc/loadavg 2>/dev/null
}

DGRAY="\[\033[1;30m\]"
RED="\[\033[01;31m\]"
GREEN="\[\033[01;32m\]"
BROWN="\[\033[0;33m\]"
YELLOW="\[\033[01;33m\]"
BLUE="\[\033[01;34m\]"
CYAN="\[\033[0;36m\]"
GRAY="\[\033[0;37m\]"
NC="\[\033[0m\]"

if [ $UID = 0 ]; then
    COLOR=$RED
    INFO="[\$(process_count)|\$(load_average)]"
    END="#"
else
    COLOR=$BROWN
    INFO=""
    END="\$"
fi

BRANCH="\$(GIT_BRANCH=\$(git_branch); [ -n \"\$GIT_BRANCH\" ] && echo \"$DGRAY@$CYAN\$GIT_BRANCH\")"

export PS1="$NC$BLUE$INFO$COLOR\u$DGRAY@$CYAN\h$DGRAY:$GRAY\w$BRANCH$DGRAY$END$NC "
export PATH="/dns/tm/sys/usr/local/bin:$PATH"
readonly PS1
umask 002

[ -n "$STY" ] && export PROMPT_COMMAND='echo -ne "\033k${HOSTNAME%%.*}\033\\"'
if [ -n "$SSH_TTY" -a -f ${HOME}/.ssh/auto ]; then
#    if [ "${HOSTNAME%%-*}" == 'proxy' ]; then
    if [[ $(hostname -s) = *001 ]]; then
        ssh_agent
        attach_tmux
    else
        attach_screen
    fi
fi

