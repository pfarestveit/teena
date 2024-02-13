#!/usr/bin/env bash

# Abort immediately if a command fails
set -e

echo
echo "------------------------"; echo
echo "  Hello friend."; echo;
echo "------------------------"; echo

tool="${TEENA__TOOL}"

options=("BOA" "Ripley" "SuiteC")

function set_tool {
    input=$(echo "${1}" | tr '[:upper:]' '[:lower:]')
    case "${input}" in
        "boa")
            tool='boac'
            friendly_tool_name=${options[0]}
            ;;
        "boac")
            tool='boac'
            friendly_tool_name=${options[0]}
            ;;
        "ripley")
            tool='ripley'
            friendly_tool_name=${options[2]}
            ;;
        "suitec")
            tool='squiggy'
            friendly_tool_name=${options[3]}
            ;;
        *)
            echo "[ERROR] Invalid option: ${REPLY}"
            exit 1
            ;;
    esac
}

# ----

options=("BOA" "Ripley" "SuiteC")

echo 'Which tool are you testing?'; echo

if [ -z "${tool}" ]
then
    PS3=$'\nEnter: '
    select opt in "${options[@]}"; do
        set_tool "${opt}"
        break
    done
else
    set_tool "${tool}"
fi

# ----

echo; echo "${friendly_tool_name} Selenium scripts:"; echo

my_list=$(echo $my_list | xargs -n1 | sort | xargs)

case "${tool}" in
    "boac")
        pattern="${tool}_*_spec.rb"
        prefix="spec/${tool}/${tool}_"
        ;;
    *)
        pattern="*_spec.rb"
        prefix="spec/${tool}/"
        ;;
esac

find "spec/${tool}" -name "${pattern}" -type f | sort -V | while read line; do
  suffix='_spec.rb'
  name=${line#"$prefix"}
  name=${name%"$suffix"}
  echo "  ${name}"
done

# ----

echo
echo "--------------------------------"; echo
echo "  Thank you and goodnight."; echo
echo "--------------------------------"; echo

exit 0
