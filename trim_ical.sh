#!/bin/sh
#
# This is a fork from https://gist.github.com/pboesch/7846aed47914adc7f34c527fceb8d200
#
# 2021 extended by Amdreas Bär, asbaer@asrael.franken.de
#
#
# All of the events preceeding the year will be removed from the calendar.
#
# Arguments:
# -h help / usage
# -i the calendar inputfile
# -y all events preceeding the year will be removed
# -o outputfile
# -p file to contain the preceding events
# -d display some debug messages

# KNOWN BUGS: calendar inputfile must be placed in the current directory paths are not respected

CALENDAR_FILE=""
OUT_FILE=""
PRE_FILE=""
YEAR=""
DEBUG=false

usage() { echo "Usage: $0 [-h help] [-d debug] [-y <year all events preceding the year will be removed] [-i <inputfile>] [-o <outputfile with events after year>] [-p <file to contain the preceeding events>]" 1>&2; exit 0; }

while getopts ":hdy:i:o:p:" o; do
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
        d)
            DEBUG=true
            ;;
		h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${CALENDAR_FILE}" ] || [ -z "${OUT_FILE}" ] || [ -z "${YEAR}" ]; then
    usage
fi

if $DEBUG; then
	echo "CALENDAR_FILE = ${CALENDAR_FILE}"
	echo "OUT_FILE = ${OUT_FILE}"
	echo "PRE_FILE = ${PRE_FILE}"
	echo "YEAR = ${YEAR}"
fi

temp_dir=$(mktemp -d)
temp_files_digits=5
rpwd=$(pwd)

# move the events to a separate temp directory
cp $CALENDAR_FILE ${temp_dir} && cd ${temp_dir}

# split the calendar file into separate files for each event. This script creates multiple files in the form of xx00000
total_files=$(csplit -n ${temp_files_digits} ${CALENDAR_FILE} '/BEGIN:VEVENT/' {*} | wc -l)

if $DEBUG; then
	echo "total events found: " ${total_files}
fi

# rename the leading content from the input file
mv xx00000 startcontent

# this last line leads to a last event which could contain some unwantend content after the END:VEVENT
# slipt of the last event
csplit -s --suppress-matched xx`printf "%05d" $((total_files-1))` '/END:VEVENT/'

# add end
echo "END:VEVENT" >> xx00

# make it the last event-file
mv xx00 xx`printf "%05d" $((total_files-1))`

# strip the "END:VEVENT" of the event before...
sed -i '1d' xx01

# rename it
mv xx01 endcontent

for f in ./xx*
do
	if $DEBUG; then
		echo "Processing $f file..."
	fi
	if grep -q RRULE $f; then	# check for reoccurring events
		if grep -q "UNTIL=" $f; then
			endjahr=$( grep RRULE $f | sed 's/^.*UNTIL=//' | sed -s "s/\([0-9]\{4\}\).*/\1/g")
			if [ "$endjahr" -ge "$YEAR" ]; then
				if $DEBUG; then
					echo "RRULE found - $endjahr greater or equal to $YEAR in $f"
				fi
				cat $f >> events
			else
				if $DEBUG; then
					echo "RRULE found - $endjahr is less than $YEAR in $f"
				fi
				if [ "${PRE_FILE}" ]; then
					cat $f >> pre_events
				fi
			fi
		else
			if $DEBUG; then
				echo "RRULE found - no end defined"
			fi
			cat $f >> events
		fi
	else	# no reoccurring event, so check the DTSTART-Date
		event_start=$(grep DTSTART $f | cut -d":" -f2 | sed -s "s/\([0-9]\{4\}\).*/\1/g")
		if $DEBUG; then
			echo "DTSTART is $event_start"
		fi
		if [ "$event_start" -ge "$YEAR" ]; then
			if $DEBUG; then
				echo "DTSTART $event_start greater or equal to $YEAR in $f"
			fi
			cat $f >> events
		else # save the older events
			if $DEBUG; then
				echo "DTSTART $event_start is less than $YEAR in $f"
			fi
			if [ "${PRE_FILE}" ]; then
				cat $f >> pre_events
			fi
		fi
	fi
done

# reassemble
cat startcontent events endcontent > ${OUT_FILE}

if [ "${PRE_FILE}" ]; then
	cat startcontent pre_events endcontent > ${PRE_FILE}
fi

# cleaning
cd ${rpwd}
mv ${temp_dir}/${OUT_FILE} ${OUT_FILE}
if [ "${PRE_FILE}" ]; then
	mv ${temp_dir}/${PRE_FILE} ${PRE_FILE}
fi

rm -rf ${temp_dir}

if $DEBUG; then
	echo "your new ics file is here: ${rpwd}/${OUT_FILE}"
	
	if [ "${PRE_FILE}" ]; then
		echo "your new ics file is here: ${rpwd}/${PRE_FILE}"
	fi
fi
