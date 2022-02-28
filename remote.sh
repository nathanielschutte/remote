
# remote.sh 
# Remote project/file deploy and management

VERSION="1.0"

SCRIPT_SRC="$0"
SCRIPT_DIR="${SCRIPT_SRC%/*}"
SCRIPT_NAME="${SCRIPT_SRC##*/}" && SCRIPT_NAME="${SCRIPT_NAME%.*}"

PROJECT_DIR="$(pwd)"

# ====================================
# Ensure everything is available
REQUIRED_FILES="deploy_files deploy_project remote_config lib/lib"

for file in $REQUIRED_FILES; do
    if [ ! -f "$SCRIPT_DIR/$file.sh" ]; then
        echo "$SCRIPT_NAME: missing file '$file' in dir $SCRIPT_DIR, exiting."
        exit 1
    fi

    source "$SCRIPT_DIR/$file.sh"
done

# Internal files
TRACKER_FILE='.deploy'
REMOTE_DIR='.remote'
REMOTE_EXT='.remote'       # host.remote
PROFILES_FILE='profiles'

[ ! -f "$PROFILES_FILE" ] && touch "$SCRIPT_DIR/$PROFILES_FILE"

# ====================================
# Context
# Remote info
REMOTE_USER=""              # Set with -u, required
REMOTE_HOST="localhost"     # Set with -h, default to localhost
REMOTE_PORT="22"            # Set with -p, default to 22
REMOTE_MAP=""               # Set with -o, required
LOCAL_MAP=""                # Set with -f, required
KEY_LOC=""                  # Set with -i, required

# Deploy options
RECURSIVE=1     # deploy directory vs. specific files
ALL=0           # deploy all despite checksums

# Specific files to deploy
FILENAMES=""

# Selection config
IGNORE_DOT_DIRS='true'
IGNORE_DOT_FILES='true'
IGNORE_DIRS=""
IGNORE_FILES="$TRACKER_FILE $REMOTE_FILE"

VERBOSE=1
DEBUG=1
# ====================================

# ====================================
# Functions
usage() {
    printf "Tracked directory deploy:\n\t$0 -r -f <local dir> -o <remote dir>"
    exit 1
}

# Check if args provide enough info on remote host

# ====================================



# ====================================
# Script
if [[ -n "$1" ]] && [[ ! "$1" =~ -. ]]; then
    REMOTE_ACTION="$1"
    shift 1
else
    REMOTE_ACTION='help'
fi

script_debug 'action is "%s"\n' "$REMOTE_ACTION"

ARGS="razZh:p:qf:o:i:u:w:"
EXE_ARGS="$@"

while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do 
    case $1 in
        -V | --version )
            echo $VERSION
            exit
            ;;
        -f | --files )
            RECURSIVE=0
            ;;
        -a | --all )
            ALL=1
            ;;
        -z | --ignore-dot-files )
            IGNORE_DOT_FILES=1
            ;;
        -Z | --ignore-dot-dirs )
            IGNORE_DOT_DIRS=1
            ;;
        -h | --host )
            shift; REMOTE_HOST=$1
            ;;
        -p | --port )
            shift; REMOTE_PORT=$1
            ;;
        -q | --quiet )
            VERBOSE=0
            ;;
        -l | --local-path )
            shift; LOCAL_MAP="${1%/}"
            ;;
        -r | --remote-path )
            shift; REMOTE_MAP="${1%/}"
            ;;
        -i | --key-file )
            KEY_LOC=$1
            ;;
        -u | --user )
            REMOTE_USER=$1
            ;;
        -U | --profile )
            PROFILE=$1
            ;;
    esac; shift; done

if [[ "$1" == '--' ]]; then shift; fi

# Check key file
script_print "Checking key..."
if [[ -r $KEY_LOC ]]; then
    script_print "ok.\n" 1
else
    script_print "not found.\n" 1
    exit 1
fi

# Check connection
script_print "Connecting to $REMOTE_HOST..."
connected=0
$(ssh -q -i $KEY_LOC -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST exit > /dev/null 2>&1) && connected=1
if [ "$connected" -eq 0 ]; then
    script_print "failed.\n" 1
    exit 1
else
    script_print "success!\n" 1
fi

# Deploy
script_print "Deploying...\n"
if [[ $RECURSIVE -eq 1 ]]; then
    deploy_r
else
    deploy_f
fi
script_print "Done\n"
