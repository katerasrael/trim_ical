#!/bin/sh

# All of the events preceeding the year will be removed from the calendar.

# Arguments:
# -h help / usage
# -i the calendar inputfile
# -y all events preceeding the year will be removed
# -o outputfile
# -p file to contain the preceding events
# -v be verbose

CALENDAR_FILE=""
OUT_FILE=""
PRE_FILE=""
YEAR=""
VERBOSE=false

usage() { echo "Usage: $0 [-h help] [-y <year all events preceding the year will be removed] [-i <inputfile>] [-o <outputfile with events after year>] [-p <file to contain the preceeding events>]" 1>&2; exit 0; }

while getopts ":hvy:i:o:p:" o; do
    case "${o}" in
        i)
            CALENDAR_FILE=${OPTARG}
            ;;
        o)
            OUT_FILE=${OPTARG}
            ;;
        p)
            PRE_FILE=${OPTARG}
            ;;
        y)
            YEAR=${OPTARG}
            ;;
        v)
            VERBOSE=true
            ;;
		h)
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${CALENDAR_FILE}" ] || [ -z "${OUT_FILE}" ] || [ -z "${PRE_FILE}" ] || [ -z "${YEAR}" ]; then
    usage
fi

if $VERBOSE; then
	echo "CALENDAR_FILE = ${CALENDAR_FILE}"
	echo "OUT_FILE = ${OUT_FILE}"
	echo "PRE_FILE = ${PRE_FILE}"
	echo "YEAR = ${YEAR}"
fi

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

if $VERBOSE; then
	echo "total events found: " ${total_files}
fi

# move the events to a separate temp directory
mv xx* endcontent ${temp_dir} && cd ${temp_dir}

for f in ./*
do
	if $VERBOSE; then
		echo "Processing $f file..."
	fi
	if grep -q RRULE $f; then	# check for reoccurring events
		if grep -q "UNTIL=" $f; then
			endjahr=$( grep -R RRULE $f | grep -R "UNTIL" | grep -v "WKST" | cut -d"=" -f3 | sed -s "s/\([0-9]\{4\}\).*/\1/g")
			if [ "$endjahr" -ge  "$YEAR" ]; then
				if $VERBOSE; then
					echo "RRULE $endjahr ist größergleich als $YEAR in $f"
				fi
				cat $f >> events
			fi
		else
			if $VERBOSE; then
				echo "RRULE ohne Enddatum"
			fi
			cat $f >> events
		fi
	else	# no reoccurring event, so check the DTSTART-Date
		endjahr=$(grep -R DTSTART $f |  cut -d":" -f2 | sed -s "s/\([0-9]\{4\}\).*/\1/g")
		if $VERBOSE; then
			echo "DTSTART endjahr ist $endjahr"
		fi
		if [ $endjahr \> "$YEAR" ]; then
			if $VERBOSE; then
				echo "DTSTART $endjahr ist größergleich als $YEAR in $f"
			fi
			cat $f >> events
		fi
	fi
done

sed -i '/END:VCALENDAR/d' events

# reassemblee
cat xx00000 events xx`printf "%05d" $((total_files-1))` endcontent > ${OUT_FILE}

# cleaning
cd ${rpwd}
mv ${temp_dir}/${OUT_FILE} ${OUT_FILE}

rm -rf ${temp_dir}

if $VERBOSE; then
	echo "your new ics file is here: ${rpwd}/${CALENDAR_FILE}"
fi
