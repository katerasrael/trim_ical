#!/bin/sh

# first argument - the calendar file
# second argument - the year.

# All of the events preceeding the year will be removed from the calendar.

CALENDAR_FILE=$1
YEAR=$2

temp_dir=$(mktemp -d)
temp_files_digits=5
rpwd=$(pwd)

# backup the calendar just in case
cp ${CALENDAR_FILE} ${CALENDAR_FILE}.bak

# split the calendar file into separate files for each event. This script creates multiple files in the form of xx00000
total_files=$(csplit -n ${temp_files_digits} ${CALENDAR_FILE} '/BEGIN:VEVENT/' {*} | wc -l)

# this last line leads to a last event which could contain some unwantend content after the END:VEVENT
# slipt of the last event
csplit --suppress-matched xx`printf "%05d" $((total_files-1))` '/END:VEVENT/'

# add end
echo "END:VEVENT/" >> xx00
mv xx00 xx`printf "%05d" $((total_files-1))`

mv xx01 endcontent


echo "total events found: " ${total_files}

# move the events to a separate temp directory
mv xx* endcontent ${temp_dir} && cd ${temp_dir}

# time to remove what we do not need
# TODO: preserve reoccurring events in case they have DEND after $YEAR
#grep -R DTSTART . | sed -s "s/\.\/\(xx[0-9]\+\).*:\([0-9]\{4\}\).*/\1 \2/g" | awk '{if($2>="'"$YEAR"'") print $1;}' | xargs -L 1 cat > events

for f in ./*
do
	echo "Processing $f file..."
	if grep -q RRULE $f; then	# check for reoccurring events
		if grep -q "UNTIL=" $f; then
			endjahr=$( grep -R RRULE $f | grep -R "UNTIL" | grep -v "WKST" | cut -d"=" -f3 | sed -s "s/\([0-9]\{4\}\).*/\1/g")
	                if [ "$endjahr" -ge  "$YEAR" ]; then
				echo "RRULE $endjahr ist größergleich als $YEAR in $f"
				cat $f >> events
			fi
		else
			echo "RRULE ohne Enddatum"
			cat $f >> events
		fi
	else	# no reoccurring event, so check the DTSTART-Date
		endjahr=$(grep -R DTSTART $f |  cut -d":" -f2 | sed -s "s/\([0-9]\{4\}\).*/\1/g")
		echo "DTSTART endjahr ist $endjahr"
                if [ $endjahr \> "$YEAR" ]
			 then
                        	cat $f >> events
				echo "DTSTART $endjahr ist größergleich als $YEAR in $f"
                fi
	fi
done

sed -i '/END:VCALENDAR/d' events

# reassemblee
cat xx00000 events xx`printf "%05d" $((total_files-1))` endcontent > ${CALENDAR_FILE}

# cleaning
cd ${rpwd}
rm ${CALENDAR_FILE}
mv ${temp_dir}/${CALENDAR_FILE} ${CALENDAR_FILE}

rm -rf ${temp_dir}

echo "your new ics file is here: ${rpwd}/${CALENDAR_FILE}"
