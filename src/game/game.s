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

	movq $7, %r8  # i = 7

	print_loop:
		movq $7, %r9  # j = 7


		print_row_loop:

			# print num at (i, j)

			movq $0, %rdx  # clear rdx
			movq %r15, %rax  # move board to rax for division
			movq $2, %rcx
			divq %rcx  # divide board by 2

			cmpq $0, %rdx  # rdx = modulo of 2
			jne print1  # if not divisible by 2, print 1

			print0:
				movb $'0', %dl  # 0 char
				movb $0x00, %cl  # colour

				jmp end_print_iter

			print1:
				movb $'B', %dl  # B char
				movb $0x0f, %cl  # white colour

			end_print_iter:

			movq %r9, %rdi  # x = j
			movq %r8, %rsi  # y = i
			call putChar # print char

			shr %r15  # shift board to get next bit

			dec %r9
			jge print_row_loop
		end_print_row_loop:

		dec %r8
		jge print_loop
	end_print_loop:

	ret
