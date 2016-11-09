#!/bin/bash
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Requirements:
#
#   You need docker/docker-machine/docker-compose executables exist in
#   your search path.
#
# Configuration:
#
#   You can overwrite MACHINE_OPTS setting in $HOME/dm.sh.rc
#
# Usage:
#
#   dm.sh "machine name" "command" ["args"...]
#
# Supported commands:
#
#   - machine: wrapper to docker-machine
#   - compose: wrapper to docker-compose
#   - env/ssh/...: wrapper to docker-machine
#   - other commands: wrapper to docker
#
# Shortcut support:
#
#   ln -s /path/to/dm.sh /usr/local/bin/m1
#   m1 ps  # this line == dm.sh m1 ps
#
# Example:
#
#   m1 machine status
#     exactly same as docker-machine status m1
#
#   m1 ps -a
#     create/start m1 using docker-machine, prepare env vars, then run
#     docker ps -a
#
#   m1 ip
#     create/start m1 using docker-machine, prepare env vars, then run
#     docker-machine ip m1


MACHINE_OPTS="--driver virtualbox \
	    --virtualbox-disk-size 20480 \
	    --virtualbox-memory 1024"

if [[ -f "$HOME/.dm.sh.rc" ]]
then
    . "$HOME/.dm.sh.rc"
fi

function log {
    if [[ $SILENT != 1 ]]
    then
	echo "$@"
    fi
}

function start {
    # test if machine exists
    log -n "Check if $1 exists... "
    docker-machine ls -q | grep "^$1\$" > /dev/null 2>&1
    if [[ $? != 0 ]]
    then
	log "no."
	# machine not exists
	log ""
	log -n "Machine $1 not exists, create it?(Y/n) "
	read a
	if [[ $a == "n" || $a == "n" ]]
	then
	    log "Aborted."
	    exit 0
	fi
	if [[ $SILENT == 1 ]]
	then
	    docker-machine create $MACHINE_OPTS "$1" > /dev/null 2>&1
	else
	    docker-machine create $MACHINE_OPTS "$1"
	fi
	log ""
    else
	log "yes."
    fi

    # test if machine is running
    log -n "Check $1 status... "
    STATUS=$(docker-machine status "$1")
    log "$STATUS"
    log "$STATUS" | grep -F 'Running' > /dev/null 2>&1
    if [[ $? != 0 ]]
    then
	log "Starting $1 ... "
	if [[ $SILENT == 1 ]]
	then
	    docker-machine start "$1" > /dev/null 2>&1
	else
	    docker-machine start "$1"
	fi
	log ""
    fi
}

NAME=$(basename "$0")
if [[ $NAME == "dm.sh" ]]
then
    if [[ $1 == "" ]]
    then
	echo You must provide machine name.
	exit 1
    fi
    NAME="$1"
    shift
fi

CMD="$1"
shift
case "$CMD" in
    machine)
	if [[ $VERBOSE == "" ]]; then SILENT=1; fi
	start "$NAME"
	eval $(docker-machine env "$NAME")
	CMD="$1"
	shift
	docker-machine "$CMD" "$NAME" "$@"
	;;
    env|status|ip|url|ssh)
	if [[ $VERBOSE == "" ]]; then SILENT=1; fi
	start "$NAME"
	eval $(docker-machine env "$NAME")
	docker-machine "$CMD" "$NAME" "$@"
	;;
    scp|upgrade)
	start "$NAME"
	eval $(docker-machine env "$NAME")
	docker-machine "$CMD" "$NAME" "$@"
	;;
    compose)
	start "$NAME"
	eval $(docker-machine env "$NAME")
	docker-compose "$@"
	;;
    *)
	start "$NAME"
	eval $(docker-machine env "$NAME")
	docker "$CMD" "$@"
	;;
esac

