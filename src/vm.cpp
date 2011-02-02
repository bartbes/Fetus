#include <iostream>
#include <fstream>
#include <sstream>
#include <cstring>
#include "vm_core.h"

using namespace std;

int main(int argc, const char **argv)
{
	if (argc < 2)
	{
		cout<<"Usage: " <<argv[0] <<" <file>\n";
		return 0;
	}
	char *buffer;
	istream *f;
	if (strcmp(argv[1], "-") == 0)
	{
		std::stringstream *stream = new std::stringstream();
		*stream << cin.rdbuf();
		f = stream;
	}
	else
	{
		f = new ifstream(argv[1]);
	}
	f->seekg(0, ios::end);
	int l = f->tellg();
	f->seekg(0, ios::beg);
	buffer = new char[l];
	f->read(buffer, l);
	delete f;
	contexts.insert(0, buffer);
	unsigned int n;
	for (int i = 2; i < argc; i++)
	{
		sscanf(argv[i], "%u", &n);
		stack.push(n);
	}
	parse();
	for (int i = 0; i < contexts.length(); i++)
	{
		delete[] contexts.get(i);
	}
}
