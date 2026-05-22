#!/bin/bash

osascript -e 'quit app "MailMate"'
sleep 1
git -C ~/code/list-unsubscribe pull
sleep 5

open -a MailMate

tail -f /tmp/ListUnsub.log

