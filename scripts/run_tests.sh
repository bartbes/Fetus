#!/bin/bash

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
	compiled=`mktemp`
	case $extension in
		fts)
			preprocessed=`mktemp`
			./fetus_pp $file $preprocessed
			if [ $? -ne 0 ]; then
				rm $preprocessed
				continue
			fi
			./fetus_c $preprocessed $compiled
			if [ $? -ne 0 ]; then
				rm $preprocessed $compiled
				continue
			fi
			rm $preprocessed
			;;
		ftd)
			./fetoid_c $file $compiled
			if [ $? -ne 0 ]; then
				rm $compiled
				continue
			fi
			;;
		bf|b)
			./brainfuck_c $file $compiled
			if [ $? -ne 0 ]; then
				rm $compiled
				continue
			fi
			;;
		*)
			log "Don't recognize extension $extension"
			rm $compiled
			continue
			;;
	esac
	./fetus_vm $compiled
	rm $compiled
	log "Done"
done
