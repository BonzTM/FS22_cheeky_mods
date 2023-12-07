#!/usr/bin/env bash

mkdir -p ./zipped_files
for i in $(find . -maxdepth 1 -type d -name "FS22*"); do cd $i ; zip -r $i.zip ./* ; mv $i.zip ../zipped_files/; cd .. ;done
