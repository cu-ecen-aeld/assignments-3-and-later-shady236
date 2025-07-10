#!/bin/sh

if [ $# -ne 2 ]
then
	echo "Invalid number of arguments, the first argument is a path to a directory on the filesystem, the second argument is a text string which will be searched within the files on that diresctory"
	exit 1 
fi


filesdir=$1
searchstr=$2

if [ ! -d $filesdir ]
then
	echo "$filesdir does not represent a directory on the filesystem"
	exit 1 
fi

numFiles=$(find $filesdir -type f | wc -l)
numMatchingLines=$(grep -r $searchstr $filesdir | wc -l)

echo "The number of files are $numFiles and the number of matching lines are $numMatchingLines"

exit 0
