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
initBoard: .quad 0x8181818181818181
currentBoard: .quad 0x8181818181818181

brCornerPiece: .word 0x818

gravityCounter: .byte 0

.text

.global gameInit
.global gameLoop

.section .game.data

.section .game.text

gameInit:

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

	# get current board to r15
	movq currentBoard, %r15

	# check if there is no falling piece (r14 is empty)
	cmpq $0, %r14
	jne end_spawn_piece
	spawn_piece:

		movw brCornerPiece, %r14w  # get br piece to r14
		shl $48, %r14  # add leading zeroes to the piece

	end_spawn_piece:

	# check for user input
	# TODO FIX: check for collision when moving pieces
	call readKeyCode

	# check for "A" input (30)
	cmp $30, %rax
	jne end_input_left
	input_left:
		shl $1, %r14  # shift the piece left

		jmp end_input
	end_input_left:

	# check for "D" input (32)
	cmp $32, %rax
	jne end_input_right
	input_right:
		shr $1, %r14  # shift the piece right

		jmp end_input
	end_input_right:

	# check for "S" input (31)
	cmp $31, %rax
	jne end_input_down
	input_down:
		shr $8, %r14  # shift the piece down by 1 row

		jmp end_input
	end_input_down:

	# check for "R" input (19)
	cmp $19, %rax
	jne end_input_restart
	input_restart:
		# TODO FIX: down half of the board goes missing when resetting
		mov initBoard, %r15  # reset current board register
		mov %r15, currentBoard  # reset stored board
		movq $0, %r14  # reset falling piece
		movq $0, score  # reset score
		movq $0, gravityCounter  # reset gravity counter

		ret  # finish the gameLoop early
	end_input_restart:

	end_input:

	inc gravityCounter
	cmpb $30, gravityCounter
	jl end_gravity_tick
	gravity_tick:

		inc score  # score ++

		shr $8, %r14  # move falling piece 1 row down	
		mov $0, gravityCounter  # reset gravity counter

		movq %r15, %r8  # copy current board to r8
		movq %r15, %r9  # copy current board to r9

		# check if it has fallen on another piece
		or %r14, %r8
		xor %r14, %r9
		cmpq %r8, %r9
		jne put_block 

		# check if it has fallen on the ground
		movb %r14b, %r8b
		cmpb $0, %r8b
		jne put_block_bottom

		jmp end_put_block

		put_block:
			shl $8, %r14  # move the piece back up by 1 row
		put_block_bottom:
			or %r14, %r15  # put piece on board
			mov %r15, currentBoard # save current board (with piece) to memory
			movq $0, %r14  # clear falling piece
		end_put_block: 
	end_gravity_tick:

	# add the falling piece to the board 
	or %r14, %r15

	# print the board
	movq $7, %r8  # i = 7 (row iterator)

	print_loop:
		movq $7, %r9  # j = 7 (column iterator)

		print_row_loop:
			# print num at (i, j)
			movq $0, %rdx  # clear rdx for math operations

			# x = 3i, y = 2j
			movq %r9, %r12  # x = j
			movq $3, %rax
			mul %r12  # rax = 3x
			movq %rax, %r12  # x = 3x
			movq %r8, %r13  # y = i
			movq $2, %rax
			mul %r13  # rax = 2y
			movq %rax, %r13  # y = 2y

			# add padding to x,y
			add $28, %r12
			add $4, %r13

			# check if there is 0 or 1 at (i, j)
			movq %r15, %rax  # move board to rax for division
			movq $2, %rcx
			divq %rcx  # divide board by 2

			cmpq $0, %rdx  # rdx = modulo 2
			jne print1  # if not divisible by 2, it is 1

			print0:
				movb $'0', %dl  # 0 char
				movb $0x08, %cl  # gray colour

				jmp end_print_iter

			print1:
				movb $'B', %dl  # B char
				movb $0x0f, %cl  # white colour

			end_print_iter:

			movq $2, %r10  # x_offset = 2

			print_char_x:
				movq $1, %r11  # y_offset = 1
				
				print_char_y:

					movq %r12, %rdi  # pass x
					movq %r13, %rsi  # pass y

					add %r10, %rdi  # x += x_offset
					add %r11, %rsi  # y += y_offset

					call putChar # print char

					decq %r11  # y_offset --
					jge print_char_y
				end_print_char_y:

				decq %r10  # x_offset --
				jge print_char_x
			end_print_char_x:

			shr %r15  # shift board to get next bit for next iteration

			dec %r9  # j--
			jge print_row_loop  # j>=0 then repeat row
		end_print_row_loop:

		dec %r8  # i--
		jge print_loop  # i>=0 then repeat
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
