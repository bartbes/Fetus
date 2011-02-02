CXX=g++

all: fetus_vm

fetus_vm: vm.cpp
	$(CXX) -o $@ $^

clean:
	rm -rIf fetus_vm

