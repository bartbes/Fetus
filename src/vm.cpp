#include <iostream>
#include <cstring>
#include <cstdio>
#include <cmath>
#include "vm.h"

using namespace Fetus;

// The Stack methods
// the names should be
// descriptive enough.
void Stack::push(unsigned int val)
{
	stack.push(val);
}

unsigned int Stack::pop()
{
	if (stack.empty())
		return 0;
	unsigned int val = stack.top();
	stack.pop();
	return val;
}

unsigned int Stack::top()
{
	if (stack.empty())
		return 0;
	return stack.top();
}

bool Stack::empty()
{
	return stack.empty();
}

void Stack::clear()
{
	while (!stack.empty())
		stack.pop();
}

// The context, copy the code over.
Context::Context(std::string &code, unsigned int *funcTable, bool owned)
	: ip(0), fp(0), owned(owned)
{
	codeLength = code.length();
	this->code = new unsigned char[codeLength];
	memcpy(this->code, code.c_str(), codeLength);
	// The first 'function' is 0, just because we need
	// a value in there, it is unused.
	functions.push_back(0);
	// If we got a funcTable (and not NULL), add it.
	if (funcTable)
	{
		// Until we find a 0 entry, we'll go and add it to the function table.
		for (unsigned int pointer = *funcTable; *funcTable != 0; pointer = *(++funcTable))
		{
			functions.push_back(pointer);
		}
	}
}

// C string version of the above.
Context::Context(const unsigned char *code, size_t length, unsigned int *funcTable, bool owned)
	: ip(0), codeLength(length), fp(0), owned(owned)
{
	this->code = new unsigned char[codeLength];
	memcpy(this->code, code, codeLength);
	// The first 'function' is 0, just because we need
	// a value in there, it is unused.
	functions.push_back(0);
	// If we got a funcTable (and not NULL), add it.
	if (funcTable)
	{
		// Until we find a 0 entry, we'll go and add it to the function table.
		for (unsigned int pointer = *funcTable; *funcTable != 0; pointer = *(++funcTable))
		{
			functions.push_back(pointer);
		}
	}
}

void Context::setStrings(std::vector<std::string> strings)
{
	this->strings = strings;
}

// The Fetus functions, in a nice big switch-case
void Context::runFunction(unsigned int function)
{
	switch(function)
	{
		case 0x0001:			//puts
			std::cout<<strings[stack->pop()];
			break;
		case 0xffff:			//putn
			std::cout<<stack->top() <<std::endl;
			break;
		default:
			fprintf(stderr, "Invalid function %04x called\n", function);
	}
}


// The Fetus opcodes, another switch-case.
unsigned int Context::parse(unsigned char opcode, unsigned int arg)
{
	// Our temporary variables:
	unsigned int t;
	switch(opcode)
	{
		case 0x01:			//get
			stack->push(mem[arg]);
			break;
		case 0x02:			//set
			mem[arg] = stack->top();
			break;
		case 0x03:			//put
			stack->push(arg);
			break;
		case 0x04:			//pop
			stack->pop();
			break;
		case 0x05:			//call
			runFunction(arg);
			break;
		case 0x06:			//clear
			stack->clear();
			break;
		case 0x07:			//getp
			stack->push(mem[stack->pop()]);
			break;
		case 0x08:			//goto
			if (stack->pop() > 0)
				ip = arg * 3;
			break;
		case 0x09:			//gotos
			t = stack->pop();
			if (stack->pop() > 0)
				ip = t * 3;
			break;
		case 0x0a:			//add
			t = stack->pop();
			stack->push(stack->pop() + t);
			break;
		case 0x0b:			//sub
			t = stack->pop();
			stack->push(stack->pop() - t);
			break;
		case 0x0c:			//mult
			t = stack->pop();
			stack->push(stack->pop() * t);
			break;
		case 0x0d:			//div
			t = stack->pop();
			stack->push(stack->pop() / t);
			break;
		case 0x0e:			//pow
			t = stack->pop();
			stack->push((unsigned int) pow((double) stack->pop(), (double) t));
			break;
		case 0x0f:			//root
			t = stack->pop();
			stack->push((unsigned int) pow(stack->pop(), 1.0/t));
			break;
		case 0x10:			//mod
			t = stack->pop();
			stack->push(stack->pop() % t);
			break;
		case 0x11:			//eq
			stack->push((stack->pop() == stack->pop()) ? 1 : 0);
			break;
		case 0x12:			//lt
			stack->push((stack->pop() > stack->pop()) ? 1 : 0);
			break;
		case 0x13:			//gt
			stack->push((stack->pop() < stack->pop()) ? 1 : 0);
			break;
		case 0x14:			//not
			stack->push((stack->pop() == 0)? 1 : 0);
			break;
		case 0x15:			//pos
			stack->push(ip/3);
			break;
		/*case 0x16:			//ascii
			buffer = new char[16];
			sprintf(buffer, "%d", stack->top());
			insertmem(arg, buffer);
			delete[] buffer;
			break;
		case 0x17:			//num
			buffer = extractmem(arg);
			sscanf(buffer, "%d", &t);
			stack->push(t);
			delete[] buffer;
			break;*/
		case 0x18:			//setp
			t = stack->pop();
			mem[stack->pop()] = t;
			break;
		case 0x19:			//ctxt
			return arg;
		case 0x1a:			//ctxts
			return stack->pop();
		case 0x1b:			//ctxtn
			stack->push(n);
			break;
		case 0x1c:			//setf
			targetfp = arg;
			break;
		case 0x1d:			//setfs
			targetfp = stack->pop();
			break;
		default:
			fprintf(stderr, "Invalid opcode %02x\n", opcode);
			return QUIT;
	}
	// Continue
	return NOP;
}


// Give this context control
// pass it the stack and roll!
unsigned int Context::run(Stack *stack)
{
	this->stack = stack;
	// If a function pointer (fp) has been set
	// we'll continue execution from there.
	// 0 being continue at current position.
	if (fp != 0)
	{
		ip = functions[fp]*3;
		// Reset the fp
		fp = 0;
	}
	// The target fp will always be 0 until
	// it has been set explicitly.
	targetfp = 0;
	unsigned int result;
	// While we have code left...
	while (ip+2 < codeLength)
	{
		ip += 3;
		// Parse this line
		result = parse(code[ip-3], (code[ip-2]<<8) | code[ip-1]);
		if (result != NOP)
			return result;
	}
	// If we run out of code
	// no matter which context,
	// quit.
	return QUIT;
}

// Delete the allocated code.
Context::~Context()
{
	delete[] code;
}

// Add it to the context list,
// no surprises here.
bool VM::addContext(Context* context)
{
	// Except for this, we can only have
	// contexts up to MAX_CONTEXT.
	if (contexts.size() < MAX_CONTEXT)
	{
		contexts.push_back(context);
		return true;
	}
	return false;
}

// The main loop of the VM.
void VM::run()
{
	// We start at context 0.
	unsigned int curContext = 0;
	unsigned int fp = 0;
	while(contexts.size() > curContext)
	{
		Context *ctxt = contexts[curContext];
		ctxt->fp = fp;
		ctxt->n = curContext;
		// The return value is the next context.
		curContext = ctxt->run(&stack);
		fp = ctxt->targetfp;
	}
	// This context doesn't exist,
	// you lying bastard!
	if (curContext != QUIT)
		fprintf(stderr, "Invalid context switch, context %04x does not exist.\n", curContext);
}

// All contexts we own, we
// take care of (delete them).
VM::~VM()
{
	for (std::vector<Context*>::iterator i = contexts.begin(); i != contexts.end(); i++)
	{
		Context *v = *i;
		if (v->owned)
			delete v;
	}
}

Parser::Parser(VM *vm)
	: vm(vm)
{
}

int Parser::parseBlob(std::string &contents)
{
	return parseBlob((const unsigned char *) contents.c_str(), contents.length());
}

int Parser::parseBlob(const char *contents, size_t len)
{
	return parseBlob((const unsigned char *) contents, len);
}

int Parser::parseBlob(const unsigned char *contents, size_t len)
{
	// Do we have a header?
	if (contents[0] != 0xff)
	{
		// No? We'll have to assume this
		// is purely code, so just parse
		// it as such.
		Context *ctxt = new Context(contents, len, 0, true);
		vm->addContext(ctxt);
		// Only 1 context has been created.
		return 1;
	}
	// So there's a header, let's parse it.

	// The position of our current context header.
	std::vector<unsigned int> functions;
	unsigned char opcode;
	unsigned int arg;
	// The amount of contexts we've added.
	unsigned int contexts = 0;
	// Create temporary values we need.
	unsigned int *funcTable;
	unsigned int counter;
	size_t length;
	Context *ctxt;
	std::string str = "";
	std::vector<std::string> strings;
	// Parse the header.
	for (unsigned int i = 3; contents[i] > 0xf0 && i < len;)
	{
		opcode = contents[i];
		arg = (contents[i+1] << 8) | contents[i+2];
		switch(opcode)
		{
			case 0xf0:		//function
				functions.push_back(arg);
				break;
			case 0xf1:		//next context header
				// Turn the function table into the proper format.
				funcTable = new unsigned int[functions.size()+1];
				counter = 0;
				for (std::vector<unsigned int>::iterator f = functions.begin(); f != functions.end(); f++, counter++)
				{
					funcTable[counter] = *f;
				}
				funcTable[functions.size()] = 0;
				functions.clear();

				length = (arg == 0) ? len-i-3 : arg-i-3;
				ctxt = new Context(contents+i+3, length, funcTable, true);
				delete[] funcTable; // Context makes a copy.
				ctxt->setStrings(strings);
				strings.clear();
				vm->addContext(ctxt);
				contexts++;

				// A value of 0 is a special one
				// indicating the last header.
				if (arg == 0)
					i = len;
				else
					i = arg;
				continue;
			case 0xf2:		//string
				if (contents[i+1] == 0)
				{
					strings.push_back(str);
					str = std::string("");
				}
				else if (contents[i+2] == 0)
				{
					str += contents[i+1];
					strings.push_back(str);
					str = std::string("");
				}
				else
				{
					str += contents[i+1];
					str += contents[i+2];
				}
				break;
		}
		i += 3;
	}
	return contexts;
}
