#!/bin/bash

TEMPNAME=jsahTempDmkFileSA

./preprocessor.lua $1 | ./compile.lua - $TEMPNAME
./vm.lua $TEMPNAME $2 $3 $4 $5 $6 $7 $8 $9
rm $TEMPNAME
