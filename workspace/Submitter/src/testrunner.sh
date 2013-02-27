#!/bin/sh

cd "/Users/samira_tasharofi/Documents/My Documents/TA-spring2013/adt-bundle-mac-x86_64/sdk/platform-tools"

./adb logcat -c

cd /Users/samira_tasharofi/Documents/workspace-coursera/Test/

ant clean debug install test > result.txt

cd "/Users/samira_tasharofi/Documents/My Documents/TA-spring2013/adt-bundle-mac-x86_64/sdk/platform-tools"


./adb logcat -d > "/Users/samira_tasharofi/Documents/workspace-coursera/Test/logcat.txt"
