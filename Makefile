CXX=g++

all: vm

vm: vm.cpp
	$(CXX) -o $@ $^

