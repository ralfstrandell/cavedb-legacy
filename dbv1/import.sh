#!/bin/sh

# Version 1.0 Date 2020-05-17 Author Ralf Strandell

# This script takes a human readable cave report text file import.txt and produces JSON
# either as one liners or in human readable(ish) format.

# INPUT TEXT FILE FORMAT
#
#	- 13 rows per cave record
#	- 1: Cave name (letters, numbers, dash, underscore, parentheses, square brackets)
#	- 2: reference system (koordinate systems kkj, ykj and wgs84 supported)
#	- 3: lat or N as decimal number
#	- 4: lon or E as decimal number
#	- 5: Location (part of country)
#	- 6: Country
#	- 7: Continent
#	- 8: Accurary and length in metres: Examples; approx 7 OR exact 7
#	- 9: Name of person reporting the cave
#	- 10: Activity [Caving|Mines|Bunkers]
#	- 11: Subactivity [Basic|Diving|SRT]
#	- 12: URL
#	- 13: empty line for human readability
# 
# Cave name (generally: name of site described)
# coordinate_system (ykj or wgs84)
# y-coor reference (lat wgs84 or N ykj)
# x-koord reference (lon wgs84 or E ykj)
# location
# country
# continent
# Approx + length OR Exact + length (in m)
# Name of person reporting the site
# Activity
# Subactivity
# URL or Empty line
# Empty line
# Cave name (generally: name of site described)
# coordinate_system (ykj or wgs84)
# y-coor reference (lat wgs84 or N ykj)
# x-koord reference (lon wgs84 or E ykj)
# location
# country
# continent
# Approx + length OR Exact + length (in m)
# Name of person reporitng the site
# Activity
# Subactivity
# URL OR Empty line
# Empty line
# ...


# DATABASE FILE
	# DB="./testdb.json" 			# First line MUST be [ and last line MUST be ]
	DB="./caves.luolaseura.json" 		# First line MUST be [ and last line MUST be ]

# FUNCTIONS

db_coord_transform_ykj_wgs84 () {

	# READ: http://koivu.luomus.fi/projects/coordinateservice/info/
	N=$1
	E=$2
	REF_FROM="ykj"
	URL_SVC="http://koivu.luomus.fi/projects/coordinateservice/" # Luonnontieteellisen keskusmuseon koordinaatistomuunnospalvelu
	REPLY=`curl --silent "${URL_SVC}?orig_system=${REF_FROM}&north=${N}&east=${E}"`
	WGS84_LAT=`echo "$REPLY" | grep north | sed 's/^.*<north>//;s/<\/north>$//'`
	WGS84_LON=`echo "$REPLY" | grep east | sed 's/^.*<east>//;s/<\/east>$//'`
	echo "$WGS84_LAT $WGS84_LON"
}

db_add_records () {

	DB_BAK="${DB}.bak"		# We always want a backup
	DB_TMP="${DB}.tmp"		# Temporary working file

	if [ ! -e $DB ]	# Does not exist?
	then
		echo "[" > $DB || return 1	# Create
		cat $OUTPUT | sed '1s/^, //' >> $DB || return 2 # Use Stream EDitor to remove first comma on line 1
		echo "]" >> $DB || return 3 # Close
		return
	fi	
	if [ ! -r $DB -o ! -w $DB ] # RW?
	then
		echo "Error: Database $DB needs to be readable and writable!";
		return 4
	fi

	# Database (JSON) exists and is readable and writable
	DB_ROWS=`wc -l < $DB`		# How many lines
	DB_HEAD=$((DB_ROWS - 1))	# The last line (]) we want to remove before append

	# Create a new vesion of DB
	head -$DB_HEAD $DB > $DB_TMP || return 5	# all but the closing ]
	cat $OUTPUT >> $DB_TMP || return 6		# note: each line begins with a comma :)
	echo "]" >> $DB_TMP || return 7

	# Verify row count match
	OUTPUT_ROWS=`wc -l < $OUTPUT`
	DB_TMP_ROWS=`wc -l < $DB_TMP`
	EXPECTED_ROWS=$(( DB_ROWS + OUTPUT_ROWS ))
	if [ $DB_TMP_ROWS -ne $EXPECTED_ROWS ]
	then # database + appended lines NOT EQUAL TO new lines. We have a problem.
		echo "Error: Appending failed. Line count mismatch. Aborting."
		return 8
	fi
		
	# Replace the database with the appended one
	cp $DB ${DB_BAK}.`date +"%Y%m%d-%H%M%S"` || return 9 # Unique timestamped backup
	cat $DB_TMP > $DB && rm $DB_TMP || return 10 # replace or fail
}


# TURN DEBUGGING ON/OFF
	VERBOSE=true; # debug
	# VERBOSE=false;
	# For debugging purposes we recommend "sh -x ./import.sh readable"

# SET OUTPUT FORMAT
	FMT=$1
	# FMT="oneliner";
	# FMT="readable";
	if [ "$FMT" != "oneliner" -a "$FMT" != "readable" ]
	then
		echo "Error: Output type (formatting of JSON) not defined!";
		echo "Usage: ./import.sh oneliner OR ./import.sh readable";
		exit 1
	fi

# DEFINE INPUT AND OUTPUT FILE NAMES
	DATA="./import.txt"
	OUTPUT="./added-lines.txt"
	if [ ! -r $DATA ]
	then
		echo "Error: Cannot read input file $DATA !";
		exit 1;
	fi
	EXTRA_ROWS=$(( `wc -l < $DATA` % 13 )) # rows mod 13 (0=ok,1...12=notok)
	if [ $EXTRA_ROWS -ne 0 ]
	then
		echo "Error: Invalid input data: 13 lines per cave expected. Check empty lines and URL lines! The last line of the file must be empty, too!"
		exit 1
	fi
	if [ -f $OUTPUT ];
	then
		rm $OUTPUT || exit 1 # remove previous file or fail
		# echo "Error: Output file $OUTPUT already exists. Remove it first.";
		# exit 1;
	fi
	FILETYPE=`file $DATA`;
	if [ "$FILETYPE" != "UTF-8 Unicode (with BOM) text" -a "$FILETYPE" != "UTF-8 Unicode text" -a "$FILETYPE" != "ASCII text" ]
	then
		echo "Error: The file must be UTF-8 Unicode (with or without BOM) text! ASCII is also good for a-z alphabets."
		echo "HowTo: In LibreOffice Writer: Save As: Save as type: Text - choose character set. Choose UTF-8, LF, BOM."
	fi
	BADCHARS=`egrep '"' $DATA`
	if [ "$BADCHARS" != "" ]
	then
		echo "Error: Input file $DATA is not allowed to contain quotes: \"";
		exit 1;
	fi

# MAIN INGESTION LOOP
COUNTER=0;
touch $OUTPUT
cat $DATA | while read name # 1 
do
	read ref	# 2
	read y		# 3 latitude or N
	read x		# 4 longitude or E
	read location	# 5
	read country	# 6
	read continent	# 7
	read length	# 8
	read reporter	# 9
	read activity	# 10
	read subactivity #11
	read url	# 12
	read emptyline	# 13
	# TO BE IMPLEMENTED
	# - Depth: Integer or decimal (also: room dimension x y z)
	# - Type: L/R/K/T/M
	# - Difficulty: 0/1/2/3/4
	# - Challenges: A0/A1/A2/A3 (ahtaus), K0/K1/K2/K3 (kiipeily),
	# 		V0/V1/V2/V3 (vesi)
	COUNTER=$((COUNTER + 1));

	# SYNC CHECK
	# if [ "$ref" != "wgs84" -a "$ref" != "etrs89" -a "$ref" != "ykj" ]
	if [ "$ref" != "wgs84" -a "$ref" != "ykj" ]
	then
		echo "Error: Expected wgs84 or ykj. Position: cave $COUNTER name $name"
		exit 1
	fi

	# SPLIT ACCURACY + LENGTH INTO SEPARATE VARIABLES
	set $length; test "$1" == "Arvio" && la="approx" || la="exact";
	length=$2

	# NUMBER CHECK (INTEGER OR DECIMAL)
	if [[ $x =~ ^[0-9]+(\.[0-9]+){0,1}$ ]] 
	then
		: nop
	else
		echo "Error: Coordinate x should be a number. Found $x Position: cave $COUNTER name $name"
		exit 1
	fi
	if [[ $y =~ ^-{0,1}[0-9]+(\.[0-9]+){0,1}$ ]]
	then
		: nop
	else
		echo "Error: Coordinate y should be a number. Found $y Position: cave $COUNTER name $name"
		exit 1
	fi
	if [[ $length =~ ^-{0,1}[0-9]+(\.[0-9]+){0,1}$ ]] 
	then
		: nop
	else
		echo "Error: length should be a number (integer or decimal with a dot). No m. No km. Found $length Position: cave $COUNTER name $name"
		exit 1
	fi

	# COORDINATE TRANSFORM YKJ -> WGS84
	lat=$y; lon=$x;	# default
	if [ "$ref" == "ykj" ]
	then
		new=`db_coord_transform_ykj_wgs84 $y $x`
		set $new	
		lat=$1; lon=$2;
		if [ "$lat" == "" -o "$lon" == "" ]
		then
			echo "Error converting YKJ coordinates! Cave $COUNTER Name $name X $x Y $y LAT $lat LON $lon";
			exit 1
		fi
		if [[ $lat =~ ^[0-9][0-9]*\.[0-9][0-9]*$ ]] && [[ $lon =~ ^[0-9][0-9]*\.[0-9][0-9]*$ ]]
		then
			: nop
		else
			echo "Error converting KKJ coordinates! Cave $COUNTER Name $name X $x Y $y LAT $lat LON $lon";
			exit 1
		fi
	fi

	# DEBUGGING OUTPUT
	if [ "$VERBOSE" == "true" ]
	then
		echo "-----------------------------------------------------"
		echo "IMPORTING ["${COUNTER}"]"
		echo "Cave $name";
		echo "Position Y $y X $x Lat $lat Lon $lon";
		echo "Location $location $country $continent";
		echo "Length (${la}) $length m";
		echo "Reported by $reporter as $activity of type $subactivity";
		echo "Url: $url";
	fi

	# OUTPUT
	if [ "$FMT" == "oneliner" ]
	then
		echo ', {"n": "'${name}'", "lat": '${lat}', "lon": '${lon}', "l": '${length}', "la": "'${la}'", "c": "'${country}'", "o": "'${continent}'", "rl": [{ "t": "'${name}'", "w": ["'${reporter}'"], "a": ["'${activity}'"], "sa": ["'${subactivity}'"], "u": "" }]}' >> $OUTPUT;
	else
		cat << EOTXT >> $OUTPUT
, {"n": "${name}",
"lat": ${lat}, "lon": ${lon},
"l": ${length}, "la": "${la}",
"c": "${country}",
"o": "${continent}",
"rl": [{ "t": "${name}", "w": ["${reporter}"], "a": ["${activity}"], "sa": ["${subactivity}"], "u": "${url}" }]}
EOTXT
	fi
done


db_add_records && exit 0 || echo "Error: Appending database failed with error code $?"
exit 1

