
# lib_build.sh

# shell: bash
# desc: Common display and build step functions
# author: Nate


# Display and build functions #################################################
# Track build steps
declare -A lib_build_steps

# Display build step
# Automatically exits on fail unless set otherwise
# displayStep <header> [<function>] [<exit on fail>]
function buildStep() {
    assertArgMin $# 1 "buildStep"

    local header="${1^^}"
    printf '================================================\n'
    printf 'Running '\''%s'\'' ...\n' "$header"

    #[ ${#steps[@]} -eq 0 ] && declare -A steps

    if [ -z "$2" ]; then
        lib_build_steps["$header"]=1
        return 0
    else
        local func="$2"
    fi

    if [[ $(type -t "${func%% *}") == function ]]; then
        if "$func"; then
            lib_build_steps["$header"]=1
            printf 'Finished: %s.\n' "$header"
            printf '================================================\n'
        else
            lib_build_steps["$header"]=0
            if [ -n "$3" ] && [ "$3" == "false" ]; then
                displayFail "build step '$header' failed, continuing."
                printf '================================================\n'
            else
                displayFail "build step '$header' failed, exiting."
                printf "\n"
                exit 1
            fi
        fi
    else
        displayFail "build step function does not exist, exiting."
        exit 1
    fi
}

# Display summarized build step results
function displayBuildResults() {
    [ ${#lib_build_steps[@]} -eq 0 ] && return

    local total_count=${#lib_build_steps[@]}
    local pass_count=0
    for header in "${!lib_build_steps[@]}"; do
        if [ ${lib_build_steps["$header"]} -eq 1 ]; then
            pass_count=$((pass_count+1))
            unset lib_build_steps["$header"]
        fi
    done

    printf '\nBuild steps finished successfuly: %s/%s\n' "$pass_count" "$total_count"
    [ $pass_count -eq $total_count ] && return

    printf 'Builds steps with error: \n'
    for header in "${!lib_build_steps[@]}"; do
        printf '    %s\n' "$header"
    done
    printf '\n'
}

# Display status code for process 'header' (ignore fails)
# displayStatus <code> <header> [<extra message>]
function displayStatus() {
    assertArgMin $# 2 "displayStatus"
    local code="$1"
    local header="$2"
    local stat_msg=""
    header="${header^^}"
    [ -n "$3" ] && stat_msg="($3)"
    if [ "$code" -eq 0 ]; then
        printf '%s completed with code %s %s\n' "$header" "$code" "$stat_msg"
    else
        displayFail "$header failed $stat_msg"
    fi
}

# Display failure
# displayFail <error message>
function displayFail() {
    local err_msg="unknown"
    [ -n "$1" ] && err_msg="$1"
    >2& printf 'Error: %s\n' "$err_msg"
}

# Check exact argument count
# assertArgCount <actual> <expected>
function assertArgCount() {
    local arg_act=$1
    local arg_exp=$2
    local assert_msg=""
    [ -n "$3" ] && assert_msg="($3)"
    if [[ $arg_act -ne $arg_exp ]]; then
        displayFail "incorrect argument count $arg_act/$arg_act $assert_msg"
        exit 1
    fi
}

# Check minimum argument count
# assertArgCount <actual> <minimum>
function assertArgMin() {
    [ "$#" -eq 0 ] && return 1
    local arg_act="$1" # ignore $0
    local arg_exp=$2
    local assert_msg=""
    [ -n "$3" ] && assert_msg="($3)"
    if [[ $arg_act -lt $arg_exp ]]; then
        displayFail "too few arguments $arg_act/$arg_exp $assert_msg"
        exit 1
    fi
}
