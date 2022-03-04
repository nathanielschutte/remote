
# remote_util.sh

# =============================================================================
# Functions
usage() {
    printf "HELP IS ON THE WAY"
    exit 1
}

# Output format of host data to stdout
_write_host() {
    echo "host=$REMOTE_HOST"
    echo "port=$REMOTE_PORT"
    echo "user=$REMOTE_USER"
    echo "identity-file=$KEY_LOC"
    echo "ignore-dot-dirs=$IGNORE_DOT_DIRS"
    echo "ignore-dot-files=$IGNORE_DOT_FILES"
    echo "ignore-files=${IGNORE_FILES// /,}"
    echo "ignore-dirs=${IGNORE_DIRS// /,}"
    echo "local-path=$LOCAL_MAP"
    echo "remote-path=$REMOTE_MAP"
}

# Parse stdin to host data - dont overwrite params set by flags
_load_host() {
    local lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done
    for opt in ${lines[@]}; do
        [[ -z $REMOTE_HOST ]] && [[ $opt =~ ^host=[^$]+ ]] && REMOTE_HOST="${opt#*=}"
        [[ -z $REMOTE_PORT ]] && [[ $opt =~ ^port=[^$]+ ]] && REMOTE_PORT="${opt#*=}"
        [[ -z $REMOTE_USER ]] && [[ $opt =~ ^user=[^$]+ ]] && REMOTE_USER="${opt#*=}"
        [[ -z $KEY_LOC ]] && [[ $opt =~ ^identity-file=[^$]+ ]] && KEY_LOC="${opt#*=}"
        [[ -z $IGNORE_DOT_DIRS ]] && [[ $opt =~ ^ignore-dot-dirs=[^$]+ ]] && IGNORE_DOT_DIRS="${opt#*=}"
        [[ -z $IGNORE_DOT_FILES ]] && [[ $opt =~ ^ignore-dot-files=[^$]+ ]] && IGNORE_DOT_FILES="${opt#*=}"
        [[ -z $IGNORE_FILES ]] && [[ $opt =~ ^ignore-files=[^$]+ ]] && IGNORE_FILES="${opt#*=}"
        [[ -z $IGNORE_DIRS ]] && [[ $opt =~ ^ignore-dirs=[^$]+ ]] && IGNORE_DIRS="${opt#*=}"
        [[ -z $LOCAL_MAP ]] && [[ $opt =~ ^local-path=[^$]+ ]] && LOCAL_MAP="${opt#*=}"
        [[ -z $REMOTE_MAP ]] && [[ $opt =~ ^remote-path=[^$]+ ]] && REMOTE_MAP="${opt#*=}"
    done

    IGNORE_FILES="${IGNORE_FILES//,/ }"
    IGNORE_DIRS="${IGNORE_DIRS//,/ }"

    #script_debug 'loaded:\n%s\n' "$(_write_host)"
}

# Check if .remote is present
# Pass an arg to allow this to kill the program on fail
check_remote_project() {
    if [[ -n $(find $PROJECT_DIR -maxdepth 1 -type d -name ".remote") ]]; then
        if [[ -d "$PROJECT_DIR/$REMOTE_DIR" && -n $(find "$PROJECT_DIR/$REMOTE_DIR" -maxdepth 1 -type f -name "$TARGET_FILE") ]]; then
            return 0
        else
            if [[ -n "$1" ]]; then
                script_error 'Remote target file missing (maybe a permission issue)\n'
                exit 1
            else
                return 1
            fi
        fi
    else
        if [[ -n "$1" ]]; then
            script_error 'No remote project initialized in this directory.\n'
            exit 1
        else
            return 1
        fi
    fi
}

# Check current config connection
# Pass an arg to allow this to kill the program on fail
check_connection() {
    if [[ -z "$REMOTE_HOST" ]]; then
        if [[ -n "$1" ]]; then
            script_error 'Remote host is not set\n'
            exit 2 # missing information
        else
            return 2
        fi
    fi
    if [[ -z "$REMOTE_USER" ]]; then
        if [[ -n "$1" ]]; then
            script_error 'Remote user is not set\n'
            exit 2
        else
            return 2
        fi
    fi

    [[ -z $REMOTE_PORT ]] && REMOTE_PORT='22'

    # Check key file
    script_debug "Checking key..."
    if [[ -n $KEY_LOC && ! -r $KEY_LOC ]]; then
        script_debug "not found.\n"
        if [[ -n "$1" ]]; then
            script_error 'Identity file does not exist: %s\n' "$KEY_LOC"
            exit 2
        else
            return 2 # bad identity file - missing information
        fi
    else
        if [[ -z $KEY_LOC ]]; then
            script_debug "not specified.\n"
        else
            script_debug "ok.\n"
        fi
    fi

    # Check connection
    script_print "Connecting to $REMOTE_HOST..."
    local connected=0

    # using ssh-agent
    if [ -z "$KEY_LOC" ]; then
        $(ssh -q -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST exit > /dev/null 2>&1) && connected=1
    
    # using identity file
    else
        $(ssh -q -i $KEY_LOC -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST exit > /dev/null 2>&1) && connected=1
    fi

    if [ "$connected" -eq 0 ]; then
        script_print "failed.\n"
        if [[ -n "$1" ]]; then
            script_error 'Could not reach %s@%s:%s.\n' "$REMOTE_USER" "$REMOTE_HOST" "$REMOTE_PORT"
            exit 1
        else
            return 1
        fi
    else
        script_print "success!\n"
    fi
}

# Load target host data
get_host() {
    if [[ -n $REMOTE_TARGET ]]; then
        if [[ -r $PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${REMOTE_EXT} ]]; then
            _load_host < "$PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${REMOTE_EXT}"
        else
            if [[ -n "$1" ]]; then
                script_error 'Could not read data for target "%s"\n' "$REMOTE_TARGET"
                exit 1
            fi
            script_warning 'Could not read data for target "%s"\n' "$REMOTE_TARGET"
        fi
    fi
}

# Load target host from file
get_target() {
    if [[ -z $REMOTE_TARGET ]]; then
        if [[ -r "$PROJECT_DIR/$REMOTE_DIR/$TARGET_FILE" ]]; then
            REMOTE_TARGET="$(cat $PROJECT_DIR/$REMOTE_DIR/$TARGET_FILE | xargs)"
            script_debug 'Loaded target host from file: %s\n' "$REMOTE_TARGET"
        else
            script_error 'Cannot read target file'
        fi
        [[ -z $REMOTE_TARGET ]] && return 1
    fi
}

# Set target
set_target() {
    if [[ -w "$PROJECT_DIR/$REMOTE_DIR/$TARGET_FILE" ]]; then
        script_debug 'Writing host target to file: %s\n' "$REMOTE_TARGET"
        echo "$REMOTE_TARGET" > "$PROJECT_DIR/$REMOTE_DIR/$TARGET_FILE"
    else
        script_error 'Error writing to target host file\n'
    fi
}

# Check if tag was passed
check_tag_passed() {
    if [[ -z $ACTION_TAG ]]; then
        script_error '%s requires tag name: %s %s <tag name>\n' "$REMOTE_ACTION" "$SCRIPT_NAME" "$REMOTE_ACTION"
        exit 1
    fi
}

# Check if tag exists
check_tag_exists() {
    [[ -z $ACTION_TAG ]] && return 1
    # Check tag file
    script_debug 'Checking tag "%s"...' "$ACTION_TAG"
    if [[ -n "$(find $PROJECT_DIR/$REMOTE_DIR -maxdepth 1 -type f -name ${ACTION_TAG}${REMOTE_EXT})" ]]; then
        script_debug 'exists\n'
        return 0
    else
        script_debug 'not found\n'
        return 1
    fi
}
# =============================================================================
