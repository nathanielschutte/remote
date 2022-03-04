
# remote.sh 

# Remote project/file deploy and management
# Author: Nate

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
REQUIRED_FILES="remote_actions remote_util deploy_files deploy_project lib/lib"

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

# =============================================================================
# Context
# Remote info
REMOTE_USER=""              # Set with -u, required
REMOTE_HOST=""              # Set with -h, required
REMOTE_PORT=""              # Set with -p, default to 22
REMOTE_MAP=""               # Set with -o, required
LOCAL_MAP=""                # Set with -f, default to project dir
KEY_LOC=""                  # Set with -i, required
REMOTE_TARGET=""

# Deploy options
DEPLOY_FILES=0  # deploy project vs. specific files
ALL=0           # deploy all of project despite checksums
SAFE_OVERWRITE=0

# Specific files to deploy
FILENAMES=""

# Selection options
IGNORE_DOT_DIRS=
IGNORE_DOT_FILES=
IGNORE_PATTERN=""
IGNORE_DIRS=""
IGNORE_FILES=""

VERBOSE=1
DEBUG=0

# =============================================================================
# Positional args
# Script action - required arg 1
if [[ -n "$1" ]] && [[ ! "$1" =~ -.* ]]; then
    REMOTE_ACTION="$1"
    shift 1
else
    REMOTE_ACTION='help'
fi
# Tag name - optional arg 2
if [[ -n "$1" ]] && [[ ! "$1" =~ -.* ]]; then
    FILENAMES="$1" # could also be a file for file send
    ACTION_TAG="$1"
    shift 1
else
    ACTION_TAG=''
fi

# Grab all preceding non-flag args as filenames
while [[ -n "$1" && ! "$1" =~ ^- ]]; do 
    FILENAMES="$FILENAMES $1"
    shift 1
done
# =============================================================================

# =============================================================================
# Args
get_args() {
    while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do 
        case $1 in
            -V | --version )
                echo $VERSION
                exit
                ;;
            -f | --files )
                DEPLOY_FILES=1
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
            -z0 | --include-dot-files )
                IGNORE_DOT_FILES=0
                ;;
            -Z0 | --include-dot-dirs )
                IGNORE_DOT_DIRS=0
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
            -c | --copy )
                shift; ACTION_COPY="$1"
                ;;
            --debug )
                DEBUG=1
                ;;

        esac; shift; done
        
    if [[ "$1" == '--' ]]; then shift; fi

    # More filenames
    if [[ -z "$FILENAMES" ]]; then
        FILENAMES="$@"
    else
        FILENAMES="$FILENAMES $@"
    fi

    # Ignore files and dirs
    [[ -n "$LOCAL_MAP" ]] && LOCAL_MAP="${LOCAL_MAP%/}" && LOCAL_MAP="$LOCAL_MAP/"
    if [[ -n "$IGNORE_PATTERN" ]]; then
        for path in $IGNORE_PATTERN; do
            if [[ -d "$PROJECT_DIR/$LOCAL_MAP$path" ]]; then
                if [[ -z "$IGNORE_DIRS" ]]; then
                    IGNORE_DIRS="$path"
                else
                    IGNORE_DIRS="$IGNORE_DIRS $path"
                fi
            fi
            if [[ -f "$PROJECT_DIR/$LOCAL_MAP$path" ]]; then
                if [[ -z "$IGNORE_FILES" ]]; then
                    IGNORE_FILES="$path"
                else
                    IGNORE_FILES="$IGNORE_FILES $path"
                fi
            fi
        done
        script_debug 'found ignore files/dirs: %s %s\n' "$IGNORE_FILES" "$IGNORE_DIRS"
    fi
}
# =============================================================================

# =============================================================================
# Script
get_args "$@"

# Clean params
LOCAL_MAP="${LOCAL_MAP%/}"
REMOTE_MAP="${REMOTE_MAP%/}"

# ACTION TABLE - ANYWHERE
case $REMOTE_ACTION in
    'help' )
        usage
        exit
        ;;
    'init' )
        init_project || script_error "Failed to initialize.\n"
        exit
        ;;
    'send' )
        send_files
        exit
        ;;
esac

# Load project info
check_remote_project 1
get_target

# ACTION TABLE - IN PROJECT
case $REMOTE_ACTION in
    # sub-table - offline
    'list' | 'ls' | 'status' )
        project_info
        ;;
    'info' | 'i' | 'show' )
        project_host_info
        ;;
    'use'  | 'u' | 'target' )
        set_project_target
        ;;

    # sub-table - connection
    'add' | 'a' )
        add_project_host
        ;;
    'edit' | 'e' )
        edit_project_host
        ;;
    'deploy' | 'd' )
        project_deploy
        ;;
    'run' | 'r' )
        usage
        ;;
    * )
        script_error 'Unknown action "%s"' "$REMOTE_ACTION"
        exit 1
        ;;
esac
# =============================================================================
