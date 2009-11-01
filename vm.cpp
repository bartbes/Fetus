#include <iostream>
#include <fstream>
#include <cstdlib>
#include <cstring>
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
		unsigned int length();
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
	V temp;
	memset(&temp, 0, sizeof(V));
	return temp;
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

template <class I, class V> unsigned int GrowHashMap<I, V>::length()
{
	return indices.length();
}

struct fd
{
	int t;
	bool open;
	int sock;
	FILE *file;
};

GrowFIFO<unsigned int> stack;
GrowHashMap<unsigned int, unsigned int> mem;
GrowHashMap<unsigned int, char*> contexts;
GrowHashMap<unsigned int, fd> handles;
unsigned int pos, curcontextn;
const char *curcontext;

char *extractstack(int off = 0)
{
	int l;
	for (int i = off; i < stack.length(); i++)
	{
		if (stack[i] == 0)
		{
			l = i-off;
			break;
		}
	}
	char *buffer = new char[l+1];
	for (int i = 0; i < l; i++)
	{
		buffer[i] = (char) stack[i+off];
	}
	buffer[l] = 0;
	return buffer;
}

void functions(unsigned int function)
{
	unsigned int s, e, p, m;
	char *buffer;
	const char *mode;
	fd file;
	switch(function)
	{
		case 0x0001:		//output
			buffer = extractstack();
			cout<<buffer;
			delete[] buffer;
			break;
		case 0x0003:		//fileopen
			buffer = extractstack();
			m = stack[strlen(buffer)+1];
			stack.clear();
			if (m == 1)
				mode = "r";
			else if (m == 2)
				mode = "w";
			else if (m == 3)
				mode = "a";
			else
				return;
			file.t = 0;
			file.file = fopen(buffer, mode);
			file.open = true;
			delete[] buffer;
			p = handles.length();
			handles.insert(p, file);
			stack.push(p);
			break;
		case 0x0004:		//fileclose
			p = stack.pop();
			stack.clear();
			file = handles.get(p);
			if (!file.open)
				return;
			if (file.t == 0)
				fclose(file.file);
			file.open = false;
			break;
		case 0x0006:		//write
			p = stack[0];
			buffer = extractstack(1);
			stack.clear();
			file = handles.get(p);
			if (!file.open || file.t != 0)
				return;
			fprintf(file.file, "%s", buffer);
			fflush(file.file);
			delete[] buffer;
			break;
		case 0x000D:		//createcontext
			e = (stack.pop()+1)*3;
			s = (stack.pop()-1)*3;
			stack.clear();
			buffer = new char[e-s];
			strncpy(buffer, contexts.get(0), e-s);
			p = contexts.length();
			contexts.insert(p, buffer);
			stack.push(p);
			break;
		case 0xFFFF:		//debug
			cout<<stack.top() <<endl;
			break;
	}
}

void commands(unsigned int command, unsigned int arg)
{
	bool b;
	unsigned int r, p, t, v, oldcontext;
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
			oldcontext = curcontextn;
			curcontextn = arg;
			curcontext = contexts.get(curcontextn);
			stack.clear();
			stack.push(oldcontext);
			break;
		case 0x1a:			//ctxts
			oldcontext = curcontextn;
			curcontextn = stack.pop();
			curcontext = contexts.get(curcontextn);
			stack.clear();
			stack.push(oldcontext);
			break;
	}
}

void parse()
{
	pos = 0;
	curcontextn = 0;
	curcontext = contexts.get(0);
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
	contexts.insert(0, buffer);
	unsigned int n;
	for (int i = 2; i < argc; i++)
	{
		sscanf(argv[i], "%u", &n);
		stack.push(n);
	}
	parse();
	while(contexts.length() > 1)
	{
		delete[] contexts.get(1);
	}
	delete[] contexts.get(0);
}
