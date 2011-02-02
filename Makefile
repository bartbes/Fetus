CXX=g++
CP=cp -r
RM=rm -rIf

all: fetus_pp fetus_c fetus_vm

fetus_vm: src/vm.cpp
	$(CXX) -o $@ $^

fetus_pp: src/preprocessor.lua
	$(CP) $^ $@

fetus_c: src/compiler.lua
	$(CP) $^ $@

clean:
	$(RM) fetus_vm fetus_c fetus_pp

