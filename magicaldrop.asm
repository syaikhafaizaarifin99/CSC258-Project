################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Syaikha Faiza Arifin, 1011987236
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

colors:
    .word 0x000000, 0x00ff00, 0xffff00, 0xff8800, 0x0000ff
    #     0=empty  1=green   2=yellow   3=orange    4=blue
    
wall_color:
    .word 0x888888 # gray
player_color:
    .word 0xffffff # white

##############################################################################
# Mutable Data
##############################################################################
grid: 
    .space 392 # 7 x 14 grid x 4 = 392 byte
player_col:
    .word 3 # start from the middle
held_color:
     .word 0 # initial state (does not held ball)
held_count: 
     .word 0 # initial state (does not held ball)
key_counter: 
    .word 0 # initial state


##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    jal init_grid 

game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
    check_collision:
    # Check if it is time to advance
    lw $t0, key_counter
    blt $t0, 10, skip_advance

    # Reset counter
    sw $zero, key_counter

    # Move rows down
    jal advance_row

    skip_advance:
    # Check bottom row
    jal check_game_over

	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep
	li $v0, 32          # syscall 32 = sleep
    li $a0, 16          # sleep 16 ms
    syscall

    # 5. Go back to Step 1
    j game_loop
    

init_grid:
    la $t0, grid
    li $t1, 0

init_loop:
    bge $t1, 98, init_done

    # First 5 rows: random colors
    blt $t1, 35, init_random

    # Remaining rows: empty
    sw $zero, 0($t0)
    j init_next

init_random:
    li $v0, 42
    li $a0, 0
    li $a1, 4
    syscall

    addi $t2, $a0, 1
    sw $t2, 0($t0)

init_next:
    addi $t0, $t0, 4
    addi $t1, $t1, 1
    j init_loop

init_done:
    jr $ra
    
#----------------------------------------------------
    
# Get value of a cell
# Input:  $a0 = row, $a1 = column
# Output: $v0 = cell value

get_cell:
    li $t0, 7
    mul $t1, $a0, $t0
    add $t1, $t1, $a1
    sll $t1, $t1, 2

    la $t0, grid
    add $t0, $t0, $t1

    lw $v0, 0($t0)
    jr $ra
    
# Set value of a cell
# Input: $a0 = row, $a1 = column
#        $a2 = new cell value

set_cell:
    li $t0, 7
    mul $t1, $a0, $t0
    add $t1, $t1, $a1
    sll $t1, $t1, 2

    la $t0, grid
    add $t0, $t0, $t1

    sw $a2, 0($t0)
    jr $ra
    
# ----------------------------------------------------------------
    
# Grab balls from current player column
# Bottommost occupied cell first
# Continue upward while colors match

grab_ball:
    lw $t0, player_col
    li $t1, 13
    la $t2, grid

grab_find:
    bltz $t1, grab_done

    # index = row * 7 + column
    li $t3, 7
    mul $t4, $t1, $t3
    add $t4, $t4, $t0
    sll $t4, $t4, 2

    add $t5, $t2, $t4
    lw $t6, 0($t5)

    # Skip empty cells
    beq $t6, $zero, grab_find_next

    # Check currently held balls
    lw $t7, held_count
    beq $t7, $zero, grab_new_color

    lw $t8, held_color
    bne $t6, $t8, grab_done
    j grab_collect

grab_find_next:
    addi $t1, $t1, -1
    j grab_find

grab_new_color:
    sw $t6, held_color

grab_collect:
    # Check matching color
    bltz $t1, grab_done

    li $t3, 7
    mul $t4, $t1, $t3
    add $t4, $t4, $t0
    sll $t4, $t4, 2

    add $t5, $t2, $t4
    lw $t6, 0($t5)

    lw $t8, held_color
    bne $t6, $t8, grab_done

    # Empty the cell
    sw $zero, 0($t5)

    # Increase held_count
    lw $t7, held_count
    addi $t7, $t7, 1
    sw $t7, held_count

    # Move one row upward
    addi $t1, $t1, -1
    j grab_collect

grab_done:
    jr $ra
    
# -------------------------------------------------------------------

# Shift all rows down by one
# Generate new random top row

advance_row:
    la $t0, grid
    li $t1, 97

advance_loop:
    blt $t1, 7, advance_top

    # Destination address
    sll $t2, $t1, 2
    add $t3, $t0, $t2

    # Source = 7 cells above
    addi $t4, $t3, -28

    lw $t5, 0($t4)
    sw $t5, 0($t3)

    addi $t1, $t1, -1
    j advance_loop

advance_top:
    li $t1, 0

advance_random:
    bge $t1, 7, advance_done

    # Random value between 1 and 4
    li $v0, 42
    li $a0, 0
    li $a1, 4
    syscall

    addi $t2, $a0, 1

    # Store in top row
    la $t0, grid
    sll $t3, $t1, 2
    add $t4, $t0, $t3
    sw $t2, 0($t4)

    addi $t1, $t1, 1
    j advance_random

advance_done:
    jr $ra
    
# --------------------------------------------------------------

# Check if bottom row contains any ball
# Row 13 = indices 91 to 97

check_game_over:
    la $t0, grid
    li $t1, 91

game_over_loop:
    bge $t1, 98, game_over_safe

    sll $t2, $t1, 2
    add $t3, $t0, $t2

    lw $t4, 0($t3)

    # Nonzero means game over
    bne $t4, $zero, game_over

    addi $t1, $t1, 1
    j game_over_loop

game_over_safe:
    jr $ra

game_over:
    li $v0, 10
    syscall


# --------------------------------------------------------------------

# Check vertical matches in one column
# Input: $a0 = column (0-6)
# Clear runs of 3 or more matching balls

check_match:
    bltz $a0, match_done
    bge $a0, 7, match_done

    la $t0, grid
    li $t1, 0        # Current row
    li $t2, 0        # Previous color
    li $t3, 0        # Match count
    li $t4, 0        # Start row of run

match_loop:
    # Stop after row 13
    bge $t1, 14, match_finish

    # Calculate cell address
    li $t5, 7
    mul $t6, $t1, $t5
    add $t6, $t6, $a0
    sll $t6, $t6, 2
    add $t7, $t0, $t6

    # Read current color
    lw $t8, 0($t7)

    # Empty cell ends a run
    beq $t8, $zero, match_change

    # Same color as previous?
    beq $t8, $t2, match_same

match_change:
    # Save current row and color
    move $t9, $t1

    # Clear previous run if count >= 3
    bge $t3, 3, match_clear

match_continue:
    move $t2, $t8
    move $t4, $t9

    beq $t8, $zero, match_reset

    li $t3, 1
    j match_next

match_reset:
    li $t3, 0
    j match_next

match_same:
    addi $t3, $t3, 1
    j match_next

match_next:
    addi $t1, $t1, 1
    j match_loop

match_clear:
    # Clear run starting at $t4
    move $t5, $t4

clear_loop:
    bge $t5, $t9, clear_done

    li $t6, 7
    mul $t7, $t5, $t6
    add $t7, $t7, $a0
    sll $t7, $t7, 2
    add $t7, $t0, $t7

    sw $zero, 0($t7)

    addi $t5, $t5, 1
    j clear_loop

clear_done:
    j match_continue

match_finish:
    # Handle run ending at row 13
    blt $t3, 3, match_done

    move $t9, $t1
    move $t5, $t4

finish_clear:
    bge $t5, $t9, match_done

    li $t6, 7
    mul $t7, $t5, $t6
    add $t7, $t7, $a0
    sll $t7, $t7, 2
    add $t7, $t0, $t7

    sw $zero, 0($t7)

    addi $t5, $t5, 1
    j finish_clear

match_done:
    jr $ra
