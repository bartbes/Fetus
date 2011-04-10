#!/bin/bash

#Be sure to build the entire toolchain
make full

log()
{
	echo -e "\033[;32m$*\033[;37m"
}

#example_files=`find examples/ -type f`
example_files= #don't run examples
test_files=`find tests/ -type f`

files="$example_files $test_files"

for file in $files; do
	log "Running file: $file"
	extension=`echo $file | sed 's/.*\.\(.*\)/\1/'`
	case $extension in
		fts)
			./fetus $file
			;;
		ftd)
			./fetoid $file
			;;
		bf|b)
			./brainfuck $file
			;;
		*)
			log "Don't recognize extension $extension"
			;;
	esac
	log "Done"
done
