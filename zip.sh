#!/usr/bin/env bash

mkdir -p ./zipped_files
for i in $(find . -maxdepth 1 -type d -name "FS22*"); do zip -jr $i.zip $i; mv *.zip ./zipped_files/; done
