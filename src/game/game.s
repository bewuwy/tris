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
	- saving high score
	- hire a SCRUM master
*/

.file "src/game/game.s"

.global gameInit
.global gameLoop

.section .game.data

score: .quad 0

scoreboard:
.quad 0
.quad 0
.quad 0

scoreboardNames:
.asciz "1st"
.asciz "2nd"
.asciz "3rd"

initBoard: .skip 32
currentBoard: .skip 32
.word 0
tempBoard: .skip 32 # go fuck yourself
.quad 0
colorBoard: .skip 128
.quad 0
tmpColour: .skip 128
.quad 0
fallingBlock: .skip 32
fallingColor: .skip 4

gameState: .byte 0  # 0 - main menu, 1 - game, 2 - game over dialog, 3 - high score input

r_wall: .quad 0x0040004000400040
l_wall: .quad 0x8000800080008000

pieces: .skip 120

randomGen: .byte 0xa7

currPiece: .byte 0
holdPiece: .byte 5  # straight vert for debugging
canSwap: .byte 1

gravityCounter: .byte 0

.section .game.text

scoreString: .asciz "SCORE:"
scoreboardString: .asciz "-- SCOREBOARD --"
holdString: .asciz "HOLD"
gameOverString: .asciz "--- Game over! ---"
restartInputString: .asciz "press R to play again"
youBeatString: .asciz "You beat"

titleString: 
.ascii " _______   _"
.word 0x0A  # new line
.ascii "|__   __| (_)"
.word 0x0A  # new line
.ascii "   | |_ __ _ ___ "
.word 0x0A  # new line
.ascii "   | | '__| / __|"
.word 0x0A  # new line
.ascii "   | | |  | \\__ \\"
.word 0x0A  # new line
.ascii "   |_|_|  |_|___/"
.word 0x0A  # new line
.word 0x0A  # new line
.ascii "---- the game ----"
.word 0x0A  # new line
.word 0x0A  # new line
.ascii " press S to start"
.byte 0x00

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
	movq $0xffc0, 112(%r8)

	# init falling color
	mov $9, fallingColor

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

	movb gameState, %r8b

	cmpb $0, %r8b
	je main_menu_loop

	cmpb $2, %r8b
	je game_over_loop

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
		movb %r9b, currPiece
		movq currentBoard, %r15
		and %r8, %r15
		jz no_player_death
		player_death:  # player dies - no place to spawn
			movb $2, gameState
			jmp input_restart
		no_player_death:
		movq %r8, fallingBlock
	end_spawn_piece:

	# check for user input
	call readKeyCode


	# check for "C" input (??)
	cmp $46, %rax
	jne end_input_hold
	input_hold:
		movq $0, %r8
		movb canSwap, %r8b
		cmp $0, %r8
		je end_input_hold
		movb $0, canSwap
		mov $3, %r8	
		clean_falling_board_loop:
			leaq fallingBlock, %rcx
			movq $0, (%rcx, %r8, 8)
			dec %r8
			jge clean_falling_board_loop
		end_clean_falling_board_loop:
		mov $0, %r9
		movb holdPiece, %r9b
		leaq pieces, %rcx
		movq (%rcx, %r9, 8), %r8
		movq %r8, fallingBlock
		movb currPiece, %cl
		movb %cl, holdPiece
		movb %r9b, currPiece
		
	end_input_hold:
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
		movb $100, gravityCounter
	end_input_down:

	# check for "R" input (19)
	cmp $19, %rax
	jne end_input_restart
	input_restart:
		# update high score leaderboard if needed
		movq score, %r8
		leaq scoreboard, %r10

		# check 1st place in leaderboard
		movq (%r10), %r9

		cmpq %r9, %r8
		jle end_update_1stplace # score <= highScore, skip
			# 3rd place = old 2nd place
			movq 8(%r10), %r12
			movq %r12, 16(%r10)			
			# 2nd place = old 1st place
			movq %r9, 8(%r10)
			# 1st place = score
			movq %r8, (%r10)
			jmp end_update_scoreboard
		end_update_1stplace:

		# check 2nd place
		movq 8(%r10), %r9

		cmpq %r9, %r8
		jle end_update_2ndplace
			# 3rd place = old 2nd place
			movq %r9, 16(%r10)
			# 2nd place = score
			movq %r8, 8(%r10)
			jmp end_update_scoreboard
		end_update_2ndplace:

		# check 3rd place
		movq 16(%r10), %r9

		cmpq %r9, %r8
		jle end_update_3rdplace
			# 3rd place = score
			movq %r8, 16(%r10)
			jmp end_update_scoreboard
		end_update_3rdplace:

		end_update_scoreboard:

		movq $3, %r8
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

		# restart held piece
		movb $5, holdPiece
		movb $1, canSwap

		ret  # finish the gameLoop early
	end_input_restart:

	end_input:

	incb gravityCounter
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

		movb $0, gravityCounter  # reset gravity counter

		jmp end_put_block
		put_block:
			movb $1, canSwap
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
				not %rdx
				and %rdx, %r12
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
		movq $15, %r8
		check_line_loop:
			leaq currentBoard, %rcx
			movw (%rcx, %r8, 2), %r14w
			cmpw $0xFFC0, %r14w
			jne line_not_full
			line_full:
				add $0x10000, %r15
			line_not_full:
			shr %r15
			dec %r8
			jge check_line_loop
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
				dec %r8
				jge shift_line_loop
				jmp end_shift_line_loop
			end_inc_offset:
			leaq currentBoard, %rcx
			movw (%rcx, %r8, 2), %r14w
			movq %r8, %r11
			addq %r9, %r11
			leaq tempBoard, %rcx
			movw %r14w, (%rcx, %r11, 2)
			leaq colorBoard, %rcx
			movq (%rcx, %r8, 8), %r14
			movq %r8, %r11
			addq %r9, %r11
			leaq tmpColour, %rcx
			movq %r14, (%rcx, %r11, 8)
			dec %r8
			jge shift_line_loop
		end_shift_line_loop:
		movq $15, %r8
		save_line_clear_loop:
			leaq tempBoard, %rcx  # load temp board address
			movw (%rcx, %r8, 2), %r14w  # load 1 rows of falling piece array
			leaq currentBoard, %rcx  # load falling block address
			movw %r14w, (%rcx, %r8, 2)  # load 1 rows of falling piece array
			leaq tmpColour, %rcx  # load temp board address
			movq (%rcx, %r8, 8), %r14  # load 1 rows of colour
			leaq colorBoard, %rcx  # load falling block address
			movq %r14, (%rcx, %r8, 8)  # load 1 rows of fcolur piece array
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
		movq $9, %r9  # j = 15
		movq $0, %r15
		leaq tempBoard, %rcx
		leaq colorBoard, %r11
		movw (%rcx, %r8, 2), %r15w  #row to print
		movq (%r11, %r8, 8), %r11  #colours to print
		shr $6, %r15
		shr $24, %r11
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
			add $32, %rdi  # horizontal padding
			movq %r8, %rsi  # y = i
			add $4, %rsi  # vertical padding
			call putChar # print char
			shr %r15  # shift board to get next bit
			shr $4, %r11  # shift color board by 4 bits

			dec %r9
			//cmp $6, %r9
			jge print_row_loop
		end_print_row_loop:
		dec %r8
		jge print_loop
	end_print_loop:

	# print the held piece
	movq $4, %r8  # i = 4 (row iterator)
	
	print_hold_loop:
		movq $5, %r9  # j = 4
		movq $0, %r15
		leaq pieces, %rcx
		movq $0, %r10
		movb holdPiece, %r10b
		leaq (%rcx, %r10, 8), %rcx
		movw (%rcx, %r8, 2), %r15w  # row to print
		shr $6, %r15
		print_hold_row_loop:
			# print num at (i, j)
			movq $0, %rdx  # clear rdx
			movq %r15, %rax

			movq $2, %rcx
			divq %rcx  # divide board by 2
			cmpq $0, %rdx  # rdx = modulo of 2
			jne h_print1  # if not divisible by 2, print 1
			h_print0:
				mov $0, %rcx
				movb $7, %dl
				//shl $4, %cl
				or %dl, %cl
				movb $' ', %dl  # | char
				jmp end_print_hold_iter
			h_print1:
				movq $15, %rcx  # hard coded colour
				movb %cl, %dl
				shl $4, %cl
				or %dl, %cl

				movb $'H', %dl  # B char
				// shr $4, %cl
			end_print_hold_iter:
			movq %r9, %rdi  # x = j
			add $46, %rdi  # horizontal padding
			movq %r8, %rsi  # y = i
			add $5, %rsi  # vertical padding
			call putChar # print char
			shr %r15  # shift board to get next bit
			shr $4, %r11  # shift color board by 4 bits

			dec %r9
			//cmp $6, %r9
			jge print_hold_row_loop
		end_print_hold_row_loop:
		dec %r8
		jge print_hold_loop
	end_print_hold_loop:

	# frame
	# y = {4,20}, x = [31,42]
	# y = {4,8}, x = [46, 53]

	movq $31, %r8  # x
	movq $4, %r9  # y
	movq $42, %r11  # x stop
	movq $0, %r10  # i = 0
	print_frame_horizontal_loop:
		movq $3, %rcx
		movq $0, %rdx
		movb $'=', %dl

		mov %r8, %rdi
		mov %r9, %rsi
		call putChar

		inc %r8
		cmpq %r11, %r8
		jle print_frame_horizontal_loop		
	end_print_frame_horizontal_loop:

	inc %r10  # i++

	cmp $1, %r10
	jne end_horizontal_frame1

		movq $20, %r9
		movq $31, %r8
		jmp print_frame_horizontal_loop

	end_horizontal_frame1:

	cmp $2, %r10
	jne end_horizontal_frame2

		movq $4, %r9
		movq $46, %r8
		movq $53, %r11
		jmp print_frame_horizontal_loop
	end_horizontal_frame2:

	cmp $3, %r10
	jne end_horizontal_frame3

		movq $8, %r9
		movq $46, %r8
		jmp print_frame_horizontal_loop
	end_horizontal_frame3:

	# x = {31,42}, y = [4,20]
	# x = {46,53}, y = [4,8]
	movq $31, %r8  # x
	movq $4, %r9  # y
	movq $0, %r10  # i = 0
	movq $20, %r11 # y stop
	print_frame_vertical_loop:
		movq $3, %rcx
		movq $0, %rdx
		movb $'!', %dl

		mov %r8, %rdi
		mov %r9, %rsi
		call putChar

		inc %r9
		cmpq %r11, %r9
		jle print_frame_vertical_loop		
	end_print_frame_vertical_loop:

	inc %r10

	cmp $1, %r10
	jne end_vertical_frame1

		movq $42, %r8
		movq $4, %r9
		jmp print_frame_vertical_loop
	end_vertical_frame1:

	cmp $2, %r10
	jne end_vertical_frame2

		movq $46, %r8
		movq $4, %r9
		movq $8, %r11
		jmp print_frame_vertical_loop
	end_vertical_frame2:

	cmp $3, %r10
	jne end_vertical_frame3

		movq $53, %r8
		movq $4, %r9
		jmp print_frame_vertical_loop
	end_vertical_frame3:

	# print "score:" at (13, 5)
	movq $0, %r13  # i = 0
	leaq scoreString, %r12
	print_score_label_loop:
		mov $0, %rdx
		movb (%r12, %r13, 1), %dl  # get char
		cmpb $0, %dl
		je end_print_score_label_loop

		movq %r13, %rdi
		addq $13, %rdi  # get x

		movq $5, %rsi  # y = 1
		movq $15, %rcx  # color = white

		call putChar  # print

		inc %r13  # i++
		jmp print_score_label_loop
	end_print_score_label_loop:

	# print "hold" label
	movq $0, %r13  # i = 0
	leaq holdString, %r12
	print_hold_label_loop:
		mov $0, %rdx
		movb (%r12, %r13, 1), %dl  # get char
		cmpb $0, %dl
		je end_print_hold_label_loop

		movq %r13, %rdi
		addq $48, %rdi  # get x

		movq $9, %rsi  # y = 1
		movq $15, %rcx  # color = white

		call putChar  # print

		inc %r13  # i++
		jmp print_hold_label_loop
	end_print_hold_label_loop:

	# print score value
	movq score, %r8
	movq $13, %r9  # i = 13

	print_score_loop:
		movq %r8, %rax  # div by 10 to get last digit
		movq $10, %rcx
		movq $0, %rdx
		div %rcx  # last digit is in rdx
		addq $48, %rdx  # convert last digit to ASCII
		movq %rax, %r8

		movq %r9, %rdi  # x = i
		addq $12, %rdi
		movq $5, %rsi  # y = 1
		call putChar

		dec %r9
		cmp $8, %r9
		jge print_score_loop
	end_print_score_loop:

	# print scorerboard values
	leaq scoreboard, %r10
	movq $2, %r11  # j = 2

	leaderboard_values_print_loop:
		movq (%r10, %r11, 8), %r8
		movq $13, %r9  # i = 13

		print_highscore_loop:
			movq %r8, %rax  # div by 10 to get last digit
			movq $10, %rcx
			movq $0, %rdx
			div %rcx  # last digit is in rdx
			addq $48, %rdx  # convert last digit to ASCII
			movq %rax, %r8

			movq %r9, %rdi  # x = i
			addq $12, %rdi
			movq $9, %rsi  # y = 1
			addq %r11, %rsi
			addq %r11, %rsi
			call putChar

			dec %r9
			cmp $8, %r9
			jge print_highscore_loop
		end_print_highscore_loop:

		movq $26, %rdi  # x = 26
		movq $9, %rsi
		addq %r11, %rsi
		addq %r11, %rsi	
		call putChar

		movq $27, %rdi  # x = 27
		movq $9, %rsi
		addq %r11, %rsi
		addq %r11, %rsi	
		call putChar

		dec %r11
		jge leaderboard_values_print_loop
	end_leaderboard_values_print_loop:

	movq $2, %r8  # i = 2
	leaq scoreboardNames, %r10
	print_leaderboard_names_loop:
		movq $2, %r9  # j = 2

		print_name_char_loop:
			leaq (%r10, %r8, 4), %r11

			movq $0, %rdx
			movb (%r11, %r9), %dl

			movq %r9, %rdi  # x = i
			addq $14, %rdi
			movq $9, %rsi  # y = 1
			addq %r8, %rsi
			addq %r8, %rsi

			movq $15, %rcx

			call putChar

			dec %r9
			jge print_name_char_loop
		end_print_name_char_loop:

		# add the ":" character

		movq $17, %rdi
		movq $9, %rsi
		addq %r8, %rsi
		addq %r8, %rsi

		movb $':', %dl

		call putChar

		dec %r8
		jge print_leaderboard_names_loop
	end_print_leaderboard_names_loop:

	# add leading 0s
	movq $10, %rcx
	movq $'0', %rdx

	movq $26, %rdi  # x = 26
	movq $5, %rsi  # y = 5
	call putChar

	movq $27, %rdi  # x = 27
	movq $5, %rsi  # y = 5
	call putChar

	# print "scoreboard"
	movq $0, %r13  # i = 0
	leaq scoreboardString, %r12
	print_highscore_label_loop:
		mov $0, %rdx
		movb (%r12, %r13, 1), %dl  # get char
		cmpb $0, %dl
		je end_print_highscore_label_loop

		movq %r13, %rdi
		addq $13, %rdi  # get x

		movq $7, %rsi  # y = 3
		movq $15, %rcx  # color = white

		call putChar  # print

		inc %r13  # i++
		jmp print_highscore_label_loop
	end_print_highscore_label_loop:

	jmp end_loop  # finished in-game loop

	main_menu_loop:

	# print title
	leaq titleString, %r11
	movq $0, %r12  # x = 0
	movq $0, %r13  # y = 0
	movq $0, %r14  # i = 0

	print_title_string_loop:
		mov $0, %rdx
		movb (%r11, %r14, 1), %dl  # get char
		
		cmpb $0, %dl
		je end_print_title_string_loop

		cmp $0x20, %dl  # space
		jne print_title_not_space

			inc %r12  # x ++
			inc %r14 # i ++
			jmp print_title_string_loop

		print_title_not_space:

		cmpb $0x0A, %dl  # new line
		jne print_title_not_new_line

			inc %r13  # y ++
			add $2, %r14  # i ++
			movq $0, %r12  # x = 0
			jmp print_title_string_loop

		print_title_not_new_line:

		movq %r12, %rdi
		addq $30, %rdi  # get x

		movq %r13, %rsi
		addq $7, %rsi  # get y

		movq $15, %rcx  # color = white

		call putChar  # print

		inc %r14  # i++
		inc %r12  # x++
		jmp print_title_string_loop
	end_print_title_string_loop:

	# check for "S" input
	call readKeyCode
	cmp $31, %rax
	jne end_input_start
	input_start:
		# clear the screen
		movq $24, %r9  # y = 24
		start_clear_row:
			movq $79, %r8  # x = 79

			start_clear_char:
				movq %r8, %rdi  # pass x
				movq %r9, %rsi  # pass y
				movq $0, %rdx  # char
				movq $0, %rcx  # colour

				call putChar

				decq %r8  # x--
				jge start_clear_char
			end_start_clear_char:

			decq %r9  # y--
			jge start_clear_row
		end_start_clear_row:

		movb $1, gameState
		jmp end_loop
	end_input_start:

	jmp end_loop  # end of main menu loop

	game_over_loop:

	# print game over label
	movq $0, %r13  # i = 0
	leaq gameOverString, %r12
	print_gameover_label_loop:
		mov $0, %rdx
		movb (%r12, %r13, 1), %dl  # get char
		cmpb $0, %dl
		je end_print_gameover_label_loop

		movq %r13, %rdi
		addq $28, %rdi  # get x

		movq $22, %rsi  # y = 3
		movq $15, %rcx  # color = white

		call putChar  # print

		inc %r13  # i++
		jmp print_gameover_label_loop
	end_print_gameover_label_loop:

	# print restart input label
	movq $0, %r13  # i = 0
	leaq restartInputString, %r12
	print_restart_label_loop:
		mov $0, %rdx
		movb (%r12, %r13, 1), %dl  # get char
		cmpb $0, %dl
		je end_print_restart_label_loop

		movq %r13, %rdi
		addq $26, %rdi  # get x

		movq $23, %rsi  # y = 3
		movq $15, %rcx  # color = white

		call putChar  # print

		inc %r13  # i++
		jmp print_restart_label_loop
	end_print_restart_label_loop:

	leaq scoreboard, %r10
	movq score, %r8
	movq $0, %r13  # beat place name address = null

	# check 1st place in leaderboard
	movq (%r10), %r9

	cmpq %r9, %r8
	jne end_check_1stplace # score <= highScore, skip		
		leaq scoreboardNames, %r13
		jmp end_check_scoreboard
	end_check_1stplace:

	# check 2nd place
	movq 8(%r10), %r9

	cmpq %r9, %r8
	jne end_check_2ndplace
		leaq scoreboardNames, %r13
		addq $4, %r13
		jmp end_check_scoreboard
	end_check_2ndplace:

	# check 3rd place
	movq 16(%r10), %r9

	cmpq %r9, %r8
	jne end_check_3rdplace
		leaq scoreboardNames, %r13
		addq $8, %r13
		jmp end_check_scoreboard
	end_check_3rdplace:

	end_check_scoreboard:


	// # print score value
	// movq (%r10), %r8
	// movq $13, %r9  # i = 13

	// print_score_loop2:
	// 	movq %r8, %rax  # div by 10 to get last digit
	// 	movq $10, %rcx
	// 	movq $0, %rdx
	// 	div %rcx  # last digit is in rdx
	// 	addq $48, %rdx  # convert last digit to ASCII
	// 	movq %rax, %r8

	// 	movq %r9, %rdi  # x = i
	// 	addq $12, %rdi
	// 	movq $20, %rsi  # y = 1
	// 	call putChar

	// 	dec %r9
	// 	cmp $8, %r9
	// 	jge print_score_loop2
	// end_print_score_loop2:

	# beat someone -> print
	cmpq $0, %r13
	je end_print_beat
		movq $0, %r11  # i = 0
		leaq youBeatString, %r12

		print_you_beat_label_loop:
			mov $0, %rdx
			movb (%r12, %r11, 1), %dl  # get char
			cmpb $0, %dl
			je end_print_you_beat_label_loop

			movq %r11, %rdi
			addq $30, %rdi  # get x

			movq $24, %rsi  # y = 3
			movq $15, %rcx  # color = white

			call putChar  # print

			inc %r11  # i++
			jmp print_you_beat_label_loop
		end_print_you_beat_label_loop:

		movq $0, %r11  # i = 0

		print_you_beat_name_loop:
			mov $0, %rdx
			movb (%r13, %r11, 1), %dl  # get char
			cmpb $0, %dl
			je end_print_you_beat_name_loop

			movq %r11, %rdi
			addq $39, %rdi  # get x

			movq $24, %rsi  # y = 3
			movq $15, %rcx  # color = white

			call putChar  # print

			inc %r11  # i++
			jmp print_you_beat_name_loop
		end_print_you_beat_name_loop:

		# print a "!"
		movq $42, %rdi
		movq $24, %rsi

		movb $'!', %dl
		call putChar

	end_print_beat:

	# check for "R" input
	call readKeyCode
	cmp $19, %rax
	jne end_input_restart_gameover
		# clear the bottom of the screen
		movq $24, %r9  # y = 24
		restart_clear_row:
			movq $79, %r8  # x = 79

			restart_clear_char:
				movq %r8, %rdi  # pass x
				movq %r9, %rsi  # pass y
				movq $0, %rdx  # char
				movq $0, %rcx  # colour

				call putChar

				decq %r8  # x--
				jge restart_clear_char
			end_restart_clear_char:

			decq %r9  # y--
			cmpq $20, %r9
			jge restart_clear_row
		end_restart_clear_row:

		# set game state to main game
		movb $1, gameState
		jmp input_restart
	end_input_restart_gameover:

	jmp end_loop  # end of game over loop

	end_loop:

	ret
