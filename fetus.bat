@echo off

lua preprocessor.lua %1 > nul
lua compile.lua a.ftsp > nul
lua vm.lua a.ftsb %2 %3 %4 %5 %6 %7 %8 %9
