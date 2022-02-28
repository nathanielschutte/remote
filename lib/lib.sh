
# lib.sh

# shell: bash
# desc: Source all lib files and define common functions
# author: Nate

LIBS="build remote"

# Source library files
DEPS_DIR="/var/www/code/devops/jobs/lib"
for lib in $LIBS; do
    . "$DEPS_DIR/${lib}_lib.sh"
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
