#!/bin/sh

# cd "/Users/samira_tasharofi/Documents/My Documents/TA-spring2013/adt-bundle-mac-x86_64/sdk/tools"

# android create avd -n TestAVD -t 1

# emulator -avd TestAVD

cd "/Users/samira_tasharofi/Documents/My Documents/TA-spring2013/adt-bundle-mac-x86_64/sdk/platform-tools"

./adb logcat -c

cd /Users/samira_tasharofi/Documents/workspace-coursera/Test/

ant clean debug install test 2>&1 | tee result.txt

cd "/Users/samira_tasharofi/Documents/My Documents/TA-spring2013/adt-bundle-mac-x86_64/sdk/platform-tools"


./adb logcat -d > "/Users/samira_tasharofi/Documents/workspace-coursera/Test/logcat.txt"
