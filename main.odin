package main

import "core:fmt"
import "core:os"
when ODIN_DEBUG {
	println :: fmt.println
	printf :: fmt.printfln
} else {
	println :: proc(_: ..any) {}
	printf :: proc(_: ..any) {}
}

IMPLEMENTED :: false

main :: proc() {
	when IMPLEMENTED {
		if len(os.args) < 2 {panic("Expected a path")}
		path := os.args[1]

		data, err := os.read_entire_file_from_path(path, context.allocator)
		if err != nil {
			fmt.printfln("Error: %v\nFailed to open file (%v)", err, path)
			return
		}

		// fmt.println(cast(string)data)
	}

	stack_register = raw_data(global_stack[:])
	stack_base = &global_stack[0]
	global_stack[0] = 7
	stack_register = &stack_register[1]

	code := [?]u8 {
		// .start
		// TODO: write xddddd program
	}
	code_register = 0
	code_base = raw_data(code[:])
	when ODIN_DEBUG {code_len = len(code)} else {
		// remove bounds checking code code array
		code_len = ~uint(0)
	}
	// // TODO: figure out what size to make the each code point be

	// fmt.println(size_of(u64))
	// if true do return
	vm_loop()
}

STACK_SIZE :: 255

temp_register: struct #raw_union {
	t:   uint,
	t32: [2]u32,
	t16: [4]u16,
	t8:  [8]u8,
}
global_stack: [STACK_SIZE]u8

code_register: uint
code_len: uint
code_base: [^]u8

stack_register: [^]u8
stack_base: [^]u8

// OP_CODES
op_code :: enum u8 {
	//:: stackless, registerless op
	INVALID = 0,
	NOP = 1,
	EXIT = 255,

	//:: using stack, registerless op
	ADD = 2,
	SUB,
	PUTCHAR,

	//:: using stack and register
	PUSH,
	POP,

	// CALL,
	DEREF_LOCAL, //assumes index into stack_base
	JMP_LOCAL, // assumes index into code_base
}

vm_loop :: proc() {
	for iter in 0 ..< 10 {
		op_code_point := cast(op_code)code_base[code_register]

		switch op_code_point {
		case .NOP:
			println("nop")

		case .ADD:
			println("add")
			n1 := stack_pop()
			println(n1)
			n2 := stack_pop()
			println(n2)
			stack_push(n1 + n2)
		case .SUB:
			println("sub")
			n1 := stack_pop()
			println(n1)
			n2 := stack_pop()
			println(n2)
			stack_push(n1 - n2)
		case .POP:
			println("pop")
			temp_register.t = 0
			temp_register.t8[3] = stack_pop()

		case .PUSH:
			code_next()
			println("push ", code_base[code_register])
			stack_push(code_base[code_register])

		case .DEREF_LOCAL:
			println("Dereferencing")
			val := stack_pop()
			assert(val < STACK_SIZE)
			stack_push(stack_base[val])

		case .JMP_LOCAL:
			jump_loc := stack_pop()
			code_register = cast(uint)jump_loc
			println("local jump to", jump_loc)
		case .PUTCHAR:
			val := stack_pop()
			fmt.printf("%c", val)


		case .EXIT:
			return
		case .INVALID:
			panic("invalid memory")
		case:
			fmt.panicf("Unknown opcode %v, iter %v", op_code_point, iter)
		}

		code_next()
		assert(stack_register != stack_base)
	}
}

code_push :: #force_inline proc(data: u8, loc := #caller_location) {
	// INFO: in release mode, code_len == ~(0), no bounds checking should occur
	assert_contextless(code_register < code_len)
	code_register += 1
	code_base[code_register] = data
}
code_pop :: #force_inline proc(loc := #caller_location) -> u8 {
	code_register -= 1
	return code_base[code_register + 1]
}
code_next :: #force_inline proc(loc := #caller_location) {
	code_register += 1
}

stack_push :: #force_inline proc(data: u8, loc := #caller_location) {
	assert(&stack_register[-STACK_SIZE] < stack_base, loc = loc)
	stack_register = &stack_register[1]
	stack_register[0] = data
}

stack_pop :: #force_inline proc(loc := #caller_location) -> u8 {
	assert(stack_register >= stack_base)
	stack_register = &stack_register[-1]
	return stack_register[1]
}
