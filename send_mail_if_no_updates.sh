#!/usr/bin/env bash

for file in `find /var/log -type f -name "*.log"`
do
    if [ -f "$file" ]
    then
        if ! ((`find -wholename $file -type f -mmin +1`)); then
            echo "File $file was not updated for one hour" | mail -s alarm! example@example.com
        fi
    fi
done