#!/bin/bash
# NOTE: bash is required instead of Bourne shell because of arithmetics: "let" and (( expr )). Nicer than running expr...

# Version 2.0 Date 2020-08-06 Author Ralf Strandell

# This script takes a human readable cave report text file import.txt (version 2) and produces JSON
# either as one liners or in human readable(ish) format.

# TO DO
#	publication fields p and pu
#	reading lists: support several articles (each with title + people + year + url)


# INPUT TEXT FILE FORMAT
#
#	- 14 rows per cave record
#	- 1: Cave name. Alternative names separated by "space / space".
#			Each name can contain additional info separated by "space - space".
#			CaveName1 - entranceA / Cavename2 - entranceA / Cavename3 / ...
#			Also: CaveName - Visitor centre, CaveName - Parking lot, etc.
#			CaveName can contain letters, numbers, space, underscore, dash (no space around it)
#	- 2: Description field. Additional information. Eg. dimensions, structure, etc.
#	- 3: reference system (koordinate systems ykj and wgs84 supported)
#	- 4: lat or N as decimal number
#	- 5: lon or E as decimal number
#	- 6: Location (part of country)
#	- 7: Country
#	- 8: Continent
#	- 9: Accurary and length in metres: Examples; approx 7 OR exact 7
#	- 10: Name of person reporting the cave
#	- 11: Activity [Caving|Diving]
#	- 12: Subactivity 	[Basic|Swimming|Boating|Diving|SRT|Digging|Skiing|None]
#				[Rock,Ice,Other-Material,Man-Made]
#				[Rock-Granite|Rock-Limestone|Rock-Sandstone|Rock-Marble|Rock-Volcanic|Rock-Other]
#				[Morphology-Crack|Morphology-Boulders|Morphology-Karst|Morphology-Volcanic|Morphology-Erosion|Morphology-Other]
#	- 13: URL pointing to an article
#	- 14: Optional numeric date + Optional CSV list of names + URL pointing to a cave map + [ + Title + ]
#				Title is not allowed to contain [
# OUTPUT FILE FORMAT
#	- ActivityJSON 2gen


# FILE NAMES
	# DB="./testdb.json" 				# For testing purposes
	DB="./caves.luolaseura.json-content.txt"	# The inner part of JSON ("features"). Appendable.
	LENGTH_DATA="statistics-lengths.txt"
	KML_PLACEMARKS="export-Suomen-luolaseura-Caves.kml-placemarks"

# STRINGS
	SUOMEN_LUOLAT="Suomen luolat. Kesäläinen, Kejonen, Kielosto, Salonen, Lahti. 2015. Salakirjat. ISBN 978-952-5774-80-1"

# SETTINGS
	DEBUG="false"	# or true	"set -x" in loop.
	VERBOSE="false" # or true	see a bit more what's being done while importing cave records.

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
		# # Use Stream EDitor to remove first comma on line 1
		cat $OUTPUT | sed '1s/^[ \t]*, //' >> $DB || return 2 
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
	# cp $DB ${DB_BAK}.`date +"%Y%m%d-%H%M%S"` || return 9 # Unique timestamped backup
	TODAY=`date +"%Y%m%d"`
	cat $DB > ${DB_BAK}.${TODAY} || return 9 # Datestamped backup. We do not want 17 of these with import-all.sh ...
	cat $DB_TMP > $DB && rm $DB_TMP || return 10 # replace or fail

}

split () {

	# Read arguments
	classString="$1";
	subactivitylist="$2";

	# Remove commas and spaces, then prepend letters with spaces, then remove the first space on the line
	classes_spaced=`echo "$classString" | sed -e 's/[, ]//g' -e 's/[a-zA-Z]/ &/g' -e 's/^ //'`

        # INIT - ACTIVITIES
	#	None, Basic, SRT, Boating, Swimming, Diving, Digging
	None=false;
	Basic=false;
	SRT=false;
	Boating=false;
	Swimming=false;
	Diving=false;
	Digging=false;

	# Detect existing activities
	echo "$subactivitylist" | grep -q 'None' && None=true;
	echo "$subactivitylist" | grep -q 'Basic' && Basic=true;
	echo "$subactivitylist" | grep -q 'SRT' && SRT=true;
	echo "$subactivitylist" | grep -q 'Boating' && Boating=true;
	echo "$subactivitylist" | grep -q 'Swimming' && Swimming=true;
	echo "$subactivitylist" | grep -q 'Diving' && Diving=true;
	echo "$subactivitylist" | grep -q 'Digging' && Digging=true;


	# INIT - TYPES OF SURROUNDING MATERIAL
	Rock=false;
	Glacier=false;		# ice
	Other=false;		# moraine, turf
	ManMade=false;		# concrete walls

	# INIT - ROCK TYPES
	#	Igneous/magmakivet
	#		Volcanic/vulkaaniset
	#		Other/Syvä- ja juonikivet
	#	Sedimentary/sedimenttikivet
	#		Siliciclastic: Mudrocks/savikivet
	#		Siliciclastic: Sandstones/hiekkakivet
	#		Carbonate/karbonaattikivet: Limestone, Dolomite/kalkkikivi ja dolomiitti
	#		Sulfate/sulfaattikivet: Gypsum/kipsi
	#		Halite: rock salt/vuorisuola
	#	Metamorphic/metamorfiset
	#		Marble/marmorit
	#		Other/muut metamorfiset

	Mudrocks=false;		# sedimentary, siliciclastic
	Sandstones=false;	# sedimentary, siliciclastic
	Carbonate=false;	# sedimentary (limestone and dolomite)
	Sulfate=false;		# sedimentary (gypsum)
	Halite=false;		# sedimentary (rock salt)
	Volcanic=false;		# igneous (solidified lava)
	NSNV=false;		# nonsedimentary nonvolcanic rocks/syväkivet, juonikivet, metamorfiset kivet
	Marble=false;		# metamorphic

	# INIT - TYPES OF OTHER MATERIAL
	Turf=false;
	Moraine=false;

	# INIT - CLASSES 1 (morphological)
	Boulders=false;		# lohkareluola
	Crevice=false; 		# rakoluola, psgeo: crack
	Shelter=false;		# lippaluola
	Karst=false;		# karstiluola
	Tunnel=false;		# tunneli
	Vugg=false;		# kideonkalo
	Blister=false;		# vulkaaninen onkalo (eri kuin kideonkalo)
	Earthcave=false;	# maaluola
	Tafone=false;		# tafonionkalo

	# INIT - CLASSES 2 (genetic)
	Primary=false;		# primary volcanic, primary organic
	Growth=false;		# reef,overgrown (fi: piilopurot, umpeen kasvaneet lammet)
	Tectonic=false;		# tectonic, including neotectonic of course
	Dissolution=false;	# karst
	Weathering=false;
	Glacial=false;		# pseudokarst
	Erosion=false;		# rantavoimat (shore), joet (fluvial)
	Shore=false;		# caves carved by waves, current, winter ice
	Fluvial=false;		# caves carved by rivers, glacial rivers included of course
	Freezing=false;		# ice caves, a little bit strange classification, but practical
	GroundwaterPiping=false;# erosion
	Excavated=false;	# at least partially

	# DETECT CERTAIN ROCK TYPES IN JSON ALREADY
	echo "$subactivitylist" | grep -q 'Rock' && Rock=true;
	echo "$subactivitylist" | grep -q 'Rock-Gypsum' && Gypsum=true;

	# PROCESS CLASS STRING
	# 	Remove commas and spaces and "ja" words,
	#	then prepend letters with spaces,
	#	then remove the first space on the line
	#	and finally process its contents

	classes_spaced=`echo "$classString" | sed -e 's/ ja //g' -e 's/[, ]//g' -e 's/[a-zA-Z]/ &/g' -e 's/^ //'`
	if [ "$classes_spaced" != "" ]
	then
		set $classes_spaced
		counter=$#
	else
		counter=0
	fi
	while [ $counter -gt 0 ]
	do
		c="$1";
		if [ $counter -gt 1 ]; then shift; fi	# don't shift over the edge
		let counter--;

		case "$c" in
		#	MATERIAL   SUBTYPE		MORPHOLOGY      GENETICS          		COMMENT
		A|a)	Rock=true; NSNV=true; 		Vugg=true;	Primary=true;;			# blister cave (igneous origin!)
		B|b)	Rock=true; 			Crevice=true;	Tectonic=true;;			# tectonic crevice caves
		C|c)	Rock=true;			Karst=true;	Dissolution=true;;		# karst caves
		C1|c1)	Rock=true; Carbonate=true;	Karst=true;	Dissolution=true;;		# same
		C2|c2)	Rock=true; Sulfate=true;	Karst=true;	Dissolution=true;;		# same
		C3|c3)	Rock=true; Halite=true;		Karst=true;	Dissolution=true;;		# same
		D|d)	Rock=true;					Weathering=true;;		# generic weathering cave
		D1|d1)	Rock=true;			Tafone=true;	Weathering=true;;		# tafone
		D2|d2)	Rock=true;			Crevice=true;	Weathering=true;;		# preglacial weathering crack
		D3|d3)	Rock=true;					Weathering=true;;		# other weathering caves
		E|e)	Rock=true;			Crevice=true;	Glacial=true;;			# glacial crevice caves
		F|f)	Rock=true;			Boulders=true;	Glacial=true;;			# glacial boulder caves
		G|g)	Other=true; Moraine=true;	Earthcave=true;	Glacial=true;;			# glacial earth caves (ice melting)
		H|h)	Rock=true;					Erosion=true; Shore=true;;	# cave caused by shore action
		I|i)	Rock=true;			Boulders=true;;					# Tectonic/Glacial/Weathering (fi: vuorenvieremät)
		I1|i1)	Rock=true;			Boulders=true;	Tectonic=true;;			# (neo)Tectonic talus caves
		J|j)	Rock=true;					Erosion=true; Fluvial=true;;	# caves caused by rivers
		K|k)	Rock=true;			Shelter=true;	Erosion=true; Glacial=true;;	# glacial shelter caves
		L|l)	Rock=true; 					Freezing=true;;			# ice caves (caves with ice)
		M|m)	Glacier=true;;									# crevices/tunnels; gravity/meltwater/volcanic heat
		N1|n1)	Rock=true; Carbonate=true;			Primary=true; Growth=true;;	# reefs
		N2|n2)	Other=true; Turf=true;				Primary=true; Growth=true;;	# overgrown by mosses
		V|v)	Rock=true; Volcanic=true;			Primary=true;;			# unspecified volcanic cave
		V1|v1)	Rock=true; Volcanic=true;			Primary=true;;			# magma chambers, eruptive fissures
		V2|v2)	Rock=true; Volcanic=true;	Tunnel=true;	Primary=true;;			# lava tubes, lava toes (surface tubes)
		V3|v3)	Rock=true; Volcanic=true;			Primary=true;;			# other types of caves in lava flows:
													# pressure ridge/plateau caves, traversal caves (gravity),
													# lava falls, lava molds, blisters, ...
		V4|v4)	Rock=true; Volcanic=true;			Primary=true;;			# gas explosion caves (pneumatogenetic)
													# e.g. hollow tall welded spatter cones
		Z|z)	Rock=true;					Excavated=true;;		# at least partially excavated caves
		Z1|z1)	Rock=true;					Excavated=true;;		# e.g. salt ingestion caves
		Z2|z2)	Rock=true;					Excavated=true;;		# e.g. mined caves, 'cave like' mines, mines
		*)	;;
		esac
	done

	# Next map these to the psgeo values best we can! Convert only EXISTING data, thus limited.
	psgeotags="";

	# 1 Write activities
		if [ "$None" == "true" ]; 	then 	psgeotags="${psgeotags}\"None\","; 		fi;
		if [ "$Basic" == "true" ]; 	then 	psgeotags="${psgeotags}\"Basic\","; 		fi;
		if [ "$SRT" == "true" ]; 	then 	psgeotags="${psgeotags}\"SRT\","; 		fi;
		if [ "$Boating" == "true" ]; 	then 	psgeotags="${psgeotags}\"Boating\","; 		fi;
		if [ "$Swimming" == "true" ]; 	then 	psgeotags="${psgeotags}\"Swimming\","; 		fi;
		if [ "$Diving" == "true" ]; 	then 	psgeotags="${psgeotags}\"Diving\","; 		fi;
		if [ "$Digging" == "true" ]; 	then 	psgeotags="${psgeotags}\"Digging\","; 		fi;


	# 2 Write type of surrounding material (environment)
		if [ "$Rock" == "true" ]; 	then 	psgeotags="${psgeotags}\"Rock\","; 		fi;
		if [ "$Glacier" == "true" ]; 	then	psgeotags="${psgeotags}\"Glacier\","; 		fi;
		if [ "$Other" == "true" ]; 	then 	psgeotags="${psgeotags}\"Material-Other\","; 	fi;
		if [ "$ManMade" == "true" ]; 	then	psgeotags="${psgeotags}\"Man-Made\","; 		fi;		

	# 3 Write detailed material type (rock type)
		# Sedimentary rocks
		if [ "$Sandstones" == "true" ]; then 	psgeotags="${psgeotags}\"Rock-Sandstone\","; 	fi;
		if [ "$Mudrocks" == "true" ]; 	then 	psgeotags="${psgeotags}\"Rock-Mudrock\","; 	fi;
		if [ "$Carbonate" == "true" ]; 	then 	psgeotags="${psgeotags}\"Rock-Limestone\","; 	fi;
		if [ "$Sulfate" == "true" ]; 	then 	psgeotags="${psgeotags}\"Rock-Gypsum\","; 	fi;
		if [ "$Halite" == "true" ]; 	then 	psgeotags="${psgeotags}\"Rock-Salt\","; 	fi;
		# Igneous and metamorphic rocks
		if [ "$Volcanic" == "true" ]; 	then 	psgeotags="${psgeotags}\"Rock-Volcanic\","; 	fi;		#1
		if [ "$NSNV" == "true" ]; 	then 	psgeotags="${psgeotags}\"Rock-Granite\","; 	fi;
		if [ "$Marble" == "true" ]; 	then 	psgeotags="${psgeotags}\"Rock-Marble\","; 	fi;

	# Cave classification by form (morphology-)
		if [ "$Volcanic" == "true" ]; 	then 	psgeotags="${psgeotags}\"Morphology-Volcanic\","; 	fi;	#2
		if [ "$Boulders" == "true" ]; 	then 	psgeotags="${psgeotags}\"Morphology-Boulders\","; 	fi;
		if [ "$Crevice" == "true" ]; 	then 	psgeotags="${psgeotags}\"Morphology-Crack\",";		fi;
		if [ "$Shelter" == "true" ]; 	then 	psgeotags="${psgeotags}\"Morphology-Shelter\",";	fi;
		# if [ "$Tunnel" == "true" ]; 	then 	psgeotags="${psgeotags}\"Morphology-Tunnel\",";		fi;
		if [ "$Karst" == "true" ]; 	then 	psgeotags="${psgeotags}\"Morphology-Karst\",";		fi;
		if [ "$Vugg" == "true" ]; 	then 	psgeotags="${psgeotags}\"Morphology-Crystallization\",";fi;
		if [ "$Growth" == "true" ]; 	then 	psgeotags="${psgeotags}\"Morphology-Organic\","; 	fi;

	# Genetic classification of caves (morphology-)
		# Recorded as Morphology-* because of limitations of psgeo
		if [ "$Weathering" == "true" ]; then	psgeotags="${psgeotags}\"Morphology-Weathering\",";	fi;
		if [ "$Erosion" == "true" ]; 	then	psgeotags="${psgeotags}\"Morphology-Erosion\",";	fi;
		if [ "$Erosion" == "false" ];
		then
			if [ "$Shore" == "true" -o "$Fluvial" == "true" -o "$GroundwaterPiping" == "true" ]
			then
				psgeotags="${psgeotags}\"Morphology-Erosion\","
			fi
		fi
		if [ "$Freezing" == "true" ]; 	then	psgeotags="${psgeotags}\"Ice\",";			fi;

        # Not yet supported by psgeo:	Morphology-Shelter, Morphology-Tunnel, Morphology-Tafone, Morphology-Blister, Earthcave
	# Not supported by psgeo:	Genetical classification and morphological classification separated.
	# No need to record:		Primary cave, Rock-Other, Morphology-Other, Rock-Unknown, Morphology-Unknown.
	# Genetic classes non used:	Tectonic, Dissolution, Glacial, Excavated

	psgeotags=`echo "$psgeotags" | sed 's/,$//'`

	# Return result
	echo "$psgeotags";
}

	
# DEFINE INPUT AND OUTPUT FILE NAMES
	DATA="./import.txt"
	if [ "$1" != "" ]; then DATA="$1"; fi
	OUTPUT="./added-lines.txt"
	if [ ! -r $DATA ]
	then
		echo "ERROR: Cannot read input file $DATA !";
		exit 1;
	fi
	EXTRA_ROWS=$(( `wc -l < $DATA` % 14 )) # rows mod 13 (0=ok,1...12=notok)
	if [ $EXTRA_ROWS -ne 0 ]
	then
		echo "ERROR: Invalid input data: 14 lines per cave expected. Check empty lines and URL lines! The last line of the file must be empty, too!"
		echo "Continuing to process the file. First error will reveal where the line numbers fall out of sync."
	#	exit 1
	fi
	if [ -f $OUTPUT ];
	then
		rm $OUTPUT || exit 1 # remove previous file or fail
		# echo "ERROR: Output file $OUTPUT already exists. Remove it first.";
		# exit 1;
	fi
	FILETYPE=`file --brief $DATA`;
	if [ "$FILETYPE" != "UTF-8 Unicode (with BOM) text" -a "$FILETYPE" != "UTF-8 Unicode text" -a "$FILETYPE" != "UTF-8 Unicode text, with very long lines" -a "$FILETYPE" != "ASCII text" ]
	then
		echo "Warning: The file must be UTF-8 Unicode (without BOM) text! ASCII is also good for a-z alphabets."
		echo "Filetype was: $FILETYPE"
		echo "HowTo: In LibreOffice Writer: Save As: Save as type: Text - choose character set. Choose UTF-8, LF, BOM."
	fi
	BADCHARS=`egrep '"' $DATA`
	if [ "$BADCHARS" != "" ]
	then
		echo "ERROR: Input file $DATA is not allowed to contain quotes: \"";
		exit 1;
	fi

# MAIN INGESTION LOOP
COUNTER=0; prevname="start of file";
touch $OUTPUT
# remove carriage returns from any data, then process
cat $DATA | LC_ALL=C sed -e 's/\r$//' | while read cave # 1 
do
	if [ "$DEBUG" = "true" ]; then set +x; fi

	read descr	# 2 THESE ARE IN FINNISH
	read ref	# 3
	read y		# 4 latitude or N
	read x		# 5 longitude or E
	read location	# 6
	read country	# 7
	read continent	# 8
	read length	# 9
	read reporters		# 10
	read activity		# 11
	read subactivitylist	# 12
	read webref		# 13
	read mapurl		# 14

	COUNTER=$((COUNTER + 1));

	# SYNC CHECK
	# if [ "$ref" != "wgs84" -a "$ref" != "etrs89" -a "$ref" != "ykj" ]
	if [ "$ref" != "wgs84" -a "$ref" != "ykj" ]
	then
		error_pos=$(($COUNTER * 14 - 14))
		echo "ERROR: Expected wgs84 or ykj. Position: cave $COUNTER after line ${error_pos}. Previous cave was $prevname"
		exit 1
	fi
	prevname="$cave"	# store the name of the cave; usefull if next cave fails to be read.


	# PROCESS THE RECORD ################################################

	# SPLIT ACCURACY + LENGTH INTO SEPARATE VARIABLES
	set $length; test "$1" == "Arvio" && la="approx" || la="exact";
	length=$2


	# NUMBER CHECK (INTEGER OR DECIMAL)
	if [[ $x =~ ^-{0,1}[0-9]+(\.[0-9]+){0,1}$ ]] 
	then
		: nop
	else
		echo "ERROR: Coordinate x should be a number. Found $x Position: cave $COUNTER which is $cave"
		exit 1
	fi
	if [[ $y =~ ^-{0,1}[0-9]+(\.[0-9]+){0,1}$ ]]
	then
		: nop
	else
		echo "ERROR: Coordinate y should be a number. Found $y Position: cave $COUNTER which is $cave"
		exit 1
	fi
	if [[ $length =~ ^[0-9]+(\.[0-9]+){0,1}$ ]] 
	then
		: nop
	else
		echo "ERROR: length should be a number (integer or decimal with a dot). No m. No km. Found $length Position: cave $COUNTER which is $cave"
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
			echo "ERROR converting YKJ coordinates! Cave $COUNTER which is $cave X $x Y $y LAT $lat LON $lon";
			exit 1
		fi
		if [[ $lat =~ ^[0-9][0-9]*\.[0-9][0-9]*$ ]] && [[ $lon =~ ^[0-9][0-9]*\.[0-9][0-9]*$ ]]
		then
			: nop
		else
			echo "ERROR converting YKJ coordinates! Cave $COUNTER which is $cave X $x Y $y LAT $lat LON $lon";
			exit 1
		fi
	fi


	# PROCESS PEOPLE
	#	CSV to JSON LIST: A,B, C,D , E ,F -> ["A","B","C","D","E","F"]
	#	heading [" and trailing "]
	#	change / *, */","/
	reporters='["'`echo "$reporters" | sed 's/ *, */","/g'`'"]'
	#	"Name One","Name Two", "Name Three"

	# ANONYMIZE
	reporters=`echo "$reporters" | LC_ALL=C sed -e 's/[a-z] //g' -e 's/[a-z]//g'` # just keep capital letters

	# cave = "name1 / name 2 / name3, city [id] {class,class,class}"

	# EXTRACT NAME
		# remove everything than begins with " [" or " {"
		# then remove anything upto the first comma
		name_and_city=`echo "$cave" | LC_ALL=C sed 's/ [\[|{].*$//g'`
		name=`echo "$name_and_city" | LC_ALL=C sed -e 's/, .*$//'`

	# EXTRACT CITY
		# name_and_city is either "cave name" "cave name, city"
		# remove anything up to and including ", "
		# if there is no change, city is empty
		city=`echo "$name_and_city" | LC_ALL=C sed -e 's/^.*, //'`
		if [ "$city" = "$name_and_city" ]
		then # no city data, use wider area
			city="$location"
		fi

	# EXTRACT CAVE ID
		cid=`echo "$cave" | LC_ALL=C sed -e 's/^.*\[//' -e 's/\].*$//'`
		if [ "$cid" = "$cave" ]; then cid=""; fi

	# EXTRACT GENETIC-MORPHOLOGICAL CLASS
		class=`echo "$cave" | LC_ALL=C sed -e 's/^.*{//' -e 's/}.*$//'`
		if [ "$class" = "$cave" ]; then class=""; fi

		# finnishdata="";
		# if [ "$cid" != "" ]; then finnishdata=" [{$cid}]"; fi
		# if [ "$class" != "" ]; then finnishdata="${finnishdata} {${class}}"; fi

	# UPDATE DESCRIPTION WITH ID AND CLASS
		# descr gets reset at read, but the following need to be reset here
		descr_fi="";
		descr_se="";
		descr_en="";
		if [ "$class" != "" -o "$cid" != "" ]
		then # update description.
			if [ "$descr" != "" ]; then
				descr=" $descr";
				descr_fi=" $descr";
				descr_se=" Mera information på finska.";
				descr_en=" More information in Finnish.";
			fi # add space
			if [ "$class" = "" ]	# or [ -z "$class" ]
			then	# lisää vain ID
				descr="Luolan tunniste ${cid}.$descr";
				descr_fi="Luolan tunniste ${cid}.$descr_fi";
				descr_se="Finsk grott-ID ${cid}.$descr_se";
				descr_en="Finnish cave ID ${cid}.$descr_en";
			else	# lisää luokitus ja ehkä ID
				descr="Geneettis-morfologinen luokitus {${class}}.$descr";
				descr_fi="Geneettis-morfologinen luokitus {${class}}.$descr_fi";
				descr_se="Finsk genetisk-morfologisk grottklass {${class}}.$descr_se";
				descr_en="Finnish genetic-morphological cave class {${class}}.$descr_en";
				if [ "$cid" != "" ]; then
					descr="Luolan tunniste ${cid}. $descr";
					descr_fi="Luolan tunniste ${cid}. $descr_fi";
					descr_se="Finsk grott-ID ${cid}. $descr_se";
					descr_en="Finnish cave ID ${cid}. $descr_en";
				fi
			fi
		fi
		

	# EXTRACT ALTERNATIVE NAMES
		# prepend [" and append "] and replace each " / " with ", "
		namelist="[\"`echo ${name} | LC_ALL=C sed 's/ \/ /", "/g'`\"]"
		# if the list is just ["cave name"] then namelist is empty

		if [ "$namelist" = '["'"${name}"'"]' ]
		then
			# list of alternative names is empty object
			namelist="[]";
		else
			# use the first name in the list as main cave name
			name="`echo ${name} | LC_ALL=C sed 's/ \/ .*$//'`";
			# namelist will contain them all
		fi

	# FORMAT LISTS
	#	A,B , C -> {"A","B","C"}
		# activitylist="[\""`echo "$activitylist" | LC_ALL=C sed 's/ *, */\", \"/'`"\"]"
		subactivitylist='["'`echo "$subactivitylist" | LC_ALL=C sed 's/ *, */\", \"/'`'"]'
		echo "$subactivitylist" | grep -q -e Rock -e Ice -e Other-Material
		if [ $? -ne 0 ]
		then
			echo "ERROR: Every cave MUST include at least Rock or Ice or Other-Material among the subactivities (to exclude Man-Made)."
			echo "Cave $name File: $DATA"
			echo "Aborting."
			exit 1
		fi

	# VERIFY THAT DATA WILL MATCH DISPLAY FILTERS
		if [ "$activity" != "Caving"  ]
		then
			echo "ERROR: Only entries listing Caving as main activity will be displayed."
			echo "Fix record: Cave: $name File: $DATA"
			exit 1
		fi


	# GENERATE SUBACTIVITY LIST BASED ON PREVIOUS DATA AND FINNISH CAVE CLASSIFICATION
		subactivitylist=`split "$class" "$subactivitylist"`

	# GENERATE PUBLICATION REFERENCE FOR FINNISH CAVES
		if [ "$cid" != "" ]	# the cave has an id: Suomen luolat / Itä-Savon luolat
		then
			area_code=`echo $cid | sed 's/[0-9][0-9]*$//'`
			case $area_code in
			U|KY|TP|HÄ|MI|VA|KS|KU|PK|OU|LA|ÅL)	# Suomen luolat-kirja
				LITTERATURE='
				, { "t": "'"${cid} ${name}"'",
				"w": ["Aimo Kejonen"],
				"y": 2015,
				"a": ["'"${activity}"'"],
				"sa": [['${subactivitylist}']],
				"p": "'"${SUOMEN_LUOLAT}"'" }';
				year=2015 ;;
			SA|EN|RA|SU|PU|RU)			# Itä-Savon luolat blogi
				# No litterature reference but default year is known
				year=2018 ;;
			*)	LITTERATURE="" ;;	# Muita kirjallisuusviitteitä ei (ainakaan vielä tueta; ei tallennuspaikkaa)
			esac
		else
			LITTERATURE="";
		fi


	# PROCESS WEB REFERENCE

	# Remove everything before http
	# Also remove everyting from the end of the line upto the first space counted from left.

	# Extract the year
		# First strip url and title: http.*$
		# Then remove everything from the end upto and including the first space
		webref_date=`echo "$webref" | LC_ALL=C sed 's/http.*$//' | LC_ALL=C sed 's/ .*//'`
		webref_year=`echo "$webref_date" | LC_ALL=C cut -c1-4`
			if [ "$webref_year" != "" ]; then year="$webref_year"; fi	# SOME DATE GUESSING MAGIC EARLIER (Suomen luolat, Itä-Savon luolat)
			if [ "$year" = "" ]; then year="2020"; fi			# ~FAIL
		webref_month=`echo "$webref_date" | LC_ALL=C cut -c5-6`
		webref_day=`echo "$webref_date" | LC_ALL=C cut -c7-8`
		# MM,DD EI VIELÄ KIRJOITETA JSONIIN. VOISI LAITTAA JOS HALUAISI.

	# If there is a CSV list of names between date and URL, then extract and use it
		webref_peoplenames=`echo "$webref" | LC_ALL=C sed -e 's/^[0-9][0-9]* //' -e 's/[ ]*http.*$//'`
		if [ "$webref_peoplenames" != "" ]
		then
			reporters="$webref_peoplenames"
			reporters='["'`echo "$reporters" | sed 's/ *, */","/g'`'"]'	# Format it as a JSON list
		fi

	# Extract the URL
		# First, remove everything before http
		# Second, remove space + [ + every non-[ letter from the end. Note: [ not allowed in the latter part (linkname!)
		url=`echo "$webref" | LC_ALL=C sed 's/^.*http/http/' | LC_ALL=C sed 's/ \[[^\[]*$//'`

	# Extract webref title: .*[title].*
		# First remove optional date and name list, then remove the URL (no spaces) and trailing space(s)
		# What is left is the title
		webref_title=`echo "$webref" | LC_ALL=C sed 's/^.*\[//' | LC_ALL=C sed 's/\].*$//'`
		if [ "$webref_title" = "$webref" ];
		then
			webref_title="$name";
		fi

	# ADD MAP LINK IF A MAP IS DEFINED
	MAPINFO="";
	if [ "$mapurl" != "" ]
	then
		MAPINFO=', "m": "'${mapurl}'"';
	fi

# HUOM MYLS "m": mapurl mukaan!!!

	# DEBUGGING OUTPUT
	if [ "$VERBOSE" = "true" ]
	then
		echo "-----------------------------------------------------"
		echo "IMPORTING ["${COUNTER}"]"
		echo "Cave $name";
		echo "Position Y $y X $x Lat $lat Lon $lon";
		echo "Location $location $country $continent";
		echo "Length (${la}) $length m";
		echo "Reported by $reporters as $activity of type(s) $subactivitylist";
		echo "Web reference [YYYY[MM[DD]]] PeopleNamesCSV URL TitleString: $webref";
	fi

	# OUTPUT
	#	Note
	#		year is hardcoded to 2020 as year is lacking in data
	#		but all articles at luolaseura.fi are from 2020!


	# 1) WRITE LENGTHS
	if [ -z "$class" ]; then stat_class="-"; else stat_class="$class"; fi
	if [ -z "$cid" ]; then stat_cid="-----"; else stat_cid="$cid"; fi
	printf "%08.1f\t%-15s\t%-15s\t%6s\t%-40s\n" "${length}" "${stat_class}" "${country}" "${stat_cid}" "${name}" >> $LENGTH_DATA


	# 2) WRITE KML FOR EXPORT
		# The description field can contain HTML because of <![CDATA[ ]]
		cat << EOKML >> $KML_PLACEMARKS
<Placemark>
	<name>${name}</name>
	<description>${descr}</description>
	<Point>
		<coordinates>${lon},${lat},0</coordinates>
	</Point>
</Placemark>
EOKML
	
	# 3) WRITE GPX
		# not yet implemeneted


	# 4) APPEND activityJSON LIST DATA
	cat << EOTXT >> $OUTPUT
		, {
		"type": "Feature",
		"geometry": {
			"type": "Point",
			"coordinates": [${lat}, ${lon}] }, 
		"properties": {
			"n": "${name}, ${city}",
			"an": ${namelist},
			"d": {	"fi": "${descr_fi}",
				"se": "${descr_se}",
				"en": "${descr_en}" },
			"la": "${la}",
			"l": ${length},
			"k": "${location}",
			"c": "${country}",
			"o": "${continent}",
			"rl": [{ "t": "${webref_title}",
				"w": ${reporters},
				"y": ${year},
				"a": ["${activity}"],
				"sa": [[${subactivitylist}]],
				"u": "${url}" } ${LITTERATURE} ]
			$MAPINFO
			}
		}
EOTXT
done

if [ $? -ne 0 ]; then exit 1; fi

db_add_records
if [ $? -eq 0 ]
then
	rm $OUTPUT
	exit 0
else
	echo "ERROR: Appending database failed with error code $?"
	exit 1
fi

exit 1 
