CXX=g++
CP=cp -r
RM=rm -rIf

all: fetus_pp fetus_c fetus_vm fetoid_c brainfuck_c

fetus_vm: src/vm.cpp src/vm_core.cpp
	$(CXX) -o $@ $^

fetus_pp: src/preprocessor.lua
	$(CP) $^ $@

fetus_c: src/compiler.lua
	$(CP) $^ $@

fetoid_c: languages/fetoid/compiler.lua
	$(CP) $^ $@

brainfuck_c: languages/brainfuck/compiler.lua
	$(CP) $^ $@

clean:
	$(RM) fetus_vm fetus_c fetus_pp

%: src/vm_core.cpp %.ftsb
	src/standalone $@.ftsb $@.cpp
	$(CXX) -o $@ $@.cpp src/vm_core.cpp -Isrc

