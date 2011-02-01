#Fetus#
Fetus is a small assembly-like language, its bytecode compiler, and most importantly its VM.

###The language###
The Fetus language is assembly like, but enforces strict rules on syntax.

1. Each command has a separate line
2. Every line consists of 2 parts, a command and an argument.
3. The command is an ascii string, usually 3 or 4 characters.
4. The argument consist of a 4-byte hexadecimal number, 0000 in case no argument is needed.
5. call is used to call functions.
6. Commands interact with the stack, and have stack effects.
7. Functions expect a proper stack set up and clear the stack during their operation.
8. Any lines not following these rules are ignored.

This is the basis to get you started.

###The compiler###
The compiler is a very small and basic program, turning commands in their bytecode equivalents and stripping all unnecessary data. Generally code is first processed by the preprocessor, providing some advanced features, like strings, which are not natively supported by the language.

###The VM###
The VM is a general purpose VM designed to run Fetus bytecode, this means it is not restricted to running just Fetus code, but it can run any compatible bytecode. It is designed with both a stack and (abstracted) memory access in mind, completely number-based. One of the features of this VM is providing high-level functions such as file I/O and (eventually) sockets.

