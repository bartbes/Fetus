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

// A file descriptor.
class Handle
{
public:
	bool open;

	virtual char read() = 0;
	virtual void write(char ch) = 0;
};

class FileHandle : public Handle
{
private:
	FILE *file;
public:
	char read();
	void write(char ch);

	FileHandle(const char *filename, const char *mode);
	~FileHandle();
};

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

// Forward declaration of the VM class.
class VM;

// A context is kind of like a file.
// It has its own memory, but the stack
// remains during a context switch.
class Context
{
	private:
		// The memory associated with this context.
		std::map<unsigned int, unsigned int> mem;
		// The instruction pointer.
		unsigned int ip;
		// The function table.
		std::vector<unsigned int> functions;
		// Handles.
		std::vector<Handle*> handles;

		// The raw bytecode and its length.
		unsigned char *code;
		size_t codeLength;

		// The stack pointer, it's set whenever
		// this context is run.
		Stack *stack;
		// A call stack.
		Stack callStack;

	protected:
		// The functions.
		void runFunction(unsigned int function);
		// The opcodes.
		unsigned int parse(unsigned char opcode, unsigned int arg);

	public:
		// Run in this context for a bit
		// returns the next context to run
		unsigned int run(Stack* stack);

		// Do we own (and therefore delete)
		// this context as a vm?
		bool owned;

		// Our context number.
		unsigned int n;

		// Constructor time!
		Context(std::string &code, unsigned int *funcTable, bool owned = true);
		Context(const unsigned char *code, size_t length, unsigned int *funcTable, bool owned = true);

		// And a nice destructor
		~Context();

		// Become good friends with the VM. ;)
		friend class VM;
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

// And we'll add a class that handles
// parsing the bytecode, nice touch.
class Parser
{
	private:
		VM *vm;

	public:
		Parser(VM* vm);
		int parseBlob(std::string &contents);
		int parseBlob(const char *contents, size_t len);
		int parseBlob(const unsigned char *contents, size_t len);
};

} // Fetus
