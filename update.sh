#!/bin/bash

ping -c1 github.com &> /dev/null
if [ $? -ne 0 ]; then
   printf "Can't ping github.com: Not connected to the internet? resolv.con error?\n"
   exit 1
fi

if [[ -z "${GITHUB_TOKEN}" && is_base -eq 1 ]]; then 
   echo "enter: 'export GITHUB_TOKEN=something' before running script"; 
   exit 1
fi

# to be deleted if not used:
if [[ $(hostname) == "base"* ]]; then 
   is_base=1
else
   is_base=0
fi

cd ~/repos
if [ $? -ne 0 ]; then
   printf "No ~/repos directory\n"
   exit 1
fi

repo_dirs=( audio drills boomer_supporting_files control_ipc_utils ui-webserver )

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
