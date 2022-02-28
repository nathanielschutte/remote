
# SCP deploy script

# ====================================
# Remote config
REMOTE_USER="nate"
REMOTE_HOST=""      # Set with -h.  Sets port to 22
REMOTE_PORT=""      # Set with -p.  Sets host to localhost
REMOTE_MAP=""       # Set with -o
LOCAL_MAP=""        # Set with -f
KEY_LOC="C:\\Users\\Nate\\.ssh\\aws-access.pem"

# Internal files
TRACKER_FILE='.deploy'
REMOTE_FILE='.remote'

# Specific files
FILENAMES=""

# Selection config
IGNORE_DOT_DIRS='true'
IGNORE_DOT_FILES='true'
IGNORE_DIRS=""
IGNORE_FILES="$0"

# Output
V_SPEC='false'
QUIET='false'
# ====================================

# Arg descriptor
ARGS="rvaiIh:p:qf:o:"

# Capture script args
EXE_ARGS="$@"

# Get deploy options
RECURSIVE=0     # deploy directory vs. specific files
ALL=0           # deploy all despite checksums
while getopts "$ARGS" flag; do
    case "${flag}" in
        r)
            RECURSIVE=1
            ;;
        v)
            V_SPEC='true'
            ;;
        a)
            ALL=1
            ;;
        i)
            IGNORE_DOT_FILES=1
            ;;
        I)
            IGNORE_DOT_DIRS=1
            ;;
        h)
            REMOTE_HOST="$OPTARG"
            REMOTE_PORT=22
            ;;
        p)
            REMOTE_HOST="localhost"
            REMOTE_PORT="$OPTARG"
            ;;
        q)
            QUIET='true'
            ;;
        f)
            LOCAL_MAP="${OPTARG%/}"
            ;;
        o)
            REMOTE_MAP="${OPTARG%/}"
            ;;
    esac
done

# Check key file
printf "Checking key..."
if [[ -r $KEY_LOC ]]; then
    printf "ok.\n"
else
    printf "not found.\n"
    exit 1
fi

# Check connection
printf "Connecting to $REMOTE_HOST..."
connected='false'
$(ssh -q -i $KEY_LOC -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST exit) && connected='true'
if [[ $connected == 'false' ]]; then
    printf "failed.\n"
    exit 1
else
    printf "success!\n"
fi

# Usage
usage() {
    printf "Tracked directory deploy:\n\t$0 -r -f <local dir> -o <remote dir>"
    exit 1
}

# Deploy context
context() {
    printf "\nCONTEXT\n"
    printf "Deploying to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT\n"
    printf "Local dir: $LOCAL_MAP\nRemote dir: $REMOTE_MAP\n"
    printf "Ignore .dirs: $IGNORE_DOT_DIRS\n"
    printf "Ignore .files: $IGNORE_DOT_FILES\n"
    printf "Ignoring: $IGNORE_DIRS\n$IGNORE_FILES\n"
    printf "\n"
}

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

# SCP recursive directory deploy - tracking
deploy_r() {

    # load current file hashes - skip if -a (ALL) is set
    if [[ $ALL -eq 0 ]]; then
        printf "Collecting files...\n"
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
                [[ $V_SPEC == 'true' ]] && echo "skipping $file"
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
            [[ ${file##*/} == $ignore ]] && skip=1 && [[ $V_SPEC == 'true' ]] && echo "skipping $file"
        done
        for ignore in $IGNORE_DIRS; do
            [[ $file =~ .*\/$ignore[^/]*/.* ]] && skip=1 && [[ $V_SPEC == 'true' ]] && echo "skipping $file"
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
        printf "No files to deploy, exiting.\n"
        exit 0
    fi
    [[ $V_SPEC == 'true' ]] && printf "\nStarting deploy...\n"
    [[ $V_SPEC == 'true' ]] && printf "Path local: $LOCAL_MAP/\n"
    [[ $V_SPEC == 'true' ]] && printf "Path remote: $REMOTE_MAP/\n"
    printf "Starting transfer to $REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/...\n"

    # Deploy files
    idx=0
    for file in ${FILES[@]}; do
        printf "[$idx] Transferring $LOCAL_MAP/$file -> $REMOTE_MAP/$file\n"
        scp -i $KEY_LOC -q $LOCAL_MAP/$file $REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/$file

        # check if failed, maybe dir doesn't exist
        if [[ $? -ge 1 ]]; then
            printf "Creating non-existant dir: ${file%/*}\n"
            ssh $REMOTE_USER@$REMOTE_HOST -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "mkdir -p $REMOTE_MAP/${file%/*}"

            # try again with dir created
            scp -i $KEY_LOC -q $LOCAL_MAP/$file $REMOTE_USER@$REMOTE_HOST:$REMOTE_MAP/$file
            ec=$?
            if [[ $ec -ge 1 ]]; then
                printf "[$idx] ERROR for file: $file (code=$ec). Stopping deploy.\n"
                exit 1
            fi
        fi
        idx=$((idx + 1))
    done
}

printf "Deploying...\n"

# deploy directory
if [[ $RECURSIVE -eq 1 ]]; then
    deploy_r

# deploy specific files
else
    deploy_f
fi

printf "Done\n"
