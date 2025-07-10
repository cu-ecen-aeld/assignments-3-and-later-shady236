#!/bin/sh

if [ $# -ne 2 ]
then
	echo "Invalid number of arguments"
	exit 1 
fi


writefile=$1
writestr=$2


install -Dv /dev/null $writefile
echo $writestr > $writefile

exit 0
