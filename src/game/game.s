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

.file "src/game/game.s"

.data

score: .int 0
initBoard: .quad 0x8181818181818181
currentBoard: .quad 0x8181818181818181

cornerPieces: .quad 0x0620064002600460

.text

.global gameInit
.global gameLoop

.section .game.data

.section .game.text

gameInit:
	ret

gameLoop:

	# get current board to r15
	movq $currentBoard, %r8
	movq (%r8), %r15

	# print the board
	movq $7, %r8  # i = 7 (row iterator)

	print_loop:
		movq $7, %r9  # j = 7 (column iterator)

		print_row_loop:
			# print num at (i, j)
			movq $0, %rdx  # clear rdx for math operations

			# x = 4i, y = 4j
			movq %r9, %r12  # x = j
			movq $4, %rax
			mul %r12  # rax = 4x
			movq %rax, %r12  # x = 4x
			movq %r8, %r13  # y = i
			movq $4, %rax
			mul %r13  # rax = 4y
			movq %rax, %r13  # y = 4y

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

			movq $3, %r10  # x_offset = 3

			print_char_x:
				movq $3, %r11  # y_offset = 3
				
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
