
# lib.sh

# shell: bash
# desc: Source all lib files and define common functions
# author: Nate


# ====================================
# Select extra libraries to use
LIBS="remote"
# ====================================


# ====================================
# Script info
if [ -z "$SCRIPT_SRC" ]; then
    SCRIPT_SRC="$0"
fi

if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="${SCRIPT_SRC%/*}"
fi

if [ -z "$SCRIPT_NAME" ]; then
    SCRIPT_NAME="${SCRIPT_SRC##*/}" && SCRIPT_NAME="${SCRIPT_NAME%.*}"
fi

# Set LIB_DIR in calling script if lib files are somewhere else
if [ -z "$LIB_DIR" ]; then
    LIB_DIR="$SCRIPT_DIR/lib"
fi

# Set VERBOSE in calling script
if [ -z "$VERBOSE" ]; then
    VERBOSE=0
fi

# Set DEBUG in calling script
if [ -z "$DEBUG" ]; then
    DEBUG=0
fi

# Source library files
for lib in $LIBS; do
    if [ ! -f "$LIB_DIR/lib_${lib}.sh" ]; then
        echo "$SCRIPT_NAME: missing lib '$lib', exiting."
        exit 1
    fi

    source "$LIB_DIR/lib_${lib}.sh"
done

# Lib common functions
# Check positional script args and print usage on error
# checkArgs <script name> <actual arg count> <expected arg names...>
function checkPositionalArgs() {
    assertArgMin $# 2 "checkArgs"
    local script_name="$1"
    local count_act="$2"

    local count_exp="$(($#-2))"
    [ "$count_exp" -eq 0 ] && return 0

    local arg_list=("${@:3}")
    local arg_names="${arg_list[*]}"
    if [[ $count_act -lt $count_exp ]]; then
        displayFail "too few positional args ($count_act/$count_exp)"
        printf 'Usage: %s %s\n' "$script_name" "$arg_names"
    else
        return 0
    fi
}

# Conditional print (verbose) with optional script name tag
script_print() {
    if [[ $VERBOSE -eq 1 ]]; then
        [[ -z "$1" ]] && printf '%s: ' "$SCRIPT_NAME"
        printf "${@}"
    fi
}

# Conditional print (debug)
script_debug() {
    if [[ $VERBOSE -eq 1 ]]; then
        [[ -z "$1" ]] && printf '%s: ' "DEBUG"
        printf "${@}"
    fi
}
