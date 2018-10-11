#!/bin/bash

function print_header_message {
    echo "###############################################################
################## $1
##################
    "
}

function print_body_message {
    echo "################## $1
    "
}

function init_git_repo {
    dir_name=$1
    if [ -d "$dir_name" ]; then
        echo "$dir_name allready exists"
    else
        echo "creating directory: $dir_name"
        mkdir $dir_name
    fi
    cd $dir_name
    git clone $2 .
    git checkout $BRANCH_NAME
    git submodule sync --recursive
    git submodule update --init --recursive --force
}

function update_core_submodule {
    cd vendor/gems/data-cycle-core
    git status
    git checkout origin/$BRANCH_NAME
    git pull origin $BRANCH_NAME
}

BRANCH_NAME=$1
dir=$(pwd)
PROJECTS=()
UPDATE_GEM=$2

if [[ $# -eq 0 ]] ; then
    echo 'No arguments supplied'
    exit 1
fi

print_header_message "Init data-cycle git script for branch: $BRANCH_NAME"

IFS=$'\n' read -d '' -r -a PROJECTS < "./$BRANCH_NAME.txt"

if [[ ${#PROJECTS[@]} -eq 0 ]] ; then
    echo "No Projects found for branch: ${BRANCH_NAME}"
    exit 1
fi

for project in "${PROJECTS[@]}"
  do
    name=${project%%\;*}
    project_dir=${name,,}
    git_url=${project##*\;}
    print_body_message "Init $name($git_url)"

    init_git_repo $project_dir $git_url
    update_core_submodule $project_dir $git_url
    cd "$dir/$project_dir"
    if [ ! -z "$UPDATE_GEM" ] ; then
        echo "Updating gem: ${UPDATE_GEM}"
        bundle update $UPDATE_GEM
    fi
    bundle install
    git status
    ts=$(date +%s)
    git commit -a -m "$ts: updated datacyclecore"
    git push origin $BRANCH_NAME
    cd "$dir"
    rm -Rf "$dir/$project_dir"
done