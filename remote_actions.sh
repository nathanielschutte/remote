
# remote_actions.sh

# =============================================================================
# ACTION FUNCTIONS
# init
init_project() {
    if check_remote_project; then
        script_print "Already a remote project initialized in this directory.\n"
    else
        script_print "Initializing project in this directory...\n"
        mkdir $REMOTE_DIR || return 1
        echo "" >> "$PROJECT_DIR/$REMOTE_DIR/$TARGET_FILE" || return 1
        script_print "Success.\n"
    fi
}

# list
project_info() {
    count=0
    printf 'Hosts:\n'
    for file in $(find $PROJECT_DIR/$REMOTE_DIR -type f -name *$REMOTE_EXT); do
        tag="${file##*/}" && tag="${tag%$REMOTE_EXT}"
        [[ -z "$tag" ]] && continue
        if [[ $tag == $REMOTE_TARGET ]]; then
            printf ' * %s\n' "$tag" 
        else
            printf '   %s\n' "$tag" 
        fi
        count=$((count+1))
    done
    [[ $count -eq 0 ]] && script_print '   None\n'
}

# info
# Get detail info on host, default to target host
project_host_info() {
    if [[ -z $ACTION_TAG ]]; then
        if [[ -n $REMOTE_TARGET ]]; then
            ACTION_TAG="$REMOTE_TARGET"
        else
            script_message 'No hosts\n'
        fi
    fi
    REMOTE_TARGET="$ACTION_TAG"
    get_host 1
    if [[ -r "$PROJECT_DIR/$REMOTE_DIR/${ACTION_TAG}${REMOTE_EXT}" ]]; then
        printf '\nHOST "%s"\n----------------\n%s\n' "${ACTION_TAG^^}" "$(_write_host)"
    else
        script_message 'Host "%s" does not exist\n' "$ACTION_TAG"
    fi
}

# add
# Add a new host to project
add_project_host() { 
    check_tag_passed
    if check_tag_exists; then
        script_error 'Tag "%s" already exists.\n' "$ACTION_TAG"
        return 1
    fi

    # copy from existing host - overwrite any args
    if [[ -n $ACTION_COPY ]]; then
        REMOTE_TARGET="$ACTION_COPY"
        get_host 1
        script_print 'Creating new host "%s" from "%s"\n' "$ACTION_TAG" "$ACTION_COPY"
    fi

    # check host connection then write
    check_connection 1
    _write_host > "$PROJECT_DIR/$REMOTE_DIR/${ACTION_TAG}${REMOTE_EXT}"

    # if this is the first host in the project, make it the target host
    if [[ -z $REMOTE_TARGET ]]; then
        script_print 'Making this host (%s) the new target\n' "$ACTION_TAG"
        REMOTE_TARGET="$ACTION_TAG"
        set_target
    fi
}

# edit
# Edit existing host for project
edit_project_host() {
    check_tag_passed
    if check_tag_exists; then
        REMOTE_TARGET="$ACTION_TAG"
        get_host 1
        script_print 'Updating host "%s"\n' "$ACTION_TAG"
        _write_host > "$PROJECT_DIR/$REMOTE_DIR/${ACTION_TAG}${REMOTE_EXT}"
    else
        script_error 'Tag "%s" does not exist.\n' "$ACTION_TAG"
        return 1
    fi
}

# use
# Switch host for project
set_project_target() {
    check_tag_passed
    if check_tag_exists; then
        REMOTE_TARGET="$ACTION_TAG"
        set_target
        script_print 'Set target host to "%s"\n' "$ACTION_TAG"
    else
        script_error 'Tag "%s" does not exist.\n' "$ACTION_TAG"
    fi
}

# deploy
# Deploy project
project_deploy() {
    get_host
    check_connection 1
    deploy_r
}

# send
# Send files to remote
send_files () {
    script_message 'I will send >>> %s\n' "$FILENAMES"
}
# =============================================================================
