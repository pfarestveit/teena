#!/usr/bin/env bash

# Abort immediately if a command fails
set -e
trap "killall background" EXIT

echo
echo "------------------------"; echo
echo "   PREPARE TO COMPARE!  "; echo;
echo "------------------------"; echo

# ----

echo 'Are you testing the inactivation scripts in Junction vs Ripley? '

inactivation_options=("yes" "no")

select opt in "${inactivation_options[@]}"; do
  case ${opt} in
  "yes")
    inactivation=true
    break
    ;;
  "no")
    inactivation=false
    break
    ;;
  esac
done

echo

# ----

if [ -z "${csv_1}" ]
then
    echo
    echo "Enter the file path to CSV 1. If the file is in the webdriver-output/test-output dir, simply enter the file name"
    echo; echo -n "    > "

    read csv_1
fi

# ----

if [ -z "${csv_2}" ]
then
    echo
    echo "Enter the file path to CSV 2. If the file is in the webdriver-output/test-output dir, simply enter the file name"
    echo -n "    > "

    read csv_2
fi

# ----

INACTIVATE="${inactivation}" CSV_1="${csv_1}" CSV_2="${csv_2}" ruby scripts/csv_compare_script.rb

echo
echo "----------------------------------------------------------"; echo
echo "                     DARE TO COMPARE!                     "; echo
echo "  You'll find your diffs in webdriver-output/test-output  "; echo
echo "----------------------------------------------------------"; echo
echo

exit 0
