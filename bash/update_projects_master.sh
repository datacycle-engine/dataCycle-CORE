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

function add_core_git_tag {
    print_body_message "Add tag to core"
    dir_name='core'
    git_repo='git@git.pixelpoint.biz:data-cycle/data-cycle-core.git'
    if [ -d "$dir_name" ]; then
        echo "$dir_name allready exists"
    else
        echo "creating directory: $dir_name"
        mkdir $dir_name
    fi
    cd $dir_name
    git clone $git_repo .
    git checkout $BRANCH_NAME
    git tag -a "$TAG_NAME" -m "core $BRANCH_NAME"
    git push origin "$TAG_NAME"
    cd ".."
    rm -Rf "$dir_name"
}

function update_core_submodule {
    cd vendor/gems/data-cycle-core
    git status
    git checkout origin/$BRANCH_NAME
    git pull origin $BRANCH_NAME
}

BRANCH_NAME='master'
dir=$(pwd)
PROJECTS=()
UPDATE_GEM=$1
TAG_NAME="core.$BRANCH_NAME.$(date +%Y%m%d)"

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
    # add new robots.txt
    # cp "$dir/migrations/robots.txt" "$dir/$project_dir/public"
    git status
    ts=$(date +%s)
    git commit -a -m "$ts: updated datacyclecore"
    git push origin $BRANCH_NAME
    git tag -a "$TAG_NAME" -m "core $BRANCH_NAME"
    git push origin "$TAG_NAME"
    cd "$dir"
    rm -Rf "$dir/$project_dir"
done

add_core_git_tag