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
	if (f->fail())
	{
		cout<<"Input error" <<endl;
		delete f;
		return 1;
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
	// Create a VM.
	VM vm;
	// Create a parser and let it parse
	// the file for us.
	Parser p(&vm);
	p.parseBlob(buffer, l);
	// And start the main loop!
	vm.run();
	return 0;
}
