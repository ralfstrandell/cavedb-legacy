#!/bin/sh

# This script has been used e.g. to assign class {C}, karst cave, to foreign caves.


exit 1	# bad idea: blind bulk assign, USE CAREFULLY, BACKUP DATA FIRST

CLASS=$1
FILE=$2

# while read -r FILE
# do
	echo "Processing file $FILE" >&2
	row=0;
	cat $FILE | while read line
	do
		row=$((${row}+1))
		if [ $row -eq 15 ]; then row=1; fi
		if [ $row -eq 1 ]
		then
			echo "$line" | egrep -q '[\{|\}]'
			if [ $? -eq 0 ]
			then
				echo "WARNING: $FILE NOT CHANGING $line" >&2
				echo "$line"
			else
				echo "$line {${CLASS}}"
			fi
		else
			echo "$line"
		fi
	done
	exit $?
# done
# exit $?
