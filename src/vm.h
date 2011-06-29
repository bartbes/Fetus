#include <string>
#include <vector>
#include <map>
#include <stack>

namespace Fetus
{
// Some constants:
// The quit "context number", used internally.
const unsigned int QUIT = (1<<16)-1;
// The nop "context number", signals a continue
// used internally.
const unsigned int NOP = QUIT-1;
// The maximum context index.
const unsigned int MAX_CONTEXT = NOP-1;

// Stack is a thing wrapper around std::stack.
class Stack
{
	private:
		std::stack<unsigned int> stack;

	public:
		void push(unsigned int val);
		// Pop needs to return the value!
		unsigned int pop();
		unsigned int top();
		bool empty();
		// Clear's useful to have.
		void clear();
};

// A context is kind of like a file.
// It has its own memory, but the stack
// remains during a context switch.
// There is one other thing you can influence
// namely the 'function pointer', which denotes
// a function location in the function table.
class Context
{
	private:
		// The memory associated with this context.
		std::map<unsigned int, unsigned int> mem;
		// The instruction pointer.
		unsigned int ip;
		// The function table.
		std::vector<unsigned int> functions;

		// The raw bytecode and its length.
		unsigned char *code;
		size_t codeLength;

		// The stack pointer, it's set whenever
		// this context is run.
		Stack *stack;

	protected:
		// The functions.
		void runFunction(unsigned int function);
		// The opcodes.
		unsigned int parse(unsigned char opcode, unsigned int arg);

	public:
		// The function pointer.
		unsigned int fp;

		// Run in this context for a bit
		// returns the next context to run
		unsigned int run(Stack* stack);

		// Do we own (and therefore delete)
		// this context as a vm?
		bool owned;

		// Constructor time!
		Context(std::string &code, unsigned int *funcTable, bool owned = true);
		Context(unsigned char *code, size_t length, unsigned int *funcTable, bool owned = true);

		// And a nice destructor
		~Context();
};

// The actual VM, has a stack
// and contexts.
class VM
{
	private:
		// The one and only stack for this VM
		// if we are to switch to threading
		// threads will have their own stacks.
		Stack stack;
		// All contexts belonging to this VM,
		// do not, I repeat, do NOT, share a
		// single context between VMs unless
		// you know exactly what you're doing.
		std::vector<Context*> contexts;
		
	public:
		// Add a context to the VM
		bool addContext(Context* context);

		// Run the main loop
		void run();

		// The destructor deletes all
		// owned contexts
		~VM();
};

} // Fetus
