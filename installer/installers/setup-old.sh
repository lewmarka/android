#!/bin/bash

CURRENT=`pwd`

DEST="$HOME"
IN_DEST=""

echo $CURRENT

echo

while true; do
    read -p "Do you wish to install this program?" yn
    case $yn in
        [Yy]* ) 
                echo "Program will be installed in $DEST/android "
                echo "Please enter the path for install:"
                read IN_DEST
                
                echo $IN_DEST
                
                if [ -d "$IN_DEST" ]
                then
                   DEST=$IN_DEST
                else 
                   echo "Directory does not exist." 
                fi
                
                DEST="$DEST/android"
                
                echo "The program will be installed in $DEST "
                 
                break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

mkdir $DEST

unzip *.zip -d $DEST



 
