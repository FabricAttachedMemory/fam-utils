#!/bin/bash
# Parse file containing Host names (one per line) to make same changes to all of
#them by running this script. Tasks could be anything, like copying your ssh
#pub key to the hosts; updating sources.lists; installing packages and etc.

#author         : Zach Volchak
#date           : 03-12-2018
#note           : apt install sshpass.

# Hosts file format can be of two types:
# hostname
# username@hostname
#
# using "#" or "//" in the HOSTS_FILE will allow to skip parsing that line.

HOSTS_FILE=$1
DEFAULT_USER=
SSH_ID=
SSH_PASSWD=

SKIP_COPY_ID=false
DRY_RUN=false


function show_help(){
    echo " Usage: "
    echo " -f : path to a file containing all the hosts destination. Either 'username@host' or 'host' format per line."
    echo " -u : default username for a host that is not in a format 'username@host' in the provided file path."
    echo " -i : ssh/id_rsa.pub file to be used for ssh-copy-id."
    echo " -S : Skip ssh-copy-id stage."
    echo " -D : Dry run. No actual action will be done."
}


while getopts "h?f:u:i:SD" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    u) # default username to ssh into a host
        DEFAULT_USER=$OPTARG
        ;;
    f) # path to a file containing all the hosts
        HOSTS_FILE=$OPTARG
        ;;
    i) # path to .ssh/id_rsa.pub
        SSH_ID=$OPTARG
        ;;
    D) #dry run
        DRY_RUN=true
        ;;
    S) #Skip ssh-copy-id
        SKIP_COPY_ID=true
        ;;
    esac
done


if [ -z "$HOSTS_FILE" ]; then
    echo "Missing positional argument #1: path to a file with all the host names"
    exit
fi


if [ $SKIP_COPY_ID = false ]; then
    if [ -z "$SSH_ID" ]; then
        echo " -- SSH ID path is not set! Getting default from ~/.ssh/id_rsa.pub --"
        echo ""
        SSH_ID=`(realpath ~/.ssh/id_rsa.pub)`
        echo $SSH_ID
    fi

    #Read ssh pub key password once to be used for all the hosts in the file,
    #instead of keep asking for password for each host.
    echo "Password for $SSH_ID:"
    read -s SSH_PASSWD #Not sure if it is a good idea to store pasword in the global variable...
fi #skip ssh-copy-id


while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ ${line:0:1} = '#' || ${line:0:1} = '/' ]]; then
        continue
    fi

    split_line=(${line/@/ }) #split by @ to extract username (if present)
    # Get user from a host line or use default one passed as an argument using -u
    if [ ${#split_line[@]} -gt 1 ]; then
        user=${split_line[0]}
        host=${split_line[1]}
    else
        if [ -z "$DEFAULT_USER" ]; then
            echo " - Default user is not set (-u) and no User in the host:"
            echo "  -- $line"
            echo ""
            continue
        fi
        user=$DEFAULT_USER
        host=${split_line[0]}
    fi # if host has username

    destination=$user@$host
    if [ "$DRY_RUN" = true ]; then
        echo " - Dry run for: $destination"
        echo ""
        continue
    else
        echo " - Processing $destination"
        echo ""
    fi

    # -- At this point, actual work on hosts can be done! --

    if [ $SKIP_COPY_ID = false ]; then
        sshpass -p $SSH_PASSWD ssh-copy-id -i $SSH_ID $destination
    fi
done < "$HOSTS_FILE"
