#!/bin/bash

./preprocessor.lua $1
./compile.lua a.ftsp
./vm.lua a.ftsb $2 $3 $4 $5 $6 $7 $8 $9
