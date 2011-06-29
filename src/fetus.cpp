#include <iostream>
#include <fstream>
#include <sstream>
#include <cstring>
#include "vm.h"

using namespace std;
using namespace Fetus;

int main(int argc, const char **argv)
{
	// Usage information.
	if (argc < 2)
	{
		cout<<"Usage: " <<argv[0] <<" <file>\n";
		return 0;
	}
	char *buffer;
	istream *f;
	// If it's -, read from stdin.
	if (strcmp(argv[1], "-") == 0)
	{
		std::stringstream *stream = new std::stringstream();
		*stream << cin.rdbuf();
		f = stream;
	}
	// Otherwise, just open the file.
	else
	{
		f = new ifstream(argv[1]);
	}
	// Determine the size.
	f->seekg(0, ios::end);
	int l = f->tellg();
	f->seekg(0, ios::beg);
	// Allocate a buffer.
	buffer = new char[l];
	// Read the data.
	f->read(buffer, l);
	delete f;
	VM vm;
	Context *main = new Context((unsigned char*) buffer, l, 0);
	// It copies, so we no longer need the buffer.
	delete[] buffer;
	// Add it to the VM.
	vm.addContext(main);
	// And start the main loop!
	vm.run();
	// We don't delete main?
	// Correct, we asked the vm
	// to do it for us.
}
