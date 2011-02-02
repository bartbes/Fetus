#include <iostream>
#include <fstream>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <sstream>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>

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
GrowHashMap<unsigned int, unsigned int> posses;
GrowHashMap<unsigned int, fd> handles;
unsigned int pos, curcontextn;
const char *curcontext;
char *storedip = NULL;
unsigned int storedport;

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

char *extractmem(unsigned int addr)
{
	unsigned int l = 0;
	while (mem.get(addr+l) != 0)
	{
		++l;
	}
	char *buffer = new char[l+1];
	for (unsigned int i = 0; i < l; i++)
	{
		buffer[i] = (char) mem.get(i+addr);
	}
	buffer[l] = 0;
	return buffer;
}

void insertstack(const char *text)
{
	int l = strlen(text);
	for (int i = 0; i < l; i++)
	{
		stack.push(text[i]);
	}
	stack.push(0);
}

void insertmem(unsigned int addr, const char *text)
{
	int l = strlen(text);
	for (int i = 0; i < l; i++)
	{
		mem.set(addr+i, text[i]);
	}
	mem.set(addr+l, 0);
}

void functions(unsigned int function)
{
	unsigned int s, e, p, m, id;
	unsigned int a, b, c, d;
	char *buffer, *ipbuffer;
	std::string strbuffer;
	std::stringstream strstream;
	const char *mode;
	fd file;
	switch(function)
	{
		case 0x0001:		//output
			buffer = extractstack();
			cout<<buffer;
			delete[] buffer;
			break;
		case 0x0002:		//input
			p = stack[0];
			s = stack[1];
			stack.clear();
			getline(cin, strbuffer);
			strbuffer = strbuffer.substr(s);
			insertmem(p, strbuffer.c_str());
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
			{
				delete[] buffer;
				return;
			}
			file.t = 0;
			file.file = fopen(buffer, mode);
			file.open = true;
			delete[] buffer;
			p = handles.length();
			handles.insert(p, file);
			stack.push(p);
			break;
		case 0x0004:		//close
			p = stack.pop();
			stack.clear();
			file = handles.get(p);
			if (!file.open)
				return;
			switch (file.t)
			{
				case 0:
					fclose(file.file);
					break;
				case 1:
				case 2:
					close(file.sock);
					break;
			}
			file.open = false;
			break;
		case 0x0005:		//read
			id = stack[0];
			p = stack[1];
			s = stack[2];
			stack.clear();
			file = handles.get(id);
			if (!file.open)
				return;
			buffer = new char[s+1];
			memset(buffer, 0, s+1);
			switch (file.t)
			{
				case 0:
					fread(buffer, 1, s, file.file);
					buffer[s] = 0;
					insertmem(p, buffer);
					break;
				case 1:
				case 2:
					recv(file.sock, buffer, s, 0);
					buffer[s] = 0;
					insertmem(p, buffer);
					break;
			}
			delete[] buffer;
			break;
		case 0x0006:		//write
			p = stack[0];
			buffer = extractstack(1);
			stack.clear();
			file = handles.get(p);
			if (!file.open)
				return;
			switch (file.t)
			{
				case 0:
					fprintf(file.file, "%s", buffer);
					fflush(file.file);
					break;
				case 1:
					send(file.sock, buffer, strlen(buffer), 0);
					break;
			}
			delete[] buffer;
			break;
		case 0x0007:		//tcp
			ipbuffer = extractstack(0);
			p = stack[strlen(ipbuffer)+1];
			stack.clear();
			s = socket(AF_INET, SOCK_STREAM, 0);
			file.t = 1;
			file.sock = s;
			{
				addrinfo hints, *servinfo;
				memset(&hints, 0, sizeof(addrinfo));
				hints.ai_family = AF_UNSPEC;
				hints.ai_socktype = SOCK_STREAM;
				char port[6];
				sprintf(port, "%d", p);
				if (getaddrinfo(ipbuffer, port, &hints, &servinfo) != 0)
				{
					delete[] ipbuffer;
					id = handles.length();
					file.open = false;
					handles.insert(id, file);
					stack.push(id);
					return;
				}
				file.open = (file.sock != -1 && connect(file.sock, servinfo->ai_addr, servinfo->ai_addrlen) != -1);
				freeaddrinfo(servinfo);
			}
			id = handles.length();
			handles.insert(id, file);
			stack.push(id);
			delete[] ipbuffer;
			break;
		case 0x0008:		//udp
			stack.clear();
			s = socket(AF_INET6, SOCK_DGRAM, 0);
			file.t = 2;
			file.sock = s;
			file.open = (s != -1);
			a = 0;
			if (file.open)
				setsockopt(s, IPPROTO_IPV6, IPV6_V6ONLY, &a, sizeof(a));
			p = handles.length();
			handles.insert(p, file);
			stack.push(p);
			break;
		case 0x0009:		//createip
			p = stack[0];
			a = stack[1];
			b = stack[2];
			c = stack[3];
			d = stack[4];
			strstream <<a <<"." <<b <<"." <<c <<"." <<d;
			strbuffer = strstream.str();
			insertmem(p, strbuffer.c_str());
			stack.clear();
			stack.push(strbuffer.length());
			break;
		case 0x000A:		//sendto
			id = stack[0];
			buffer = extractstack(1);
			ipbuffer = extractstack(strlen(buffer)+2);
			p = stack[strlen(buffer)+strlen(ipbuffer)+3];
			stack.clear();
			file = handles.get(id);
			if (!file.open || file.t != 2)
				return;
			{
				addrinfo hints, *servinfo;
				memset(&hints, 0, sizeof(addrinfo));
				hints.ai_family = AF_UNSPEC;
				hints.ai_socktype = SOCK_STREAM;
				char port[6];
				sprintf(port, "%d", p);
				if (getaddrinfo(ipbuffer, port, &hints, &servinfo) != 0)
				{
					delete[] ipbuffer;
					id = handles.length();
					file.open = false;
					handles.insert(id, file);
					stack.push(id);
					return;
				}
				sendto(file.sock, buffer, strlen(buffer), 0, servinfo->ai_addr, servinfo->ai_addrlen);
				freeaddrinfo(servinfo);
			}
			delete[] buffer;
			delete[] ipbuffer;
			break;
		case 0x000B:		//storeaddress
			if (storedip)
				delete[] storedip;
			storedip = extractstack();
			storedport = stack[strlen(storedip)];
			stack.clear();
			break;
		case 0x000C:		//getaddress
			stack.clear();
			insertstack(storedip);
			stack.push(storedport);
			break;
		case 0x000D:		//createcontext
			e = (stack.pop()+1)*3;
			s = (stack.pop())*3;
			stack.clear();
			buffer = new char[e-s];
			memcpy(buffer, contexts.get(0)+s, e-s);
			p = contexts.length();
			contexts.insert(p, buffer);
			stack.push(p);
			break;
		case 0x000E:		//stacktomem
			p = stack[0];
			buffer = extractstack(1);
			stack.clear();
			insertmem(p, buffer);
			delete[] buffer;
			break;
		case 0x000F:		//memtostack
			p = stack.pop();
			buffer = extractmem(p);
			insertstack(buffer);
			delete[] buffer;
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
	char *buffer;
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
			stack.push((unsigned int) pow((double) stack.pop(), (double) t));
			break;
		case 0x0f:			//root
			t = stack.pop();
			stack.push((unsigned int) pow(stack.pop(), 1.0/t));
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
			buffer = new char[16];
			sprintf(buffer, "%d", stack.top());
			insertmem(arg, buffer);
			delete[] buffer;
			break;
		case 0x17:			//num
			buffer = extractmem(arg);
			sscanf(buffer, "%d", &t);
			stack.push(t);
			delete[] buffer;
			break;
		case 0x18:			//setp
			v = stack.pop();
			mem.set(stack.pop(), v);
			break;
		case 0x19:			//ctxt
			posses.set(curcontextn, pos);
			oldcontext = curcontextn;
			curcontextn = arg;
			curcontext = contexts.get(curcontextn);
			pos = posses.get(curcontextn);
			stack.clear();
			stack.push(oldcontext);
			break;
		case 0x1a:			//ctxts
			posses.set(curcontextn, pos);
			oldcontext = curcontextn;
			curcontextn = stack.pop();
			curcontext = contexts.get(curcontextn);
			pos = posses.get(curcontextn);
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
