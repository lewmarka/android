#!/bin/bash

CURRENT=`pwd`

#echo $CURRENT

DEST=$CURRENT

while true; do
    read -p "Do you wish to install this program?" yn
    case $yn in
        [Yy]* ) 
                echo "The program will be installed in $DEST."
# 		read -p "If you want to change the directory, please enter the path for install; otherwise press ENTER:" IN_DEST
#                echo $IN_DEST
#                if [[ $IN_DEST != "" ]]; then
#		   echo " no enter"
#		   DEST=$CURRENT
#                fi
                if [ -d "$DEST" ]
                then
                   while true; do
                   	read -p "The directory exists. Do you wish to replace the files in $DEST?" dyn
                   	case $dyn in
                        	[Nn]* )
					echo "Exit installing. Please move or remove your files and try again." 
					exit;;
                        	[Yy]* )
					echo "Replacing the files in $DEST." 
					break;;
				* ) echo "Please answer yes or no.";;
		   	esac
		    done
                else 
                   echo "Directory does not exist; creating the directory.." 
#		   mkdir $DEST
                fi                                              
                break;;
        [Nn]* ) 
           echo "Exit installing."
            exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

#unzip *.zip -d $DEST
echo "The program is installed in $DEST"



 