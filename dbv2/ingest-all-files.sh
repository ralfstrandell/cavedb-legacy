#!/bin/sh

# Note: This script runs ingest-one-file.sh many times resulting in a large number of backup files.
# The data itself goes to caves.luolaseura.json-content.txt, which is an appendable file (a list of JSON objects).
# Note that the resulting file needs to be wrapped with some text before it becomes valid GeoJSON with features.

# FILE FOR SORTING AND ANALYZING CAVE LENGTH DATA
	LENGTH_DATA="statistics-lengths.txt"
	LONGEST_CAVES="statistics-lengths-sorted.txt"
	HISTOGRAM="statistics-lengths-histogram-minlen.txt"
# FILES FOR EXPORT
	KML_PLACEMARKS="export-Suomen-luolaseura-Caves.kml-placemarks"
	KML_FILE="export-Suomen-luolaseura-Caves.kml"

echo "" > $LENGTH_DATA
echo "" > $KML_PLACEMARKS

ls -1 import-20*.txt  | while read importfile
do
	echo "Processing file $importfile"
	./ingest-one-file.sh $importfile
	if [ $? -ne 0 ]
	then
		echo "Error in file $importfile. Aborting."
		exit 1
	fi
done
EXIT_CODE=$?

cat $LENGTH_DATA | sort -rg > $LONGEST_CAVES
cat $LENGTH_DATA | grep -v KoliActive | awk ' { print $1 } ' | sed 's/[0-9]\.[0-9]$/0/' | uniq -c | awk ' { print $1 " " $2 } ' | grep -v '^000000' > $HISTOGRAM

echo '<?xml version="1.0" encoding="UTF-8"?>' > $KML_FILE
echo '<kml xmlns="http://www.opengis.net/kml/2.2">' >> $KML_FILE
echo '<Document>' >> $KML_FILE
echo '<Name>Suomen luolaseuran luolalista</Name>' >> $KML_FILE
cat $KML_PLACEMARKS >> $KML_FILE
echo '</Document>' >> $KML_FILE
echo '</kml>' >> $KML_FILE

exit $EXIT_CODE

