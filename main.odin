package main

import "base:intrinsics"
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


	code: [dynamic]u8
	append_elems(
		&code,
		op(.INVALID),
		expand_values(op_lit('x')),
		op(.PUTCHAR),
		expand_values(op_lit('d')),
		op(.PUSH_WORD),
		op(.PEEK_WORD),
		op(.PUTCHAR),
		op(.PEEK_WORD),
		op(.PUTCHAR),
		op(.PEEK_WORD),
		op(.PUTCHAR),
		op(.PEEK_WORD),
		op(.PUTCHAR),
		op(.POP_WORD),
		op(.EXIT),
	)

	code_base = raw_data(code[:])
	code_register = code_base

	code_len = len(code)
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
		if (stack_register == stack_base) do os.exit(1)

		println("current opcode:", cast(op_code)code_register[0])
		switch cast(op_code)code_register[0] {
		case .NOP:
			{println("nop")}

		case .ADD:
			{println("add")
				panic("TODO")
				// n1 := stack_pop()
				// n2 := stack_pop()
				// stack_push(n1 + n2)
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
		case .LIT_WORD:
			{println("lit")
				res: Stack_cell
				for i in 0 ..< 8 {
					code_advance()
					res.sc8[7 - i] = code_register[0]
				}
				append(&reg_array, res.sc)
			}

		case .PEEK_WORD:
			{println("peek")
				top := stack_register[0]
				append(&reg_array, top)
			}
		case .POP_WORD:
			{println("pop")
				stack_pop :: #force_inline proc() -> uint {
					assert_contextless(stack_register >= stack_base)
					stack_register = &stack_register[-1]
					return stack_register[1]
				}

				top := stack_pop()
				append(&reg_array, top)
			}

		case .PUSH_WORD:
			{println("push")
				stack_push :: #force_inline proc(data: uint) {
					assert_contextless(&stack_register[-stack_size] < stack_base)
					stack_register = &stack_register[1]
					stack_register[0] = data
				}

				res, ok := pop_safe(&reg_array)
				if !ok do panic("tried to pop while no values in register array")

				stack_push(res)
			}

		case .PUTCHAR:
			{println("putchar")
				_top, ok := pop_safe(&reg_array)
				if !ok do panic("putchar tried to pop from empty reg_array")
				top := transmute(Stack_cell)_top
				// print the lowest byte
				fmt.printf("%c", top.sc8[0])
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
			// final := stack_pop()
			// println("Finished with", final)
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
	//::stack_less, register_less
	INVALID = 0,
	NOP = 1,
	EXIT = 255, // INFO: always returns the value on top of the stack

	//::function-like,
	ADD = 2,
	SUB,
	PUTCHAR, // read byte from top of stack and print it
	LIT_WORD, // pushes a literal to reg_array

	//::the only things allowed to touch the stack
	PUSH_WORD,
	POP_WORD,
	PEEK_WORD,


	// TODO: (5)

	// CALL,
	// DEREF_LOCAL, //assumes index into stack_base
	// JMP_LOCAL, // assumes index into code_base
}


op :: #force_inline proc($code: op_code) -> u8 {
	return u8(code)
}

op_lit :: proc($n: $T) -> [9]u8 where intrinsics.type_is_numeric(T) {
	res: [9]u8
	res[0] = op(.LIT_WORD)
	nums := op_num(n)
	for i in 1 ..< 9 {res[i] = nums[8 - i]}
	println(res)
	return res
}

op_num :: proc($n: $T) -> [8]u8 where intrinsics.type_is_numeric(T) {
	return transmute([8]u8)cast(u64)n
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

//@arguments register array manipulations
reg_array: [dynamic]uint
