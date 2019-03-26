#!/usr/bin/env bash

# Abort immediately if a command fails
set -e

trap "killall background" EXIT

echo
echo "------------------------"; echo
echo "  Teena welcomes you."; echo
echo "------------------------"; echo

tool_being_tested=''

options=("Boa" "OEC" "Junction" "SuiteC")

PS3=$'\nWhich tool are you testing? '

select opt in "${options[@]}"
do
    case ${opt} in
        "Boa")
            tool_being_tested='boac'
            friendly_tool_name=${options[0]}
            break
            ;;
        "OEC")
            tool_being_tested='oec'
            friendly_tool_name=${options[1]}
            break
            ;;
        "Junction")
            tool_being_tested='junction'
            friendly_tool_name=${options[2]}
            break
            ;;
        "SuiteC")
            tool_being_tested='suitec'
            friendly_tool_name=${options[3]}
            break
            ;;
        *)
            echo "[ERROR] Invalid option: ${REPLY}"
            exit 1
            ;;
    esac
done

echo; echo "Enter version of ${tool_being_tested} being tested."
echo; echo -n "    > "

read version

echo
echo "Enter snippet (e.g., 'curated') to match the ${tool_being_tested} Selenium script(s) you want to run."
echo "Blank input will run all tests."; echo
echo -n "    > "

read scripts_snippet

echo; echo

DATE=$(date '+%Y-%m-%d_%H-%M-%S')
script_run_version="${tool_being_tested}-${version}_${DATE}"

if [[ -z "${scripts_snippet}" ]] ; then
    echo; echo "Running ALL tests of ${friendly_tool_name} v${version}"
    echo
    rake VERSION="${script_run_version}" "${tool_being_tested}"
else
    echo; echo "Running '${scripts_snippet}' tests of ${friendly_tool_name} v${version}"
    echo
    rake SCRIPTS="${scripts_snippet}" VERSION="${script_run_version}" "${tool_being_tested}"
fi

echo
echo "--------------------------------"; echo
echo "  We are done. Teena thanks you."; echo
echo "--------------------------------"
echo; echo

exit 0
