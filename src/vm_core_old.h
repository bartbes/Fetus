#ifndef VM_CORE_H
#define VM_CORE_H
template <class T> class GrowFIFO
{
	private:
		int size;
		int allocsize;
		int extra;
		T *data;

	public:
		GrowFIFO(int alloc = 10, int extra = 10);
		~GrowFIFO();
		T operator[](int index);
		void push(T entry);
		T pop();
		T remove(int index);
		int length();
		T top(int off = 0);
		void set(int index, T value);
		void clear();
};

template <class I, class V> class GrowHashMap
{
	private:
		GrowFIFO<I> indices;
		GrowFIFO<V> values;

	public:
		void insert(I index, V value);
		V get(I index);
		void set(I index, V value);
		unsigned int length();
};

struct fd
{
	int t;
	bool open;
	int sock;
	FILE *file;
};

extern GrowHashMap<unsigned int, char*> contexts;
extern GrowFIFO<unsigned int> stack;

extern void parse();
#endif //VM_CORE_H
