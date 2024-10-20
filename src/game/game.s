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
	- score
	- colors
	- saving high score
	- hire a SCRUM master
*/

.file "src/game/game.s"

.data

score: .int 0

initBoard: .skip 32
currentBoard: .skip 32

tempBoard: .skip 34 # go fuck yourself
colorBoard: .skip 128

fallingBlock: .skip 32
fallingColor: .skip 4

currentMode: .byte 0

r_wall: .quad 0x0040004000400040
l_wall: .quad 0x8000800080008000

pieces: .skip 112

randomGen: .byte 0xa7

gravityCounter: .byte 0

.text

scoreString: .asciz "SCORE:"

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

	# init falling color
	mov $9, fallingColor  # 0xA

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
		mov $15, %r8
		restart_colors_loop:
			leaq colorBoard, %rcx
			movq $0, (%rcx, %r8, 8)
			dec %r8
			jge restart_colors_loop
		end_restart_colors_loop:
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
			mov $15, %r8
			put_block_loop:
				leaq fallingBlock, %rcx
				movw (%rcx,%r8,2), %r14w  # load 1 row of falling piece array
				leaq currentBoard, %rcx
				movw (%rcx,%r8, 2), %r15w #  load corresponding row of current board
				or %r14w, %r15w
				movw %r15w, (%rcx,%r8, 2) # save falling block to current board

				movq $0, %rax
				movb fallingColor, %al
				mov $0x1111111111111111, %rcx
				mul %rcx  # falling color array

				mov %rax, %r13

				movq $0, %rax
				movw %r14w, %ax
				mov $0, %rdx
				mov $15, %rcx
				make_mask_loop:
					mov $0x8000, %rbx
					and %r14w, %bx
					shl $4, %rdx
					shl %r14w
					cmpq $0, %rbx
					je nic
					add $0xf, %rdx
					nic:
					dec %rcx
					jge make_mask_loop
				end_make_mask_loop:

				and %rdx, %r13 # falling color to save

				leaq colorBoard, %rcx
				movq (%rcx,%r8,8), %r12
				//not %rdx
				//and %rdx, %r12
				or %r13, %r12
				movq %r12, (%rcx,%r8,8)

				leaq fallingBlock, %rcx
				movw $0,(%rcx,%r8, 2)
				dec %r8
				jge put_block_loop
			end_put_block_loop:

			# update falling color
			inc fallingColor
			cmpb $14, fallingColor
			jle end_reset_falling_color
			reset_falling_color:
				mov $9, fallingColor
			end_reset_falling_color:
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
		movq $15, %r9  # j = 15 (column iterator)
		movq $0, %r15
		leaq tempBoard, %rcx
		leaq colorBoard, %r11
		movw (%rcx, %r8, 2), %r15w
		movq (%r11, %r8, 8), %r11

		print_row_loop:
			# print num at (i, j)
			movq $0, %rdx  # clear rdx
			movq %r15, %rax

			movq $2, %rcx
			divq %rcx  # divide board by 2
			cmpq $0, %rdx  # rdx = modulo of 2
			jne print1  # if not divisible by 2, print 1
			print0:
				mov $0, %rcx
				//movb %r11b, %cl  # colour
				movb $7, %dl
				//shl $4, %cl
				or %dl, %cl
				movb $'|', %dl  # | char
				jmp end_print_iter
			print1:
				mov $0, %rcx
				movb %r11b, %cl
				and $0xf, %cl  # colour
				movb %cl, %dl
				shl $4, %cl
				or %dl, %cl

				cmp $0, %rcx
				jne end_get_falling_color
				get_falling_color:
					movb fallingColor, %cl
					movb %cl, %dl
					shl $4, %cl
					or %dl, %cl
				end_get_falling_color:

				movb $' ', %dl  # B char
				// shr $4, %cl
			end_print_iter:
			movq %r9, %rdi  # x = j
			add $20, %rdi
			movq %r8, %rsi  # y = i
			add $6, %rsi
			call putChar # print char
			shr %r15  # shift board to get next bit
			shr $4, %r11  # shift color board by 4 bits

			dec %r9
			jge print_row_loop
		end_print_row_loop:
		dec %r8
		jge print_loop
	end_print_loop:

	# print "score:"
	movq $0, %r13  # i = 0
	leaq scoreString, %r12
	print_score_label_loop:
		mov $0, %rdx
		movb (%r12, %r13, 1), %dl  # get char
		cmpb $0, %dl
		je end_print_score_label_loop

		movq %r13, %rdi
		addq $1, %rdi  # get x

		movq $1, %rsi  # y = 1
		movq $15, %rcx  # color = white

		call putChar  # print

		inc %r13  # i++
		jmp print_score_label_loop
	end_print_score_label_loop:

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
