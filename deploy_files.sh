
# deploy_files.sh
# SCP filename deploy

deploy_f() {
    for arg in $EXE_ARGS; do
        is_flag='false'
        flags=${ARGS/:/}
        for (( i=0; i<${#flags}; i++ )); do
            if [[ $arg == "-${flags:$i:1}" ]]; then
                is_flag='true'
            fi
        done
        [[ $is_flag == 'true' ]] && continue
        # Append local map path if exists
        if [[ -n $LOCAL_MAP ]]; then
            file="$LOCAL_MAP/$arg"
        else
            file=$arg
        fi
        # Try to append current dir if file not found
        if [[ ! -f "$file" ]]; then
            arg="$(pwd)/$file"
            # otherwise skip this garbage
            if [[ ! -f "$file" ]]; then
                continue;
            fi
        fi
        # Append to files list
        if [[ ${#FILESNAMES} -eq 0 ]]; then
            FILENAMES="$file"
        else
            FILENAMES="$FILENAMES $file"
        fi
    done

    # Check for no files
    if [[ ${#FILENAMES} -eq 0 ]]; then
        printf "No files to deploy, exiting.\n"
        exit 0
    fi

    # Deploy files
    idx=1
    for FILENAME in $FILENAMES; do
        printf "[$idx] Transfering $FILENAME -> $REMOTE_MAP/$FILENAME...\n"
        scp -q -P $REMOTE_PORT $FILENAME $REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/$FILENAME
        idx=$((idx+1))
    done
}
