#!/bin/sh

# FILES FOR EXPORT
	KML_PLACEMARKS="export-Suomen-luolaseura-Caves.kml-placemarks"
	KML_FILE="export-Suomen-luolaseura-Caves.kml"

echo '<?xml version="1.0" encoding="UTF-8"?>' > $KML_FILE
echo '<kml xmlns="http://www.opengis.net/kml/2.2">' >> $KML_FILE
echo '<Document>' >> $KML_FILE
echo '<Name>Suomen luolaseuran luolalista</Name>' >> $KML_FILE
cat $KML_PLACEMARKS >> $KML_FILE
echo '</Document>' >> $KML_FILE
echo '</kml>' >> $KML_FILE
