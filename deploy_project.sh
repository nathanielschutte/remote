# SCP recursive directory deploy - tracking
deploy_r() {

    # load current file hashes - skip if -a (ALL) is set
    if [[ $ALL -eq 0 ]]; then
        script_print "Collecting files...\n"
        declare -A track
        if [[ -f $TRACKER_FILE ]]; then
            while read -r line; do
                if [[ -n $line ]]; then
                    parts=($line)
                    track[${parts[0]}]=${parts[1]}
                fi
            done < $TRACKER_FILE
        else
            touch $TRACKER_FILE
        fi
    fi

    # seek files and compare hashes
    echo "" > "$LOCAL_MAP/$TRACKER_FILE"
    FILES=()
    for file in $(find $LOCAL_MAP -type f); do

        # skip blank lines
        [[ -z $file ]] && continue
        [[ $file == "." ]] && continue
        [[ ${#file} -lt 2 ]] && continue

        # ignoring . directories
        if [[ $IGNORE_DOT_DIRS == 'true' ]]; then
            if [[ $file =~ .*\/\.[^/]*/.* ]]; then
                continue
            fi
        fi

        # ignoring . files
        if [[ $IGNORE_DOT_FILES == 'true' ]]; then
            basename=${file##*/}
            if [[ ${basename:0:1} == '.' ]]; then
                script_print 'skipping %s' "$file"
                continue
            fi
        fi

        # ignoring files
        if [[ -z $IGNORE_FILES ]]; then
            IGNORE_FILES="$LOCAL_MAP/$TRACKER_FILE"
        else
            IGNORE_FILES="$IGNORE_FILES $LOCAL_MAP/$TRACKER_FILE"
        fi
        skip=0
        for ignore in $IGNORE_FILES; do
            [[ ${file##*/} == $ignore ]] && skip=1 && script_print "skipping $file"
        done
        for ignore in $IGNORE_DIRS; do
            [[ $file =~ .*\/$ignore[^/]*/.* ]] && skip=1 && script_print "skipping $file"
        done
        [[ skip -gt 0 ]] && continue

        # get latest checksum no matter what, still update deploy tracker when -a (ALL) is set
        chksum=($(cksum $file))

        # add file to deploy if -a (ALL) is set
        if [[ $ALL -eq 1 ]]; then
            FILES+=(${file#*/})
        else
            # otherwise only add it if checksum differs
            if [[ chksum -ne ${track[$file]} ]]; then
                FILES+=(${file#*/})
            fi
        fi

        # track checksum
        echo "$file $chksum" >> "$LOCAL_MAP/$TRACKER_FILE"
    done
    if [[ ${#FILES[@]} -eq 0 ]]; then
        script_print "No files to deploy, exiting.\n"
        exit 0
    fi
    [[ $V_SPEC == 'true' ]] && printf "\nStarting deploy...\n"
    [[ $V_SPEC == 'true' ]] && printf "Path local: $LOCAL_MAP/\n"
    [[ $V_SPEC == 'true' ]] && printf "Path remote: $REMOTE_MAP/\n"
    script_print "Starting transfer to $REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/...\n"

    # Deploy files
    idx=0
    for file in ${FILES[@]}; do
        script_print "[$idx] Transferring $LOCAL_MAP/$file -> $REMOTE_MAP/$file\n"
        scp -i $KEY_LOC -q $LOCAL_MAP/$file $REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/$file

        # check if failed, maybe dir doesn't exist
        if [[ $? -ge 1 ]]; then
            script_print "Creating non-existant dir: ${file%/*}\n"
            ssh $REMOTE_USER@$REMOTE_HOST -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "mkdir -p $REMOTE_MAP/${file%/*}"

            # try again with dir created
            scp -i $KEY_LOC -q $LOCAL_MAP/$file $REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/$file
            ec=$?
            if [[ $ec -ge 1 ]]; then
                script_print "[$idx] ERROR for file: $file (code=$ec). Stopping deploy.\n"
                exit 1
            fi
        fi
        idx=$((idx + 1))
    done
}
