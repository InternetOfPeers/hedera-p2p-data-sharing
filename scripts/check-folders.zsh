#!/bin/zsh

for folder in ./read/*; do
    local foldername=$(echo $folder | cut -c 8-)
    ./check-files.zsh $foldername read
done
