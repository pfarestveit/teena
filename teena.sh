#!/usr/bin/env bash

# Abort immediately if a command fails
set -e

trap "killall background" EXIT

echo
echo "------------------------"; echo
echo "  Teena welcomes you."; echo
echo "------------------------"; echo

PS3=$'\nWhich tool are you testing? '

options=("BOA" "Junction" "SuiteC")

tool_being_tested=''

select opt in "${options[@]}"
do
    case ${opt} in
        "BOA")
            tool_being_tested='boac'
            friendly_tool_name=${options[0]}
            test_dept=$(grep '^  test_dept' "${HOME}/.webdriver-config/settings.yml" | awk '{print $NF}')
            echo; echo "Boa will be tested with test_dept: ${test_dept}"; echo
            break
            ;;
        "Junction")
            tool_being_tested='junction'
            friendly_tool_name=${options[1]}
            break
            ;;
        "SuiteC")
            tool_being_tested='squiggy'
            friendly_tool_name=${options[2]}
            break
            ;;
        *)
            echo "[ERROR] Invalid option: ${REPLY}"
            exit 1
            ;;
    esac
done

echo; echo "Enter version of ${tool_being_tested} being tested (e.g., '2.15')."
echo; echo -n "    > "

read version

echo
echo "Enter snippet (e.g., 'user_role' or 'user_role_coe') to match the ${tool_being_tested} Selenium script(s) you want to run."
echo "Blank input will run all tests."; echo
echo -n "    > "

read test_suite

echo; echo "Enter arbitrary keyword (e.g., 'COENG') to add to log file name. Hit return to skip."
echo; echo -n "    > "

read arbitrary_keyword

echo; echo

echo
echo "Enter your username. Hit return to skip."
echo
printf "    > "

read username

echo
echo "Enter your password. Hit return to skip."
echo
printf "    > "

read -s password

DATE=$(date '+%Y-%m-%d-%H%M%S')

[[ "${arbitrary_keyword}" ]] && suffix="${arbitrary_keyword}-${DATE}" || suffix="${DATE}"

summary="${tool_being_tested}-v${version}-${test_suite:-'all'}-${suffix}"

if [[ -z "${test_suite}" ]] ; then
    echo; echo "Running ALL tests of ${friendly_tool_name} v${version}"
    echo
    rake VERSION="${summary}" USER="${username}" PASS="${password}" "${tool_being_tested}"
else
    echo; echo "Running '${test_suite}' tests of ${friendly_tool_name} v${version}"
    echo
    rake SCRIPTS="${test_suite}" VERSION="${summary}" USER="${username}" PASS="${password}" "${tool_being_tested}"
fi

echo
echo "--------------------------------"; echo
echo "  We are done. Teena thanks you."; echo
echo "--------------------------------"
echo; echo

exit 0
