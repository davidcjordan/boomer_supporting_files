#!/bin/bash

# use rsync to update this repo on the cameras & speaker

user_id="pi"
dst_dir="/home/${user_id}/repos"
src_dir="${dst_dir}/boomer_supporting_files"

# rsync -avhe ssh --del --exclude='.git/' --exclude='reference_files/' --dry-run $src_dir left:$dst_dir
rsync -avhe ssh --del --exclude='.git/' --exclude='reference_files/' $src_dir left:$dst_dir
rsync -avhe ssh --del --exclude='.git/' --exclude='reference_files/' $src_dir right:$dst_dir

printf "\n\n -- Now issue the following commands:\n"
printf "ssh left\n"
printf "incrontab ${repo_dir}/incrontab.txt\n"
printf "exit\n"
printf "ssh right\n"
printf "incrontab ${repo_dir}/incrontab.txt\n"
printf "exit\n"