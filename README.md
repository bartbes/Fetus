#Fetus#
Fetus is a VM for running Fetus bytecode, this is accompanied by the Fetus language, Fetoid, and their compilers. There is even an experimental, and probably horribly broken, Brainfuck compiler.

###The VM###
The VM is a general purpose VM designed to run Fetus bytecode, this means it is not restricted to running just Fetus code, but it can run any compatible bytecode. It is designed with both a stack and (abstracted) memory access in mind, completely number-based. One of the features of this VM is providing high-level functions such as file I/O and sockets.

###Fetus language###
The Fetus language is assembly like, but enforces strict rules on syntax.

1. Each command has a separate line
2. Every line consists of 2 parts, a command and an argument.
3. The command is an ascii string, usually 3 or 4 characters.
4. The argument consist of a 4-byte hexadecimal number, 0000 in case no argument is needed.
5. call is used to call functions.
6. Commands interact with the stack, and have stack effects.
7. Functions expect a proper stack set up and clear the stack during their operation.
8. Any lines not following these rules are ignored.

These are the basics to get you started.

The compiler is a very small and basic program, turning commands in their bytecode equivalents and stripping all unnecessary data. Generally code is first processed by the preprocessor, providing some advanced features, like strings, which are not natively supported by the language.

###Fetoid###
Fetoid is a language that you can actually consider high-level, though it's primary unit is still numbers, and, of course, the underlying memory model stays the same. Coding in Fetoid is radically different from coding in the Fetus language.

More documentation will hopefully be added later, but currently the language is too much in flux for documentation to be written.

###Brainfuck###
A simple brainfuck compiler is included, it *should* all work, but it has not been tested thoroughly. Because brainfuck has a very loose specification, it is very possible that existing (advanced) brainfuck code won't work.

###Executables###
On first run, 'make all' should be executed to compile the VM, and the tools for the supported languages.

brainfuck - A script that compiles and runs a Brainfuck program.
brainfuck_c - The Brainfuck compiler.
fetoid - A script that compiles and runs a Fetoid program.
fetoid_c - The Fetoid compiler.
fetus - A script that preprocesses, compiles and runs a Fetus language program.
fetus_c - The Fetus language compiler.
fetus_pp - The Fetus language preprocessor.
fetus_vm - The Fetus VM

