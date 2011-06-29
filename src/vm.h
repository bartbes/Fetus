#include <string>
#include <vector>
#include <map>
#include <stack>

namespace Fetus
{

typedef std::stack<unsigned int> Stack;
const unsigned int QUIT = (1<<16)-1;
const unsigned int NOP = QUIT-1;
const unsigned int MAX_CONTEXT = NOP-1;

class Context
{
	private:
		std::map<unsigned int, unsigned int> mem;
		unsigned int ip;
		std::map<unsigned int, unsigned int> functions;

		unsigned char *code;
		size_t codeLength;

	protected:
		unsigned int parse(unsigned char opcode, unsigned int arg);

	public:
		unsigned int fp;

		// Run in this context for a bit
		// returns the next context to run
		unsigned int run(Stack* stack);

		// Do we own (and therefore delete)
		// this context as a vm?
		bool owned;

		// Constructor time!
		Context(std::string &code, bool owned = true);
		Context(unsigned char *code, size_t length, bool owned = true);

		// And a nice destructor
		~Context();
};

class VM
{
	private:
		Stack stack;
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
