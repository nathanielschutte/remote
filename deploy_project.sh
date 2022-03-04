
# deploy_project.sh
# SCP recursive project deploy - tracking

deploy_r() {

    # load current file hashes - skip if -a is set
    if [[ $ALL -eq 0 ]]; then
        script_print "Collecting files...\n"
        declare -A track
        if [[ -f "$PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${TRACKER_EXT}" ]]; then
            while read -r line; do
                if [[ -n $line ]]; then
                    parts=($line)
                    track[${parts[0]}]=${parts[1]}
                fi
            done < "$PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${TRACKER_EXT}"
        else
            touch "$PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${TRACKER_EXT}"
        fi
    fi

    [[ -n "$LOCAL_MAP" ]] && LOCAL_MAP="$LOCAL_MAP/"

    script_debug "\nStarting deploy...\n"
    script_debug "Path local: $PROJECT_DIR/$LOCAL_MAP\n"
    script_debug "Path remote: $REMOTE_MAP/\n"
    script_print "Starting transfer to $REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/...\n"

    if [[ -z $IGNORE_DIRS ]]; then
        IGNORE_DIRS="$REMOTE_DIR"
    else
        IGNORE_DIRS="$IGNORE_DIRS $REMOTE_DIR"
    fi

    # seek files and compare hashes
    echo "" > "$PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${TRACKER_EXT}"
    local idx=0
    local this_file=""
    local chksum
    for file in $(find $PROJECT_DIR/$LOCAL_MAP -type f); do
        # skip blank lines
        [[ -z $file ]] && continue
        [[ $file == "." || $file == ".." ]] && continue
        [[ ${#file} -lt 2 ]] && continue

        # ignoring . directories
        if [[ $IGNORE_DOT_DIRS -eq 1 ]]; then
            if [[ $file =~ .*/\.[^/]+/.* ]]; then
                script_debug 'skipping dot dir %s\n' "$file"
                continue
            fi
        fi

        # ignoring . files
        if [[ $IGNORE_DOT_FILES -eq 1 ]]; then
            local basename=${file##*/}
            if [[ ${basename:0:1} == '.' ]]; then
                script_debug 'skipping dot file %s\n' "$file"
                continue
            fi
        fi

        # ignoring dirs and files
        local skip=0
        for ignore in $IGNORE_FILES; do
            #echo "testing file ignore: $PROJECT_DIR/$LOCAL_MAP$ignore"
            [[ ${file##*/} == $ignore ]] && skip=1 && script_debug "skipping $file\n"
        done
        for ignore in $IGNORE_DIRS; do
            #echo "testing dir ignore $PROJECT_DIR/$LOCAL_MAP$ignore"
            [[ $file =~ .*$PROJECT_DIR/$LOCAL_MAP$ignore[^/]*/.* ]] && skip=1 && script_debug "skipping $file\n"
        done
        [[ skip -gt 0 ]] && continue

        # get latest checksum no matter what, still update deploy tracker when -a (ALL) is set
        chksum=($(cksum $file | cut -d ' ' -f1))

        # add file to deploy if -a (ALL) is set
        this_file=""
        if [[ $ALL -eq 1 ]]; then
            this_file="${file#$PROJECT_DIR/$LOCAL_MAP}"
        else
            # otherwise only add it if checksum differs
            if [[ -z "${track[$file]}" || chksum -ne ${track[$file]} ]]; then
                this_file="${file#$PROJECT_DIR/$LOCAL_MAP}"
            else
                # file is the same - notify tracker
                echo "$file $chksum" >> "$PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${TRACKER_EXT}"
            fi
        fi

        # this file should be deployed
        if [[ -n "$this_file" ]]; then
            script_print "[$idx] Transferring $this_file -> $REMOTE_MAP/$this_file\n"
            scp -i $KEY_LOC -P $REMOTE_PORT -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$PROJECT_DIR/$LOCAL_MAP$this_file" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/$this_file" > /dev/null 2>&1

            # check if failed, maybe dir doesn't exist
            if [[ $? -ge 1 ]]; then
                script_print "[$idx] Creating potentially non-existant dir: ${file%/*}\n"
                ssh -i $KEY_LOC $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "mkdir -p $REMOTE_MAP/${this_file%/*}" > /dev/null 2>&1

                ec=$?
                if [[ $ec -ge 1 ]]; then
                    script_error "[$idx] Error creating dir: ${this_file%/*} (code=$ec - permission issue?). Stopping deploy.\n"

                    # notify tracker that this file should redeploy
                    echo "$file 0" >> "$PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${TRACKER_EXT}"
                    exit 1
                fi

                # try again with dir created
                script_print "[$idx] Re-transferring $this_file -> $REMOTE_MAP/$this_file\n"
                scp -i $KEY_LOC -P $REMOTE_PORT -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$PROJECT_DIR/$LOCAL_MAP$this_file" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/$this_file" > /dev/null 2>&1
                
                ec=$?
                if [[ $ec -ge 1 ]]; then
                    script_error "[$idx] Error for file: $this_file (code=$ec - permission issue?). Stopping deploy.\n"

                    # notify tracker that this file should redeploy
                    echo "$file 0" >> "$PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${TRACKER_EXT}"
                    exit 1
                fi
            fi

            # deploy successful - track it
            echo "$file $chksum" >> "$PROJECT_DIR/$REMOTE_DIR/${REMOTE_TARGET}${TRACKER_EXT}"
            idx=$((idx + 1))
        fi
    done

    # did not have to deploy anything
    if [[ $idx -eq 0 ]]; then
        script_print "No files to deploy, exiting.\n"
    else
        script_print "Finished.\n"
    fi
}
