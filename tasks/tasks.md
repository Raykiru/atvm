<!-- Sequencial todo's are dependant on the previous todo -->
Tasks = 16
# (1) DONE: figure out how to arrange the stack
# (3) DONE: figure out what size to make the each code point be
# (2) DONE: figure out push and putting things from code onto the stack
# (4) DONE: write xddddd program

- (5) TODO: add these features
```main.odin
	// CALL,
	// DEREF_LOCAL, //assumes index into stack_base
	// JMP_LOCAL, // assumes index into code_base
```
- (14) TODO: add boolean operations
- (15) TODO: write a program with conditional execution


- (6) TODO: create a todo plugin/system for vim

# (7) DONE: figure out if I need a temp register
	- INFO ```	instead of temp register, temp register array. it's used for getting data from
				stack to other functions or function-like intructions ```

- (8) TODO: figure out if I need code_push

# (9) DONE: figure out what pop should do, and why
	- INFO ```pop takes the top item of the stack and puts in register array ```

# (10) DONE: make some better way to write bytecode then with array literals
- (12) TODO: make a simple assembler

# (11) DONE: implement argument array 

# (13) DONE: add read,write instructions
- (17) TODO: add read and write for any pointer, not just offesets

# (16) DONE: encapsulate interpetor state


