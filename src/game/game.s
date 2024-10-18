/*
This file is part of gamelib-x64.

Copyright (C) 2014 Tim Hegeman

gamelib-x64 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

gamelib-x64 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with gamelib-x64. If not, see <http://www.gnu.org/licenses/>.
*/

/*
TODO:
	- controls - check if you can go left/right
	- random block spawning
	- score
	- lose condition
	- saving high score
	- retry
	- hire a SCRUM master
*/

.file "src/game/game.s"

.data

score: .int 0

initBoard: .skip 32
currentBoard: .skip 32


tempBoard: .skip 34 # go fuck yourself

fallingBlock: .skip 32

currentMode: .byte 0

r_wall: .quad 0x0040004000400040
l_wall: .quad 0x8000800080008000

pieces: .skip 112

randomGen: .byte 0xa7

gravityCounter: .byte 0

.text

.global gameInit
.global gameLoop

.section .game.data

.section .game.text

gameInit:

	# init pieces in memory
	leaq pieces, %r8
	movq $0x00800180, (%r8)  # br corner
	movq $0x01800080, 8(%r8)  # tr corner
	movq $0x01000180, 16(%r8)  # bl corner
	movq $0x01800100, 24(%r8)  # tl corner

	movq $0x0380, 32(%r8)  # horizontal line
	movq $0x008000800080, %r9
	movq %r9, 40(%r8)  # vertical line

	movq $0x010000800080, %r9
	movq %r9, 48(%r8)  # vbend tl
	movq $0x008001000100, %r9
	movq %r9, 56(%r8)  # vbend tr
	movq $0x008000800100, %r9
	movq %r9, 64(%r8)  # vbend bl
	movq $0x010001000080, %r9
	movq %r9, 72(%r8)  # vbend br

	movq $0x03000080, 80(%r8)  # hbend br
	movq $0x00c00100, 88(%r8)  # hbend bl
	movq $0x00800300, 96(%r8)  # hbend tr
	movq $0x010000c0, 104(%r8)  # hbend tl

	# clear the screen

	movq $24, %r9  # y = 24
	clear_row:
		movq $79, %r8  # x = 79

		clear_char:

			movq %r8, %rdi  # pass x
			movq %r9, %rsi  # pass y
			movq $0, %rdx  # char
			movq $0, %rcx  # colour

			call putChar

			decq %r8  # x--
			jge clear_char
		end_clear_char:

		decq %r9  # y--
		jge clear_row
	end_clear_row:

	movq $0, %r14  # clear falling piece

	movq $0, score  # clear score

	ret

gameLoop:

	# update random gen
	mov randomGen, %r8b
	mov %r8b, %r9b
	shr $3, %r9b
	xor %r8b, %r9b
	shl $7, %r9b
	or %r9b, %r8b
	incb %r8b
	movb %r8b, randomGen

	# check if there is no falling piece (fallingBlock is 0)
	mov $3, %r8
	check_falling_piece_loop:
		leaq fallingBlock, %rcx
		mov (%rcx,%r8,8), %r14
		cmpq $0, %r14
		jne end_spawn_piece
		dec %r8
		jge check_falling_piece_loop
	end_checkfalling_piece_loop:

	spawn_piece:
	
		movq randomGen, %rax
		movq $0, %rdx
		movq $14, %rcx
		div %rcx
		movq %rdx, %r9

		leaq pieces, %rcx
		movq (%rcx, %r9, 8), %r8
		movq currentBoard, %r15
		and %r8, %r15
		jnz input_restart
		movq %r8, fallingBlock
	end_spawn_piece:

	# check for user input
	# TODO FIX: check for collision when moving pieces
	call readKeyCode

	# check for "A" input (30)
	cmp $30, %rax
	jne end_input_left
	input_left:
		movq $3, %r8
		shift_left_loop:
			leaq fallingBlock, %rcx
			movq (%rcx,%r8,8), %r14
			mov l_wall, %r15
			and %r14, %r15
			jnz end_save_shift_left
			shl $1, %r14  # shift the piece left
			leaq currentBoard, %rcx
			movq (%rcx,%r8,8), %r15 #  load corresponding 4 rows of current board
			and %r14, %r15
			jne end_save_shift_left  # r14 and r15 != 0 -> overlap
			leaq tempBoard, %rcx
			movq %r14, (%rcx,%r8,8)
			dec %r8
			jge shift_left_loop
		end_shift_left:
		movq $3, %r8
		save_shift_left_loop:
			leaq tempBoard, %rcx
			movq (%rcx,%r8,8), %r14
			leaq fallingBlock, %rcx
			movq %r14, (%rcx,%r8,8)
			dec %r8
			jge save_shift_left_loop
		end_save_shift_left:
		jmp end_gravity_tick
	end_input_left:

	# check for "D" input (32)
	cmp $32, %rax
	jne end_input_right
	input_right:
		movq $3, %r8
		shift_right_loop:
			leaq fallingBlock, %rcx
			movq (%rcx,%r8,8), %r14
			mov r_wall, %r15
			and %r14, %r15
			jnz end_save_shift_right
			shr $1, %r14  # shift the piece right
			leaq currentBoard, %rcx
			movq (%rcx,%r8,8), %r15 #  load corresponding 4 rows of current board
			and %r14, %r15
			jne end_save_shift_right  # r14 and r15 != 0 -> overlap
			leaq tempBoard, %rcx
			movq %r14, (%rcx,%r8,8)
			dec %r8
			jge shift_right_loop
		end_shift_right:
		movq $3, %r8
		save_shift_right_loop:
			leaq tempBoard, %rcx
			movq (%rcx,%r8,8), %r14
			leaq fallingBlock, %rcx
			movq %r14, (%rcx,%r8,8)
			dec %r8
			jge save_shift_right_loop
		end_save_shift_right:

		jmp end_gravity_tick
	end_input_right:

	# check for "S" input (31)
	cmp $31, %rax
	jne end_input_down
	input_down:
		movq $100, gravityCounter
	end_input_down:

	# check for "R" input (19)
	cmp $19, %rax
	jne end_input_restart
	input_restart:
		# TODO: add restart
		mov $3, %r8
		movb $0, gravityCounter
		movq $0, score
		restart_loop:
			leaq fallingBlock, %rcx
			movq $0, (%rcx, %r8, 8)
			leaq currentBoard, %rcx
			movq $0, (%rcx, %r8, 8)
			leaq tempBoard, %rcx
			movq $0, (%rcx, %r8, 8)
			dec %r8
			jge restart_loop
		end_restart_loop:
		ret  # finish the gameLoop early
	end_input_restart:

	end_input:

	inc gravityCounter
	cmpb $15, gravityCounter
	jl end_gravity_tick
	gravity_tick:

		incq score  # score ++
		movq $24, %r8

		# check if block is at the bottom of the board
		leaq fallingBlock, %rcx
		movq (%rcx,%r8), %r14
		shr $48, %r14  # get bottom row
		cmpw $0, %r14w
		jne put_block		

		gravity_loop:
			leaq fallingBlock, %rcx
			movq (%rcx,%r8), %r14  # load 4 rows of falling piece array
			shl $16, %r14  # move falling piece 1 row down
			leaq currentBoard, %rcx
			movq (%rcx,%r8), %r15 #  load corresponding 4 rows of current board
			and %r14, %r15
			jne put_block  # r14 and r15 != 0 -> overlap
			leaq tempBoard, %rcx
			movq %r14, (%rcx, %r8)
			subq $6, %r8
			jge gravity_loop
		end_gravity_loop:

		movq $3, %r8	 # i = 3
		save_gravity_loop:
			leaq tempBoard, %rcx  # load temp board address
			movq (%rcx, %r8, 8), %r14  # load 4 rows of falling piece array
			leaq fallingBlock, %rcx  # load falling block address
			movq %r14, (%rcx, %r8, 8)  # load 4 rows of falling piece array
			dec %r8  # i--
			jge save_gravity_loop
		end_save_gravity_loop:

		mov $0, gravityCounter  # reset gravity counter

		jmp end_put_block
		put_block:
			mov $3, %r8
			put_block_loop:
				leaq fallingBlock, %rcx
				movq (%rcx,%r8, 8), %r14  # load 4 rows of falling piece array
				leaq currentBoard, %rcx
				movq (%rcx,%r8, 8), %r15 #  load corresponding 4 rows of current board
				or %r14, %r15
				movq %r15, (%rcx,%r8, 8)
				leaq fallingBlock, %rcx
				movq $0,(%rcx,%r8, 8)  # load 4 rows of falling piece array
				dec %r8
				jge put_block_loop
		end_put_block: 
	end_gravity_tick:

	clear_line_tick:
		movq $0, %r15
		movq $0, %r8
		check_line_loop:
			leaq currentBoard, %rcx
			movw (%rcx, %r8, 2), %r14w
			cmpw $0xFFC0, %r14w
			jne line_not_full
			line_full:
				add $0x8000, %r15
			line_not_full:
			shr %r15
			inc %r8
			cmp $15, %r8
			jle check_line_loop
		end_check_line_loop:
		movq $15, %r8
		movq $0, %r9
		shift_line_loop:
			mov $0, %rdx
			mov %r15, %rax
			shr %r15
			mov $2, %rcx
			div %rcx
			cmp $0, %rdx
			je end_inc_offset
			inc_offset:
				inc %r9
				movq %r9, score
			end_inc_offset:
			leaq currentBoard, %rcx
			movw (%rcx, %r8, 2), %r14w
			movq %r8, %r11
			addq %r9, %r11
			leaq tempBoard, %rcx
			movw %r14w, (%rcx, %r11, 2)
			dec %r8
			jge shift_line_loop
		end_shift_line_loop:
		movq $3, %r8
		save_line_clear_loop:
			leaq tempBoard, %rcx  # load temp board address
			movq (%rcx, %r8, 8), %r14  # load 4 rows of falling piece array
			leaq currentBoard, %rcx  # load falling block address
			movq %r14, (%rcx, %r8, 8)  # load 4 rows of falling piece array
			dec %r8  # i--
			jge save_line_clear_loop
		end_save_line_clear_loop:
	end_clear_line_tick:

	# add the falling piece to the tempBoard for rendering 
	mov $3, %r8
	prepare_tmp_board:
		leaq fallingBlock, %rcx
		movq (%rcx,%r8, 8), %r14  # load 4 rows of falling piece array
		leaq currentBoard, %rcx
		movq (%rcx,%r8, 8), %r15 #  load corresponding 4 rows of current board
		or %r14, %r15
		leaq tempBoard, %rcx
		movq %r15, (%rcx,%r8, 8)
		dec %r8
		jge prepare_tmp_board
	prepare_tmp_board_end: 

	# print the board
	movq $15, %r8  # i = 15 (row iterator)

	print_loop:
			movq $15, %r9  # j = 15
			movq $0, %r15
			leaq tempBoard, %rcx
			movw (%rcx, %r8, 2), %r15w
		print_row_loop:
			# print num at (i, j)
			movq $0, %rdx  # clear rdx
			movq %r15, %rax

			movq $2, %rcx
			divq %rcx  # divide board by 2
			cmpq $0, %rdx  # rdx = modulo of 2
			jne print1  # if not divisible by 2, print 1
			print0:
				movb $'0', %dl  # 0 char
				movb $0x01, %cl  # colour
				jmp end_print_iter
			print1:
				movb $'B', %dl  # B char
				movb $0x0f, %cl  # white colour
			end_print_iter:
			movq %r9, %rdi  # x = j
			add $20, %rdi
			movq %r8, %rsi  # y = i
			add $6, %rsi
			call putChar # print char
			shr %r15  # shift board to get next bit
			dec %r9
			jge print_row_loop
		end_print_row_loop:
		dec %r8
		jge print_loop
	end_print_loop:

	# print "score:"
	movq $1, %rsi  # y = 1
	movq $15, %rcx  # color = white

	movq $1, %rdi  # x = 1
	movq $'S', %rdx
	call putChar

	movq $2, %rdi  # x = 2
	movq $1, %rsi  # y = 1
	movq $'C', %rdx
	call putChar

	movq $3, %rdi  # x = 3
	movq $1, %rsi  # y = 1
	movq $'O', %rdx
	call putChar

	movq $4, %rdi  # x = 4
	movq $1, %rsi  # y = 1
	movq $'R', %rdx
	call putChar

	movq $5, %rdi  # x = 5
	movq $1, %rsi  # y = 1
	movq $'E', %rdx
	call putChar

	movq $6, %rdi  # x = 6
	movq $1, %rsi  # y = 1
	movq $':', %rdx
	call putChar

	# print score value
	movq score, %r8

	movq %r8, %rax  # div by 10 to get last digit
	movq $10, %rcx
	movq $0, %rdx
	div %rcx  # last digit is in rdx
	addq $48, %rdx  # convert last digit to ASCII
	movq %rax, %r8

	movq $13, %rdi  # x = 13
	movq $1, %rsi  # y = 1
	call putChar

	movq %r8, %rax  # div by 10 to get 2nd last digit
	movq $10, %rcx
	movq $0, %rdx
	div %rcx  # last digit is in rdx
	addq $48, %rdx  # convert digit to ASCII
	movq %rax, %r8

	movq $12, %rdi  # x = 12
	movq $1, %rsi  # y = 1
	call putChar

	movq %r8, %rax  # div by 10 to get 2nd last digit
	movq $10, %rcx
	movq $0, %rdx
	div %rcx  # last digit is in rdx
	addq $48, %rdx  # convert digit to ASCII
	movq %rax, %r8

	movq $11, %rdi  # x = 11
	movq $1, %rsi  # y = 1
	call putChar

	movq %r8, %rax  # div by 10 to get 2nd last digit
	movq $10, %rcx
	movq $0, %rdx
	div %rcx  # last digit is in rdx
	addq $48, %rdx  # convert digit to ASCII
	movq %rax, %r8

	movq $10, %rdi  # x = 10
	movq $1, %rsi  # y = 1
	call putChar

	movq %r8, %rax  # div by 10 to get 2nd last digit
	movq $10, %rcx
	movq $0, %rdx
	div %rcx  # last digit is in rdx
	addq $48, %rdx  # convert digit to ASCII
	movq %rax, %r8

	movq $9, %rdi  # x = 9
	movq $1, %rsi  # y = 1
	call putChar

	movq %r8, %rax  # div by 10 to get 2nd last digit
	movq $10, %rcx
	movq $0, %rdx
	div %rcx  # last digit is in rdx
	addq $48, %rdx  # convert digit to ASCII
	movq %rax, %r8

	movq $8, %rdi  # x = 8
	movq $1, %rsi  # y = 1
	call putChar

	# add leading 0s
	movq $'0', %rdx

	movq $14, %rdi  # x = 14
	movq $1, %rsi  # y = 1
	call putChar

	movq $15, %rdi  # x = 15
	movq $1, %rsi  # y = 1
	call putChar

	ret
