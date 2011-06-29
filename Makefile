CXX=g++
CP=cp -r
RM=rm -rIf

all: fetus fetoid

full: fetus fetoid brainfuck

.PRECIOUS: %_c %_pp

%_c: languages/%/compiler.lua
	$(CP) $^ $@

%_pp: languages/%/preprocessor.lua
	$(CP) $^ $@
	
%_pp:
	
%: scripts/% %_pp %_c fetus_vm
	$(CP) $< $@

fetus_vm: src/fetus.cpp src/vm.cpp
	$(CXX) -o $@ $^

clean:
	$(RM) fetus_vm *_c *_pp fetus fetoid brainfuck

%: src/vm.cpp %.ftsb
	src/standalone $@.ftsb $@.cpp
	$(CXX) -o $@ $@.cpp src/vm_core.cpp -Isrc

