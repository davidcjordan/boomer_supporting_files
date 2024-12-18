#!/bin/bash

HOST="github.com"
MAX_RETRIES=10
RETRY_SECONDS=3
retries=0

while ! ping -c 1 "$HOST" &> /dev/null; do
   if [ $retries -ge $MAX_RETRIES ]; then
      printf "Maximum number of retries ($MAX_RETRIES) reached. Exiting."
      exit 1
   fi
   ((retries++))
   printf "Ping to $HOST failed. Retrying in $RETRY_SECONDS seconds: attempt $retries out of $MAX_RETRIES.\n"
   sleep $RETRY_SECONDS 
done

if [[ $(hostname) == "base"* ]]; then 
   is_base=1
else
   is_base=0
fi
if [ $is_base -eq 1 ]; then
   repo_dirs=( boomer_supporting_files audio drills control_ipc_utils ui-webserver )
else
   repo_dirs=( boomer_supporting_files)
fi

cd ~/repos
if [ $? -ne 0 ]; then
   printf "No ~/repos directory\n"
   exit 1
fi

for directory in "${repo_dirs[@]}"
do
   git -C ${directory} rev-parse
   if [ $? -ne 0 ]; then
      printf "No ~/repos/${directory} or it is not a git repository\n"
   else
      cd ${directory}
      # from: https://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
      git remote update &> /dev/null
      if [ $? -ne 0 ]; then
         printf "FAILED: git remote update for ~/repos/${directory}; skipping update of this repo.\n"
      else
         file_needs_pull=$(git status -uno | grep -c 'git pull')
         if [ $file_needs_pull -ne 0 ]; then
            printf "pulling ${directory}\n"
            git pull origin --quiet
            if [ $? -ne 0 ]; then
               printf "FAILED: git pull origin of ~/repos/${directory}\n"
            else
               printf "OK: ${directory} has been updated.\n"
            fi
         else
            printf "${directory} is up to date.\n"
         fi
      fi
   fi
   cd ~/repos
done
