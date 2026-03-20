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

	// #stack setup
	stack_register = raw_data(global_stack[:])
	stack_base = &global_stack[0]
	global_stack[0] = 7 // wtf
	stack_register = &stack_register[1]

	// #code setup
	// odinfmt: disable 
	code := [?]u8 {
		// .start
	0	= op(.INVALID),
	1       = op(.PUSH_WORD),
	2 ..< 9 = 0,
	9       = 10,
	10	= op(.NOP),
	11	= op(.PUSH_WORD),
	12..<19 = 0,
	19	= 11,
	20	= op(.ADD),
	21	= op(.EXIT),
	}
	println(code)
	// odinfmt: enable
	code_base = raw_data(code[:])
	code_register = code_base

	when ODIN_DEBUG {code_len = len(code)} else {
		// remove bounds checking code code array
		code_len = ~uint(0)
	}

	// #runtime
	vm_loop()
}


// TODO: (7)
// temp_register: struct #raw_union {
// 	t:   uint,
// 	t32: [2]u32,
// 	t16: [4]u16,
// 	t8:  [8]u8,
// }


vm_loop :: proc() {
	for iter in 0 ..< 255 {

		// INFO: each code point is NOT responsible for advancing the op_code_point
		code_advance()
		assert(stack_register != stack_base)

		println("current opcode:", cast(op_code)code_register[0])
		switch cast(op_code)code_register[0] {
		case .NOP:
			{println("nop")}

		case .ADD:
			{println("add")
				n1 := stack_pop()
				n2 := stack_pop()
				stack_push(n1 + n2)
			}

		case .SUB:
			{println("sub")
				panic("TODO")
				// n1 := stack_pop()
				// println(n1)
				// n2 := stack_pop()
				// println(n2)
				// stack_push(n1 - n2)
			}

		//  TODO: (2)
		case .POP_WORD:
			{println("pop")
				panic("TODO")
				// top := stack_pop()
			}

		case .PUSH_WORD:
			{println("push")
				res: Stack_cell
				for i in 0 ..< 8 {
					code_advance()
					res.sc8[7 - i] = code_register[0]
				}
				stack_push(res.sc)
			}

		case .PUTCHAR:
			{println("putchar")
				panic("TODO")
				// fmt.printf("%c", stack_register[0])
			}

		// case .DEREF_LOCAL:
		// 	{println("Dereferencing")
		// 	val := stack_pop()
		// 	assert(val < STACK_SIZE)
		// 	stack_push(stack_base[val])}
		// case .JMP_LOCAL:
		// 	{jump_loc := stack_pop()
		// 	code_register = cast(uint)jump_loc
		// 	println("local jump to", jump_loc)}


		case .EXIT:
			final := stack_pop()
			println("Finished with", final)
			return
		case .INVALID:
			panic("invalid memory")
		case:
			fmt.panicf("Unknown opcode %v, iter %v", code_register[0], iter)
		}

	}
}

// @op_codes
// INFO: each code point is a u8, so hardcap of 255 code points
// must avoid code_point specializations at all costs (such as PUSH_I32)

op_code :: enum u8 {
	//:: stackless, registerless op
	INVALID = 0,
	NOP = 1,
	EXIT = 255, // INFO: always returns the value on top of the stack

	//:: using stack, registerless op
	ADD = 2,
	SUB,
	PUTCHAR, // read byte from top of stack and print it
	PUSH_WORD,
	POP_WORD,

	// TODO: (5)

	// CALL,
	// DEREF_LOCAL, //assumes index into stack_base
	// JMP_LOCAL, // assumes index into code_base
}

op_uint :: #force_inline proc($num: uint) -> [8]u8 {
	return cast(u8)num
}

op :: #force_inline proc($code: op_code) -> u8 {
	return u8(code)
}


// @code register manipulations
code_len: uint
code_register: [^]u8
code_base: [^]u8

// TODO: (8) figure out if I need code_push
//
// code_push :: #force_inline proc(data: u8, loc := #caller_location) {
// 	// INFO: in release mode, code_len == ~(0), no bounds checking should occur
//
// 	assert_contextless(code_register < &code_base[code_len], loc = loc)
//
// 	_code_advance()
// 	code_register[0] = data
// }
code_advance :: #force_inline proc(loc := #caller_location) {
	assert_contextless(code_register < &code_base[code_len], loc = loc)

	_code_advance()
}

// code_pop :: #force_inline proc(loc := #caller_location) -> u8 {
// 	assert_contextless(code_register > code_base, loc = loc)
//
// 	_code_retreat()
// 	return code_register[1]
// }

code_retreat :: #force_inline proc(loc := #caller_location) {
	assert_contextless(code_register > code_base, loc = loc)

	_code_retreat()
}

// @@code register internals
_code_advance :: #force_inline proc() {code_register = &code_register[1]}
_code_retreat :: #force_inline proc() {code_register = &code_register[-1]}


// @stack register manipulations
// INFO: stack is pointer alligned, each "cell" is exactly 8 bytes

STACK_SIZE :: 255
global_stack: [STACK_SIZE]uint

stack_register: [^]uint
stack_base: [^]uint
stack_size: int = STACK_SIZE

Stack_cell :: struct #raw_union {
	sc:   uint,
	sc32: [2]u32,
	sc16: [4]u16,
	sc8:  [8]u8,
}

stack_push :: #force_inline proc(data: uint, loc := #caller_location) {
	assert_contextless(&stack_register[-stack_size] < stack_base, loc = loc)
	stack_register = &stack_register[1]
	stack_register[0] = data
}

stack_pop :: #force_inline proc(loc := #caller_location) -> uint {
	assert_contextless(stack_register >= stack_base, loc = loc)
	stack_register = &stack_register[-1]
	return stack_register[1]
}
