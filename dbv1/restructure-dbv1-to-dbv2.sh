#!/bin/sh

workdir=./restructured

# if [ ! -e $workdir ]
# then
#	mkdir $workdir
# fi

# HUOM! sed vaatii LC_ALL=C jotta utf8-merkit tunnistetaan useana oktettina,
# eikä yhtenä merkkinä (jolloin .* mätsäys ymv menisivät rikki)

# NOTE! sed requires LC_ALL=C to work flawlessly. Characters in utf8 are treated as several octets then,
# and not as single letters. Without LC_ALL=C some pattern matching (e.g. with .* would fail).

ls import-*.txt | while read infile
do
	outfile=$workdir/$infile
	lineno=0

	cat $infile | LC_ALL=C sed -e 's/\r$//' | while read line
	do
		# lineno=`expr $lineno + 1`
		lineno=$(($lineno + 1))

		if [ $lineno -eq 14 ]; then lineno=1; fi

		if [ $lineno -eq 1 ]
		then
			cid=`echo "$line" | LC_ALL=C sed -e 's/^.*\[//' -e 's/\].*$//'`
			if [ "$cid" = "$line" ]; then cid=""; fi

			class=`echo "$line" | LC_ALL=C sed -e 's/^.*{//' -e 's/}.*$//'`
			if [ "$class" = "$line" ]; then class=""; fi

			description=`echo "$line" | LC_ALL=C sed -e 's/^[^(]*(//' -e 's/).*$//'`
			if [ "$description" = "$line" ]; then description=""; fi

			name=`echo "$line" | LC_ALL=C sed -e 's/ (.*)//' | LC_ALL=C sed -e 's/, .*$//'`

			city=`echo "$line" | LC_ALL=C sed -e 's/ (.*)//' | LC_ALL=C sed -e 's/^[^,]*, //' -e 's/ [\[|{].*$//'`
			cleaned_line=`echo "$line" | LC_ALL=C sed -e 's/ (.*)//'`
			if [ "$city" = "$cleaned_line" ]; then city=""; fi

			# DEBUG
			# if [ "$line" != "$cleaned_line" ];
			# then
			#	echo "$line"
			#	echo "$cleaned_line"
			#	echo "Description: $description"
			#fi
			echo "$cleaned_line"
			echo "$description"
		else
			echo "$line"
		fi
	done > $outfile
done 

