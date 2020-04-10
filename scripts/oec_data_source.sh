#!/usr/bin/env bash

set -e

echo
echo "----------------------------------"
echo "  OEC data source updating script "
echo "----------------------------------"
echo

echo 'What kind of browser do we want to use? Enter 1 or 2. '

headless_options=("regular" "headless")

select opt in "${headless_options[@]}"; do
  case ${opt} in
  "headless")
    headless=true
    break
    ;;
  "regular")
    headless=false
    break
    ;;
  *)
    echo "[ERROR] Computer says no."
    exit 1
    ;;
  esac
done

echo
echo 'Which environment are we updating? Enter 1 or 2. '

env_options=("prod" "qa")

select opt in "${env_options[@]}"; do
  case ${opt} in
  "prod")
    env_option="prod"
    break
    ;;
  "qa")
    env_option="qa"
    break
    ;;
  *)
    echo "[ERROR] Computer says no"
    exit 1
    ;;
  esac
done

echo
echo 'Which data source are we updating? Enter 1, 2, or 3'

refresh_options=("campus" "haas" "extension")

select opt in "${refresh_options[@]}"; do
  case ${opt} in
  "campus")
    data_source="campus"
    break
    ;;
  "haas")
    data_source="haas"
    break
    ;;
  "extension")
    data_source="extension"
    break
    ;;
  *)
    echo "[ERROR] Computer says no"
    exit 1
    ;;
  esac
done

echo
echo 'Which update workflow are we using? Enter 1 or 2. '

workflow_options=("path" "upload")

select opt in "${workflow_options[@]}"; do
  case ${opt} in
  "path")
    workflow="path"
    break
    ;;
  "upload")
    workflow="upload"
    break
    ;;
  *)
    echo "[ERROR] Computer says no"
    exit 1
    ;;
  esac
done

echo
echo "Enter the Blue username"
echo
printf "    > "

read username

echo
echo "Enter the Blue password"
echo
printf "    > "

read -s password

echo
echo "Running data source update for ${data_source} in ${env_option} environment using ${workflow} workflow"

if $headless; then
  ruby oec_data_source_script.rb "${env_option}" "${data_source}" "${workflow}" "username=${username}" "password=${password}" "headless"
else
  ruby oec_data_source_script.rb "${env_option}" "${data_source}" "${workflow}" "username=${username}" "password=${password}"
fi

exit 0
