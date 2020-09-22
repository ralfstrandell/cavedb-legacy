#!/bin/sh

# FILE FOR SORTING AND ANALYZING CAVE LENGTH DATA
	LENGTH_DATA="statistics-lengths.txt"
	LONGEST_CAVES="statistics-lengths-sorted.txt"
	HISTOGRAM="statistics-lengths-histogram-minlen.txt"

cat $LENGTH_DATA | sort -rg > $LONGEST_CAVES
cat $LENGTH_DATA | grep -v KoliActive | awk ' { print $1 } ' | sed 's/[0-9]\.[0-9]$/0/' | uniq -c | awk ' { print $1 " " $2 } ' | grep -v '^000000' > $HISTOGRAM

