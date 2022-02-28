
# lib_remote.sh

# shell: bash
# desc: SSH and SCP functions
# author: Nate


# Remote connection functions #################################################
# Store config
lib_config_remote_host=""
lib_config_local_user=""
lib_config_print=""

# Do a remote setup once before all other execs
# remoteConfig <host> <user>
function remoteConfig() {
    if [ -z "$1" ] && [ -z "$2" ]; then
        lib_config_remote_host=""
        lib_config_local_user=""
        [[ -n $lib_config_print ]] && printf 'Cleared remote config.\n'
        return 0
    fi

    local _lib_config_remote_host="$1"
    local _lib_config_local_user="$2"

    [[ -n $lib_config_print ]] && printf 'Connecting...'
    if sudo -u "$_lib_config_local_user" sh -c "ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $_lib_config_remote_host \"exit\""; then
        lib_config_remote_host="$_lib_config_remote_host"
        lib_config_local_user="$_lib_config_local_user"
        [[ -n $lib_config_print ]] && printf 'successfully connected to %s@%s\n' "$lib_config_local_user" "$lib_config_remote_host"
        return 0
    else
        [[ -n $lib_config_print ]] && printf 'failed to connect to %s@%s\n' "$_lib_config_local_user" "$_lib_config_remote_host"
        return 1
    fi
}

# Lib functions print ("true") or stay quiet ("")
function libRemotePrint() {
    lib_config_print="$1"
}

# Execute script on remote machine
# remoteScript <script file> [<remote user>] [<remote host> <local user>]
function remoteScriptExec() {
    if [[ -z $3 ]]; then
        [[ -z $lib_config_remote_host ]] && return 1
        local remote_host="$lib_config_remote_host"
    else
        local remote_host="$3"
    fi

    if [[ -z $4 ]]; then
        [[ -z $lib_config_local_user ]] && return 1
        local local_user="$lib_config_local_user"
    else
        local local_user="$4"
    fi

    [[ -z $1 ]] && return 1
    local script="$1"
    local remote_user="$2"

    [[ -n $lib_config_print ]] && printf '%s: User %s executing %s on %s as %s\n' "$0" "$local_user" "$script" "$remote_host" "$remote_user"

    if [[ -z $remote_user ]]; then
        sudo -u "$local_user" sh -c "ssh $server -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"bash -s\" < $script"
    else
        sudo -u "$local_user" sh -c "ssh $server -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"sudo -u $remote_user sh -c 'bash -s'\" < $script"
    fi

    return $?
}

# Execute script on list of remote machines
# multiRemoteScript <server list> <script file> [<separator>] [<exclude>] [<local user>]
function multiRemoteScriptExec() {
    if [[ -z $5 ]]; then
        [[ -z $lib_config_local_user ]] && return 1
        local local_user="$lib_config_local_user"
    else
        local local_user="$5"
    fi

    [[ -z $1 ]] && return 1
    [[ -z $2 ]] && return 1
    local file="$1"
    local script="$2"

    # Optional server list separator token (default is newline)
    local ifs="$3"
    ifs=${ifs:-""}
    #[[ -z $ifs ]] && ifs=""

    # Optional exclude list (default is empty)
    local exclude="$4"
    [[ -z $exclude ]] && exclude=""

    # Server list can be a file, read it if so
    if [[ -f $file ]]; then
        local text="$(<"$file")"
    # Otherwise this arg should be the list itself
    else
        local text="$file"
    fi

    [[ -n $lib_config_print ]] && printf 'User %s remote executing %s\n' "$local_user" "$script"

    idx=0
    while IFS="$ifs" read -ra items; do
        for server in "${items[@]}"; do
            op="true"
            for e in $exclude; do
                if [[ $e == "$server" ]]; then
                    [[ -n $lib_config_print ]] && printf '%s: [%s] Excluding %s\n' "$0" "$idx" "$server"
                    op="false"
                fi
            done
            if [[ $op == "true" ]]; then
                [[ -n $lib_config_print ]] && printf '%s: [%s] User %s executing %s on %s\n' "$0" "$idx" "$local_user" "$script" "$server"
                sudo -u "$local_user" sh -c "ssh ${server} -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"bash -s\" < $script"
                printf "\n"
            fi
            idx=$((idx+1))
        done
    done <<< "$text"
}

# Remote execute command
# sshExec <script> [<remote user>] [<remote host> <local user>]
function sshExec() {
    if [[ -z $3 ]]; then
        [[ -z $lib_config_remote_host ]] && return 1
        local remote_host="$lib_config_remote_host"
    else
        local remote_host="$3"
    fi

    if [[ -z $4 ]]; then
        [[ -z $lib_config_local_user ]] && return 1
        local local_user="$lib_config_local_user"
    else
        local local_user="$4"
    fi

    [[ -z $1 ]] && return 1
    local script="$1"
    local remote_user="$2"

    [[ -n $lib_config_print ]] && printf 'User %s remote executing on %s: %s\n' "$local_user" "$remote_host" "$script"

    # optionally execute as a specific remote user
    if [[ -z $remote_user ]]; then
        sudo -u "$local_user" sh -c "ssh $remote_host -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${script}\""
    else
        sudo -u "$local_user" sh -c "ssh $remote_host -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"sudo -u ${remote_user} sh -c '${script}'\""
    fi

    return $?
}

# Remote copy
# scpExec <src path> <dest path> [<remote host> <local user>]
function scpExec() {
    if [[ -z $3 ]]; then
        [[ -z $lib_config_remote_host ]] && return 1
        local remote_host="$lib_config_remote_host"
    else
        local remote_host="$3"
    fi

    if [[ -z $4 ]]; then
        [[ -z $lib_config_local_user ]] && return 1
        local local_user="$lib_config_local_user"
    else
        local local_user="$4"
    fi

    [[ -z $1 ]] && return 1
    local source="$1"

    [[ -z $2 ]] && return 1
    local dest="$2"

    [[ -n $lib_config_print ]] && printf 'User %s copying %s to %s on %s\n' "$local_user" "$source" "$dest" "$remote_host"

    sudo -u "$local_user" sh -c "scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $source $remote_host:$dest"

    return $?
}

# Open remote session
# sshOpen [<remote host> <local user>]
function sshOpen() {
    if [[ -z $1 ]]; then
        [[ -z $lib_config_remote_host ]] && return 1
        local remote_host="$lib_config_remote_host"
    else
        local remote_host="$1"
    fi

    if [[ -z $2 ]]; then
        [[ -z $lib_config_local_user ]] && return 1
        local local_user="$lib_config_local_user"
    else
        local local_user="$2"
    fi

    [[ -n $lib_config_print ]] && printf 'User %s starting remote session on %s\n' "$local_user" "$remote_host"

    sudo -u "$local_user" sh -c "ssh $remote_host -q -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

    local res=$?
    [[ -n $lib_config_print ]] && printf 'User %s finished remote session.\n' "$local_user"

    return $res
}
