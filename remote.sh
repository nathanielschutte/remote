
# remote.sh 
# Remote project/file deploy and management

# This tool version
VERSION="1.0"

# Check bash version
BASH_MAJOR="$(echo ${BASH_VERSION} | cut -d '.' -f1)"
if [[ $BASH_MAJOR -lt 4 ]]; then
    printf 'Must be using bash version 4+ (currently %s)\n' "$BASH_MAJOR"
    exit
fi

SCRIPT_SRC="$0"
SCRIPT_DIR="${SCRIPT_SRC%/*}"
SCRIPT_NAME="${SCRIPT_SRC##*/}" && SCRIPT_NAME="${SCRIPT_NAME%.*}"

PROJECT_DIR="$(pwd)"

# =============================================================================
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
REMOTE_DIR='.remote'
TARGET_FILE='target'
TRACKER_EXT='.deploy'       # host.deploy
REMOTE_EXT='.remote'        # host.remote
PROFILES_FILE='profiles'

[ ! -f "$PROFILES_FILE" ] && touch "$SCRIPT_DIR/$PROFILES_FILE"


# =============================================================================
# Context
# Remote info
REMOTE_USER=""              # Set with -u, required
REMOTE_HOST="localhost"     # Set with -h, default to localhost
REMOTE_PORT="22"            # Set with -p, default to 22
REMOTE_MAP=""               # Set with -o, required
LOCAL_MAP=""                # Set with -f, required
KEY_LOC=""                  # Set with -i, required
REMOTE_TARGET=""

# Deploy options
RECURSIVE=1     # deploy directory vs. specific files
ALL=0           # deploy all despite checksums
SAFE_OVERWRITE=0

# Specific files to deploy
FILENAMES=""

# Selection options
IGNORE_DOT_DIRS=0
IGNORE_DOT_FILES=0
IGNORE_PATTERN=""
IGNORE_DIRS=""
IGNORE_FILES="$TRACKER_FILE $REMOTE_FILE"

VERBOSE=1
DEBUG=0

# =============================================================================
# Script action - required arg 1
if [[ -n "$1" ]] && [[ ! "$1" =~ -.* ]]; then
    REMOTE_ACTION="$1"
    shift 1
else
    REMOTE_ACTION='help'
fi
# Tag name - optional arg 2
if [[ -n "$1" ]] && [[ ! "$1" =~ -.* ]]; then
    ACTION_TAG="$1"
    shift 1
else
    ACTION_TAG=''
fi
#script_debug 'action: %s  tag: %s\n' "$REMOTE_ACTION" "$ACTION_TAG"

# =============================================================================
# Args
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
        -o | --remote-path )
            shift; REMOTE_MAP="${1%/}"
            ;;
        -i | --key-file )
            shift; KEY_LOC=$1
            ;;
        -u | --user )
            shift; REMOTE_USER=$1
            ;;
        -U | --profile )
            shift; PROFILE=$1
            ;;
        -s | --safe )
            SAFE_OVERWRITE=1
            ;;
        -e | --exclude )
            shift; IGNORE_PATTERN="$IGNORE_PATTERN $1"
            ;;
        -E | --exclude-overwrite )
            shift; IGNORE_PATTERN="$1"
            ;;

    esac; shift; done
    
if [[ "$1" == '--' ]]; then shift; fi
# =============================================================================
# Functions
usage() {
    printf "HELP"
    exit 1
}

_print_host() {
    echo "host=$REMOTE_HOST"
    echo "port=$REMOTE_PORT"
    echo "user=$REMOTE_USER"
    echo "identity-file=$KEY_LOC"
    echo "ignore-dot-dirs=$IGNORE_DOT_DIRS"
    echo "ignore-dot-files=$IGNORE_DOT_FILES"
    echo "ignore-pattern=$IGNORE_PATTERN"
    echo "local-path="
    echo "remote-path="
}

# Check if .remote is present
# Pass an arg to allow this to kill the program on fail
check_remote_project() {
    if [[ -n $(find $PROJECT_DIR -type d -name ".remote") ]]; then
        if [[ -n $(find "$PROJECT_DIR/$REMOTE_DIR" -type f -name "$TARGET_FILE") ]]; then
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
    # Check key file
    script_debug "Checking key..."
    if [[ -n $KEY_LOC && ! -r $KEY_LOC ]]; then
        script_debug "not found.\n"
        if [[ -n "$1" ]]; then
            script_error 'Identity file does not exist: %s\n' "$KEY_LOC"
            exit 1
        else
            return 2 # bad identity file
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
    connected=0

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
    if [[ -n "$(find $PROJECT_DIR/$REMOTE_DIR -type f -name ${ACTION_TAG}${REMOTE_EXT})" ]]; then
        script_debug 'exists\n'
        return 0
    else
        script_debug 'not found\n'
        return 1
    fi
}

# =============================================================================
# ACTION FUNCTIONS
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

project_info() {
    get_target

    count=0
    script_print 'Hosts:\n'
    for file in $(find $PROJECT_DIR/$REMOTE_DIR -type f -name *$REMOTE_EXT); do
        tag="${file##*/}" && tag="${tag%$REMOTE_EXT}"
        [[ -z "$tag" ]] && continue
        if [[ $tag == $REMOTE_TARGET ]]; then
            script_print ' * %s\n' "$tag" 
        else
            script_print '   %s\n' "$tag" 
        fi
        count=$((count+1))
    done
    [[ $count -eq 0 ]] && script_print '   None\n'
    script_print '\n'
}

add_project_host() { 
    check_tag_passed
    if check_tag_exists; then
        script_error 'Tag "%s" already exists.\n' "$ACTION_TAG"
        return 1
    fi
    check_connection 1
    _print_host > "$PROJECT_DIR/$REMOTE_DIR/${ACTION_TAG}${REMOTE_EXT}"

    get_target
    if [[ -z $REMOTE_TARGET ]]; then
        script_print 'Making this host (%s) the new target\n' "$ACTION_TAG"
        REMOTE_TARGET="$ACTION_TAG"
        set_target
    fi
}

set_project_target() {
    check_tag_passed
    if check_tag_exists; then
        REMOTE_TARGET="$ACTION_TAG"
        set_target
    else
        script_error 'Tag "%s" does not exist.\n' "$ACTION_TAG"
    fi
}

# =============================================================================
# ACTION TABLE - ANYWHERE
case $REMOTE_ACTION in
    'help' )
        usage
        ;;
    'init' )
        init_project || script_error "Failed to initialize.\n"
        ;;
esac

# ACTION TABLE - IN PROJECT
check_remote_project 1
case $REMOTE_ACTION in
    # subtable - offline
    'info' )
        project_info
        ;;
    'use' )
        set_project_target
        ;;

    # subtable - connection
    'add' )
        add_project_host
        ;;
    'profile' )
        usage
        ;;
    'edit' )
        usage
        ;;
    'deploy' )
        usage
        ;;
esac

exit 0
