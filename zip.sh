#!/usr/bin/env bash
for i in $(find . -maxdepth 1 -type d -name "FS22*"); do zip -jr $i.zip $i; done