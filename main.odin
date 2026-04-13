package main

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:reflect"
import "core:strconv"
import "core:strings"
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


	// #code setup


	// TODO: finish this code example or redo the damn vm
	code: [dynamic]u8 = parse(
		`
	lit_word 0x58
	putchar

	lit_word 0x4
	push_word

	lit_word 0x44
	push_word
loop:
	flush

	// print the char
	peek_word
	putchar

	// load the addr of counter
	lit_word 0x2
	read_local

	// save it
	push_word

	// sub the counter with 1
	lit_word 0x1
	pop_word
	sub

	// save the res
	push_word

	
	write_local

	lit_word 0x2
	read_local
	lit_word @loop

	jnz

	exit
	`,
	)

	// append_elem(&code, op(.INVALID))
	// append_elems(&code, op(.TOP_ADDR))
	// num := op_lit(1); append_elems(&code, ..num[:])
	// append_elem(&code, op(.EXIT))

	// #stack setup
	interp: Interpretor; {
		interp.stack_register = raw_data(global_stack[:])
		interp.stack_base = &global_stack[0]
		interp.stack_register = interp.stack_register[1:]
		interp.stack_size = STACK_SIZE

		interp.code_base = raw_data(code[:])
		interp.code_register = interp.code_base
		interp.code_len = len(code)
	}
	// #runtime
	vm_loop(&interp)
}

// @assembler
ASSEM_STUFF :: true; when ASSEM_STUFF {
	parse :: proc(file: string) -> (out: [dynamic]u8) {
		append(&out, op(.INVALID))
		labels: map[string]int
		names_arr := reflect.enum_field_names(op_code)
		codes_arr := reflect.enum_field_values(op_code)
		n_map: map[string]u8
		for name, i in names_arr {
			println(strings.to_lower(name), codes_arr[i])
			n_map[strings.to_lower(name)] = auto_cast codes_arr[i]
		}

		src := file
		i := 0
		outer: for line in strings.split_lines_iterator(&src) {
			switch parts := strings.split(line, " "); strings.trim_space(parts[0]) {
			// simple cases
			// case "add":
			// 	append(&out, op(.ADD))
			// case "putchar":
			// 	append(&out, op(.PUTCHAR))
			// case "push":
			// 	append(&out, op(.PUSH_WORD))
			// case "peek":
			// 	append(&out, op(.PEEK_WORD))
			// case "pop":
			// 	append(&out, op(.POP_WORD))
			// case "exit":
			// 	append(&out, op(.EXIT))

			// with arguments:
			case "lit_word":
				append(&out, op(.LIT_WORD))
				if len(parts) > 1 {
					num, ok := strconv.parse_uint(parts[1])
					// use the number
					if ok {
						segments := op_num(num)
						append_elems(&out, ..segments[:])
					} else {
						// compute the address probably
						if parts[1][0] == '@' {
							dest := parts[1][1:]
							label_offs := labels[dest]
							println("added label to reg array", label_offs, dest)
							segments := op_num(label_offs)
							append_elems(&out, ..segments[:])
						} else {
							fmt.panicf("Neither a number nor a label: %v %v", parts[1], parts)
						}
					}
					i += 8 // account for the 8 bytes added

					// any remaining parts will be ignored as comment
					println("remaining parts:", parts[2:])
				} else {
					println("remaining parts:", parts[1:])
				}

			case "": // empty lines are ok
			case:
				// simple cases
				op_string := strings.trim_space(parts[0])

				//	// comments
				if op_string[:2] == "//" {
					continue outer
				}
				//	// solo op_codes
				if len(parts) == 1 do if op_string in n_map {
					append_elem(&out, n_map[op_string])
					continue outer
				}


				// special cases
				/* parse labels*/
				cases: {
					if label_parts := strings.split(parts[0], ":"); len(label_parts) > 1 {
						label := strings.trim_space(label_parts[0])
						labels[label] = i + 1
						continue outer
					}
					fmt.panicf("implement '%v' from '%v'", op_string, parts)
				}
			}

			i += 1
		}

		return
	}
}

// @vm stuff
VM_STUFF :: true; when VM_STUFF {
	vm_loop :: proc(itp: ^Interpretor) {
		for iter in 0 ..< 255 {

			// INFO: each code point is NOT responsible for advancing the op_code_point
			code_advance(itp)
			assert(itp.stack_register > itp.stack_base)

			println("current opcode:", cast(op_code)itp.code_register[0])
			switch cast(op_code)itp.code_register[0] {
			case .NOP:
				{println("nop")}
			case .FLUSH:
				{println("flush")
					clear_dynamic_array(&itp.reg_array)
				}

			case .ADD:
				{println("add")
					// INFO: takes 2 arguments from reg_array, adds them, clears the array
					// and puts the result back
					n1, n2: uint
					ok: bool
					n1, ok = pop_safe(&itp.reg_array)
					println("n1:", n1)
					if !ok do panic("not enough arguments for add")
					n2, ok = pop_safe(&itp.reg_array)
					println("n2:", n2)
					if !ok do panic("not enough arguments for add")
					append(&itp.reg_array, n1 + n2)
					println(itp.reg_array)
				}

			case .SUB:
				{println("sub")
					n1, n2: uint
					ok: bool
					n1, ok = pop_safe(&itp.reg_array)
					if !ok do panic("not enough arguments for sub")
					n2, ok = pop_safe(&itp.reg_array)
					if !ok do panic("not enough arguments for sub")
					printf("%v - %v = %v", n1, n2, n1 - n2)
					append(&itp.reg_array, n1 - n2)
				}
			case .LIT_WORD:
				{println("lit")
					res: Stack_cell
					for i in 0 ..< 8 {
						code_advance(itp)
						res.sc8[i] = itp.code_register[0]
					}
					append(&itp.reg_array, res.sc)
					printf("appended %v to reg_array", res.sc8)
				}

			case .JNZ:
				{println("jnz")
					println(itp.reg_array)
					dest, ok := pop_safe(&itp.reg_array)
					if !ok do panic("not enough arguments for jnz")

					cond, ok2 := pop_safe(&itp.reg_array)
					if !ok2 do panic("not enough arguments for jnz")

					if cond != 0 {
						println("jumping to", dest)
						itp.code_register = itp.code_base[dest:]
					}
				}
			case .TOP_ADDR:
				{println("top_addr")
					mem_offset := mem.ptr_sub(itp.stack_register, itp.stack_base)
					println("Pushed offset:", mem_offset)
					fmt.assertf(
						itp.stack_base[mem_offset:] == itp.stack_register,
						"Stack pointer + mem_offset should point to the same thing as stack_register\n instead %v %v %v",
						mem_offset,
						itp.stack_base,
						itp.code_base,
					)
					append_elem(&itp.reg_array, uint(mem_offset))
				}
			case .READ_LOCAL:
				{println("read_local")
					dest, ok := pop_safe(&itp.reg_array)
					if !ok do panic("expected word at top of register array for read_local")
					if len(itp.reg_array) > 0 do panic("expected only 1 argument for read_local")

					// INFO: be carefull with dest
					fmt.assertf(
						dest <= cast(uint)itp.stack_size,
						"dest offset must not be greater then the stack size\n %b",
						dest,
					)
					w := itp.stack_base[dest]
					println("read", w, "from", dest)

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
						itp.stack_register = itp.stack_register[1:]
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
					println(top.sc8)
					// numbers in reg_array are little endian
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
		panic("You've hit the vm loop limit")
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
		LIT_WORD, // pushes a constant literal to reg_array
		FLUSH, // empties the register array
		JNZ,

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

	op_lit :: #force_inline proc(n: $T) -> [9]u8 where intrinsics.type_is_numeric(T) {
		res: [9]u8
		res[0] = op(.LIT_WORD)
		nums := op_num(n)
		for num in nums {
			res[i + 1] = num
		}
		println(res)
		return res
	}

	op_num :: #force_inline proc(n: $T) -> (res: [8]u8) where intrinsics.type_is_numeric(T) {
		temp: [8]u8 = transmute([8]u8)cast(u64)n
		res = temp
		println(res)
		return
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
		// TODO: fix all the places this is used
		// reg_array:      [dynamic]uint,
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

		itp.code_register = &itp.code_register[1]
	}


	// @stack register manipulations
	// INFO: stack is pointer alligned, each "cell" is exactly 8 bytes
	Stack_cell :: struct #raw_union {
		sc:   uint,
		sc32: [2]u32,
		sc16: [4]u16,
		sc8:  [8]u8,
	}

	//@arguments register array manipulations
}
