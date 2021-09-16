Removes all events preceeding a given year from an .ics calendar file (the kind you can find e.g. in a [Radicale](http://radicale.org/)-based CalDAV server).

Forked from https://gist.github.com/pboesch/7846aed47914adc7f34c527fceb8d200

## Usage:

```
./trim_ical.sh -y year -i input_file -o output_file [-p preceding_file] [-d] # removes all events starting before the year 2016 from the calendar stored in Personal.ics file
```
