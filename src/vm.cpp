#include <iostream>
#include <cstring>
#include <cstdio>
#include "vm.h"

using namespace Fetus;

Context::Context(std::string &code, bool owned)
	: owned(owned)
{
	codeLength = code.length();
	this->code = new unsigned char[codeLength];
	memcpy(this->code, code.c_str(), codeLength);
}

Context::Context(unsigned char *code, size_t length, bool owned)
	: codeLength(length), owned(owned)
{
	this->code = new unsigned char[codeLength];
	memcpy(this->code, code, codeLength);
}

unsigned int Context::parse(unsigned char opcode, unsigned int arg)
{
	return QUIT;
}

unsigned int Context::run(Stack *stack)
{
	unsigned int result;
	while (ip+2 < codeLength)
	{
		result = parse(code[ip++], (code[ip++]<<8) | code[ip++]);
		if (result != NOP)
			return result;
	}
}

Context::~Context()
{
	delete[] code;
}

bool VM::addContext(Context* context)
{
	if (contexts.size() < MAX_CONTEXT)
	{
		contexts.push_back(context);
		return true;
	}
	return false;
}

void VM::run()
{
	unsigned int curContext = 0;
	while(contexts.size() > curContext)
	{
		curContext = contexts[curContext]->run(&stack);
	}
	if (curContext != QUIT)
		fprintf(stderr, "Invalid context switch, context %x does not exist.\n", curContext);
}

VM::~VM()
{
	for (std::vector<Context*>::iterator i = contexts.begin(); i != contexts.end(); i++)
	{
		Context *v = *i;
		if (v->owned)
			delete v;
	}
}
