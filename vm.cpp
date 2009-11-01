#include <iostream>
#include <fstream>
#include <cstdlib>
#include <cmath>

using namespace std;

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

template <class T> GrowFIFO<T>::GrowFIFO(int alloc, int extra)
	: size(0), allocsize(alloc), extra(extra)
{
	data = (T*) malloc(sizeof(T)*allocsize);
}

template <class T> GrowFIFO<T>::~GrowFIFO()
{
	free(data);
}

template <class T> T GrowFIFO<T>::operator[](int index)
{
	return data[index];
}

template <class T> void GrowFIFO<T>::set(int index, T value)
{
	data[index] = value;
}

template <class T> void GrowFIFO<T>::push(T entry)
{
	if (++size > allocsize)
	{
		data = (T*) realloc(data, sizeof(T)*(size+extra));
	}
	data[size-1] = entry;
}

template <class T> T GrowFIFO<T>::pop()
{
	if (size == 0)
		return 0;
	T temp = data[--size];
	if (allocsize - size > 2 * extra)
	{
		data = (T*) realloc(data, sizeof(T)*(size+extra));
	}
	return temp;
}

template <class T> T GrowFIFO<T>::top(int off)
{
	if (size == 0)
		return 0;
	return data[size-off-1];
}

template <class T> int GrowFIFO<T>::length()
{
	return size;
}

template <class T> void GrowFIFO<T>::clear()
{
	while(size > 0)
		pop();
}

template <class I, class V> class GrowHashMap
{
	private:
		GrowFIFO<I> indices;
		GrowFIFO<V> values;

	public:
		void insert(I index, V value);
		V get(I index);
		void set(I index, V value);
};

template <class I, class V> void GrowHashMap<I, V>::insert(I index, V value)
{
	indices.push(index);
	values.push(value);
}

template <class I, class V> V GrowHashMap<I, V>::get(I index)
{
	int l = indices.length();
	for (int i = 0; i < l; i++)
	{
		if (indices[i] == index)
			return values[i];
	}
	return 0;
}

template <class I, class V> void GrowHashMap<I, V>::set(I index, V value)
{
	int l = indices.length();
	for (int i = 0; i < l; i++)
	{
		if (indices[i] == index)
		{
			values.set(i, value);
			return;
		}
	}
	insert(index, value);
}

GrowFIFO<unsigned int> stack;
GrowHashMap<unsigned int, unsigned int> mem;
GrowFIFO<const char*> contexts;
int pos, curcontextn;
const char *curcontext;

void functions(unsigned int function)
{
	switch(function)
	{
		case 0xFFFF:
			cout<<stack.top() <<endl;
			break;
	}
}

void commands(unsigned int command, unsigned int arg)
{
	bool b;
	unsigned int r, p, t, v;
	switch(command)
	{
		case 0x01:			//get
			stack.push(mem.get(arg));
			break;
		case 0x02:			//set
			mem.set(arg, stack.top());
			break;
		case 0x03:			//put
			stack.push(arg);
			break;
		case 0x04:			//pop
			stack.pop();
			break;
		case 0x05:			//call
			functions(arg);
			break;
		case 0x06:			//clear
			stack.clear();
			break;
		case 0x07:			//getp
			stack.push(mem.get(stack.pop()));
			break;
		case 0x08:			//goto
			b = (stack.pop() > 0);
			stack.clear();
			if (b)
				pos = (arg-1) * 3;
			break;
		case 0x09:			//gotos
			p = stack.pop();
			b = (stack.pop() > 0);
			stack.clear();
			if (b)
				pos = (p-1) * 3;
			break;
		case 0x0a:			//add
			t = stack.pop();
			stack.push(stack.pop() + t);
			break;
		case 0x0b:			//sub
			t = stack.pop();
			stack.push(stack.pop() - t);
			break;
		case 0x0c:			//mult
			t = stack.pop();
			stack.push(stack.pop() * t);
			break;
		case 0x0d:			//div
			t = stack.pop();
			stack.push(stack.pop() / t);
			break;
		case 0x0e:			//pow
			t = stack.pop();
			stack.push(pow(stack.pop(), t));
			break;
		case 0x0f:			//root
			t = stack.pop();
			stack.push(pow(stack.pop(), 1.0/t));
			break;
		case 0x10:			//mod
			t = stack.pop();
			stack.push(stack.pop() % t);
			break;
		case 0x11:			//eq
			r = 0;
			if (stack.pop() == stack.pop())
				r = 1;
			stack.push(r);
			break;
		case 0x12:			//lt
			r = 0;
			if (stack.pop() < stack.pop())
				r = 1;
			stack.push(r);
			break;
		case 0x13:			//gt
			r = 0;
			if (stack.pop() > stack.pop())
				r = 1;
			stack.push(r);
			break;
		case 0x14:			//not
			r = 0;
			if (stack.pop() == 0)
				r = 1;
			stack.push(r);
			break;
		case 0x15:			//pos
			stack.push(pos/3);
			break;
		case 0x16:			//ascii
			break;
		case 0x17:			//num
			break;
		case 0x18:			//setp
			v = stack.pop();
			mem.set(stack.pop(), v);
			break;
		case 0x19:			//ctxt
			break;
		case 0x1a:			//ctxts
			break;
	}
}

void parse()
{
	pos = 0;
	curcontextn = 0;
	curcontext = contexts[0];
	while(curcontext[pos] != 0)
	{
		commands((unsigned int) curcontext[pos], (unsigned int) ((unsigned char) curcontext[pos+1] * 256 + (unsigned char) curcontext[pos+2]));
		pos = pos + 3;
	}
}

int main(int argc, const char **argv)
{
	if (argc < 2)
	{
		cout<<"Usage: " <<argv[0] <<" <file>\n";
		return 0;
	}
	ifstream f(argv[1]);
	f.seekg(0, ios::end);
	int l = f.tellg();
	f.seekg(0, ios::beg);
	char *buffer = new char[l];
	f.read(buffer, l);
	f.close();
	contexts.push(buffer);
	unsigned int n;
	for (int i = 2; i < argc; i++)
	{
		sscanf(argv[i], "%u", &n);
		stack.push(n);
	}
	parse();
	delete buffer;
}
