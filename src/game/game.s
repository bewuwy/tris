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
	- scale blocks horizontally by 3, vertically by 2 when printing
	- controls
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

	inc gravityCounter
	cmpb $20, gravityCounter
	jl end_gravity_tick
	gravity_tick:
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

	# add the falling piece to board 
	or %r14, %r15

	# print the board
	movq $7, %r8  # i = 7 (row iterator)

	print_loop:
		movq $7, %r9  # j = 7 (column iterator)

		print_row_loop:
			# print num at (i, j)
			movq $0, %rdx  # clear rdx for math operations

			# x = 2i, y = 2j
			movq %r9, %r12  # x = j
			movq $2, %rax
			mul %r12  # rax = 2x
			movq %rax, %r12  # x = 2x
			movq %r8, %r13  # y = i
			movq $2, %rax
			mul %r13  # rax = 2y
			movq %rax, %r13  # y = 2y

			# add padding to x,y
			add $32, %r12
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

			movq $1, %r10  # x_offset = 3

			print_char_x:
				movq $1, %r11  # y_offset = 3
				
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

	ret
