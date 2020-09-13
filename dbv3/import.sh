#!/bin/sh

if [ "$1" != "" ]; then IMPORTFILE="$1"; else IMPORTFILE=./import.txt; fi
CAVEJSON="./caves.luolaseura.json"
CAVELIST="./caves.luolaseura.json-content.txt"

echo "Running ingest-one-file.sh $IMPORTFILE to append $CAVELIST"

./ingest-one-file.sh $IMPORTFILE
if [ $? -ne 0 ]
then
	echo "Error: There was an error running ingest-one-file.sh. Aborting."
	exit 1
fi

# Write header
cat << EOTXT > $CAVEJSON
{
	"type": "FeatureCollection",
	"features":
	[
EOTXT

# Write data
cat $CAVELIST >> $CAVEJSON

# Close
cat << EOTXT >> $CAVEJSON
	]
}
EOTXT

