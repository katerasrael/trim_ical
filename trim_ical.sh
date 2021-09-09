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

echo "total events found: " ${total_files}

# move the events to a separate temp directory
mv xx* ${temp_dir} && cd ${temp_dir}

# time to remove what we do not need
# TODO: preserve reoccurring events in case they have DEND after $YEAR
grep -R DTSTART . | sed -s "s/\.\/\(xx[0-9]\+\).*:\([0-9]\{4\}\).*/\1 \2/g" | awk '{if($2>="'"$YEAR"'") print $1;}' | xargs -L 1 cat > events
sed -i '/END:VCALENDAR/d' events

# reassemblee
cat xx00000 events xx`printf "%05d" $((total_files-1))` > ${CALENDAR_FILE}

# cleaning
cd ${rpwd}
rm ${CALENDAR_FILE}
mv ${temp_dir}/${CALENDAR_FILE} ${CALENDAR_FILE}

rm -rf ${temp_dir}

echo "your new ics file is here: ${rpwd}/${CALENDAR_FILE}"