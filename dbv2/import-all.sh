#!/bin/sh

CAVEJSON="./caves.luolaseura.json"
CAVELIST="./caves.luolaseura.json-content.txt"

if [ -f $CAVELIST ]
then
	echo "Error: The file $CAVELIST already exists. Use import.sh instead! Aborting."
	exit 1
else
	echo "Running ingest-all-files.sh to generate $CAVELIST"
fi

./ingest-all-files.sh
if [ $? -ne 0 ]
then
	echo "Error: There was an error running ingest-all-files.sh. Aborting."
	exit 1
fi

# Write header
cat << EOTXT > $CAVEJSON
{
	"type": "FeatureCollection",
	"features":
EOTXT

# Write data
cat $CAVELIST >> $CAVEJSON

# Close
cat << EOTXT >> $CAVEJSON
}
EOTXT

