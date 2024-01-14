#!/bin/bash

if [ -d './zipped_files' ]; then
    echo 'Directory exists'
else
    mkdir -p ./zipped_files
fi

for i in $(find . -maxdepth 1 -type d -name "FS22*"); do cd $i ; zip -r $i.zip ./* ; mv $i.zip ../zipped_files/; cd .. ;done