package main

import "base:intrinsics"
import "core:fmt"
import "core:mem"
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
	interp: Interpretor


	interp.stack_register = raw_data(global_stack[:])
	interp.stack_base = &global_stack[0]
	global_stack[0] = 7 // wtf
	interp.stack_register = &interp.stack_register[1]
	interp.stack_size = STACK_SIZE

	// #code setup


	code: [dynamic]u8
	// TODO:
	append_elem(&code, op(.INVALID))
	append_elem(&code, op(.TOP_ADDR))
	append_elem(&code, op(.EXIT))

	interp.code_base = raw_data(code[:])
	interp.code_register = interp.code_base

	interp.code_len = len(code)
	// #runtime
	vm_loop(&interp)
}


vm_loop :: proc(itp: ^Interpretor) {
	for iter in 0 ..< 255 {

		// INFO: each code point is NOT responsible for advancing the op_code_point
		code_advance(itp)
		assert(itp.stack_register > itp.stack_base)

		println("current opcode:", cast(op_code)itp.code_register[0])
		switch cast(op_code)itp.code_register[0] {
		case .NOP:
			{println("nop")}

		case .ADD:
			{println("add")
				// INFO: takes 2 arguments from reg_array, adds them, clears the array
				// and puts the result back
				n1, n2: uint
				ok: bool
				n1, ok = pop_safe(&itp.reg_array)
				if !ok do panic("not enough arguments for add")
				n2, ok = pop_safe(&itp.reg_array)
				if !ok do panic("not enough arguments for add")
				append(&itp.reg_array, n1 + n2)
			}

		case .SUB:
			{println("sub")
				n1, n2: uint
				ok: bool
				n1, ok = pop_safe(&itp.reg_array)
				if !ok do panic("not enough arguments for add")
				n2, ok = pop_safe(&itp.reg_array)
				if !ok do panic("not enough arguments for add")
				append(&itp.reg_array, n1 - n2)
			}
		case .LIT_WORD:
			{println("lit")
				res: Stack_cell
				for i in 0 ..< 8 {
					code_advance(itp)
					res.sc8[7 - i] = itp.code_register[0]
				}
				append(&itp.reg_array, res.sc)
			}

		case .TOP_ADDR:
			{println("top_addr")
				mem_offet := mem.ptr_sub(itp.stack_register, itp.stack_base)
				fmt.assertf(
					itp.stack_base[mem_offet:] == itp.stack_register,
					"Stack pointer + mem_offset should point to the same thing as stack_register\n instead %v %v %v",
					mem_offet,
					itp.stack_base,
					itp.code_base,
				)
				append_elem(&itp.reg_array, uint(mem_offet))
			}
		case .READ_LOCAL:
			{println("read_local")
				dest, ok := pop_safe(&itp.reg_array)
				if !ok do panic("expected word at top of register array for read_local")
				if len(itp.reg_array) > 0 do panic("expected only 1 argument for read_local")

				// INFO: be carefull with dest
				fmt.assertf(
					dest <= cast(uint)itp.stack_size,
					"dest offset must not be greater then the stack size",
				)
				w := itp.stack_base[dest]

				append(&itp.reg_array, w)
			}
		case .PEEK_WORD:
			{println("peek")
				top := itp.stack_register[0]
				append(&itp.reg_array, top)
			}
		case .POP_WORD:
			{println("pop")
				stack_pop :: #force_inline proc(itp: ^Interpretor) -> uint {
					assert_contextless(itp.stack_register >= itp.stack_base)
					itp.stack_register = &itp.stack_register[-1]
					return itp.stack_register[1]
				}

				top := stack_pop(itp)
				append(&itp.reg_array, top)
			}

		case .WRITE_LOCAL:
			{println("write_local")
				w, ok := pop_safe(&itp.reg_array)
				if !ok do panic("expected word at top of register array for write_local")
				dest, ok2 := pop_safe(&itp.reg_array)
				if !ok2 do panic("expected another word(dest) at top of register array for write_local")
				if len(itp.reg_array) > 0 do panic("expected exactly 2 arguments for write_local")

				// INFO: be carefull with dest
				fmt.assertf(
					dest <= cast(uint)itp.stack_size,
					"dest offset must not be greater then the stack size",
				)
				itp.stack_base[dest] = w
			}

		case .PUSH_WORD:
			{println("push")
				stack_push :: #force_inline proc(itp: ^Interpretor, data: uint) {
					assert_contextless(&itp.stack_register[-itp.stack_size] < itp.stack_base)
					itp.stack_register = &itp.stack_register[1]
					itp.stack_register[0] = data
				}

				res, ok := pop_safe(&itp.reg_array)
				if !ok do panic("tried to pop while no values in register array")

				stack_push(itp, res)
			}

		case .PUTCHAR:
			{println("putchar")
				_top, ok := pop_safe(&itp.reg_array)
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
			fmt.panicf("Unknown opcode %v, iter %v", itp.code_register[0], iter)
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
	// write
	WRITE_LOCAL, // INFO: takes first word in reg_array and writes it to address second word
	PUSH_WORD,
	TOP_ADDR,
	// read
	READ_LOCAL,
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


STACK_SIZE :: 255
global_stack: [STACK_SIZE]uint
//@interpretor
Interpretor :: struct {
	// code
	code_len:       uint,
	code_register:  [^]u8,
	code_base:      [^]u8,
	// stack
	stack_register: [^]uint,
	stack_base:     [^]uint,
	stack_size:     int, // = STACK_SIZE
	// register array
	reg_array:      [dynamic]uint,
}

// @code register manipulations

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
code_advance :: #force_inline proc(itp: ^Interpretor, loc := #caller_location) {
	assert_contextless(itp.code_register < &itp.code_base[itp.code_len], loc = loc)

	_code_advance(itp)
}

// code_pop :: #force_inline proc(loc := #caller_location) -> u8 {
// 	assert_contextless(code_register > code_base, loc = loc)
//
// 	_code_retreat()
// 	return code_register[1]
// }

code_retreat :: #force_inline proc(itp: ^Interpretor, loc := #caller_location) {
	assert_contextless(itp.code_register > itp.code_base, loc = loc)

	_code_retreat(itp)
}

// @@code register internals
_code_advance :: #force_inline proc(itp: ^Interpretor) {itp.code_register = &itp.code_register[1]}
_code_retreat :: #force_inline proc(itp: ^Interpretor) {itp.code_register = &itp.code_register[-1]}


// @stack register manipulations
// INFO: stack is pointer alligned, each "cell" is exactly 8 bytes


Stack_cell :: struct #raw_union {
	sc:   uint,
	sc32: [2]u32,
	sc16: [4]u16,
	sc8:  [8]u8,
}

//@arguments register array manipulations
