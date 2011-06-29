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
	: ip(0), owned(owned)
{
	codeLength = code.length();
	this->code = new unsigned char[codeLength];
	memcpy(this->code, code.c_str(), codeLength);
	// The first 'function' is always the start.
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
Context::Context(unsigned char *code, size_t length, unsigned int *funcTable, bool owned)
	: ip(0), codeLength(length), owned(owned)
{
	this->code = new unsigned char[codeLength];
	memcpy(this->code, code, codeLength);
	// The first 'function' is always the start.
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

// The Fetus functions, in a nice big switch-case
void Context::runFunction(unsigned int function)
{
	switch(function)
	{
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
	while(contexts.size() > curContext)
	{
		// The return value is the next context.
		curContext = contexts[curContext]->run(&stack);
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
