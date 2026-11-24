################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Syaikha Faiza Arifin, 1011987236
# Student 2: Elodie Fan, 1010983848
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       4
# - Unit height in pixels:      4
# - Display width in pixels:    256
# - Display height in pixels:   512
# - Base Address for Display:   0x10008000
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display.
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard.
ADDR_KBRD:
    .word 0xffff0000

##############################################################################
# Mutable Data
##############################################################################

# Every cell is one word: 0=empty; 1=red; 2=blue; 3=yellow; 4=green.
# Row 0 is at the top; column 0 at the left.
grid:           .space 392              # 7 * 14 * 4 bytes
player_col:      .word 3                # Middle column (0..6)
held_color: .word 0    # Colour of the bubbles being held
held_count: .word 0    # Number of bubbles being held
key_counter: .word 0   # Number of gameplay keystrokes
colors:          .word 0x00000000       # 0: empty
                 .word 0x00ee5555       # 1: red
                 .word 0x005d9cec       # 2: blue
                 .word 0x00f4ca49       # 3: yellow
                 .word 0x004aca83       # 4: green

##############################################################################
# Code
##############################################################################
    .text
	.globl main

    # Run the game.
main:
    # Initialize the game
    jal init_grid             
    jal clear_screen
    jal draw_grid
    jal draw_bubbles
    jal draw_player
    jal draw_held_bubbles

game_loop:
    # 1a. Check if a key has been pressed
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)              # Keyboard status
    andi $t1, $t1, 1           # Check ready bit
    beq $t1, $zero, loop_sleep

    # 1b. Check which key has been pressed
    lw $t2, 4($t0)             # Read key

    li $t3, 0x61               # 'a' = move left
    beq $t2, $t3, move_left

    li $t3, 0x64               # 'd' = move right
    beq $t2, $t3, move_right

    li $t3, 0x73               # 's' = grab bubbles
    beq $t2, $t3, grab_input
    
    li $t3, 0x77               # 'w' = throw bubbles
    beq $t2, $t3, throw_input

    li $t3, 0x71               # 'q' = quit game
    beq $t2, $t3, quit_game

    j loop_sleep               # Ignore other keys


move_left:
    # 2a. Check the left boundary
    lw $t3, player_col
    beq $t3, $zero, count_key

    # 2b. Erase the old player and update position
    jal clear_player_area

    lw $t3, player_col
    addiu $t3, $t3, -1
    sw $t3, player_col

    # Draw the player in the new position
    jal draw_player
    jal draw_held_bubbles
    j count_key


move_right:
    # 2a. Check the right boundary
    lw $t3, player_col
    li $t4, 6
    beq $t3, $t4, count_key

    # 2b. Erase the old player and update position
    jal clear_player_area

    lw $t3, player_col
    addiu $t3, $t3, 1
    sw $t3, player_col

    # Draw the player in the new position
    jal draw_player
    jal draw_held_bubbles
    j count_key

grab_input:
    # 2c. Grab matching bubbles from the current column
    jal grab_ball

    # Count the grab as one gameplay keystroke
    lw $t3, key_counter
    addiu $t3, $t3, 1
    sw $t3, key_counter

    # Redraw the board after grabbing
    li $t4, 10
    blt $t3, $t4, redraw_game
    j update_game
    
throw_input:
    jal throw_ball

    # If nothing was thrown, skip matching
    beq $v0, $zero, count_key

    lw $a0, player_col      
    jal check_match

    jal refresh_after_throw
    jal check_game_over

    j count_key

count_key:
    # 2d. Count gameplay keystrokes
    lw $t3, key_counter
    addiu $t3, $t3, 1
    sw $t3, key_counter
    j update_game


update_game:
    # 3a. Advance rows after approximately 10 gameplay keys
    lw $t3, key_counter
    li $t4, 10
    blt $t3, $t4, loop_sleep

    # Reset the counter and advance the board
    sw $zero, key_counter
    jal advance_row

    # 3b. Check whether the bubbles have reached the bottom
    jal check_game_over

    # Refresh the board bubbles after advancing
    j redraw_game                 

redraw_game:
    # 4. Draw the screen
    jal draw_bubbles
    jal draw_player
    jal draw_held_bubbles
    # We don't redraw the entire grid or clear entire screen


loop_sleep:
    # 5. Sleep approximately 16 ms
    li $v0, 32
    li $a0, 16
    syscall

    # 6. Repeat the game loop
    j game_loop


quit_game:
    # Exit the game
    li $v0, 10
    syscall

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
# get_cell(a0, a1)
# Get value of a cell
# Input:  $a0 = row (row start from row 0, row 1, etc), $a1 = column (start from 0)
# Output: $v0 = cell value
#---------------------------------------------------- 

get_cell:
    li $t0, 7
    mul $t1, $a0, $t0
    add $t1, $t1, $a1
    sll $t1, $t1, 2

    la $t0, grid
    add $t0, $t0, $t1

    lw $v0, 0($t0)
    jr $ra

#----------------------------------------------------   
# set_cell(a0, a1, a2)
# Set value of a cell
# Input: $a0 = row, $a1 = column
#        $a2 = new cell value
#---------------------------------------------------- 

set_cell:
    li $t0, 7
    mul $t1, $a0, $t0
    add $t1, $t1, $a1
    sll $t1, $t1, 2

    la $t0, grid
    add $t0, $t0, $t1

    sw $a2, 0($t0)
    jr $ra

# -----------------------------------------------------------------------------
# draw_unit(x, y, color)
# Input: $a0 = x bitmap unit, $a1 = y bitmap unit, $a2 = 0x00RRGGBB
# Screen has 64 units per row, and each unit occupies 4 bytes.
# Address = 0x10008000 + 4 * (y * 64 + x)
# Uses temporary registers $t0 and $t1.
# -----------------------------------------------------------------------------
draw_unit:
    sll $t0, $a1, 6                 # $t0 = y * 64
    addu $t0, $t0, $a0              # $t0 = y * 64 + x
    sll $t0, $t0, 2                 # $t0 = byte offset
    lw $t1, ADDR_DSPL
    addu $t1, $t1, $t0
    sw $a2, 0($t1)
    jr $ra


# -----------------------------------------------------------------------------
# clear_screen: set all 64*128 bitmap units to black.
# -----------------------------------------------------------------------------
clear_screen:
    lw $t0, ADDR_DSPL
    li $t1, 8192                    # 64 * 128 units
clear_loop:
    beq $t1, $zero, clear_done
    sw $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    j clear_loop
clear_done:
    jr $ra


# -----------------------------------------------------------------------------
# draw_grid: 7 columns, 14 rows, each 8x8 bitmap units.
# Draw vertical grid lines at x = 4, 12, 20, ..., 60 (y = 2..114).
# Draw horizontal lines at y = 2, 10, 18, ..., 114 (x = 4..60).
# -----------------------------------------------------------------------------
draw_grid:
    addiu $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    li $s0, 4                       # current x line
vertical_line_loop:
    slti $t0, $s0, 61                # while x <= 60
    beq $t0, $zero, horizontal_start
    li $s1, 2                       # current y within this line
vertical_point_loop:
    slti $t0, $s1, 115                # while y <= 114
    beq $t0, $zero, vertical_next
    move $a0, $s0
    move $a1, $s1
    li $a2, 0x003a4759              # blue-gray grid lines
    jal draw_unit
    addiu $s1, $s1, 1
    j vertical_point_loop
vertical_next:
    addiu $s0, $s0, 8
    j vertical_line_loop

horizontal_start:
    li $s1, 2                       # current y line
horizontal_line_loop:
    slti $t0, $s1, 115              # while y <= 114
    beq $t0, $zero, grid_done
    li $s0, 4                       # current x within this line
horizontal_point_loop:
    slti $t0, $s0, 61                # while x <= 60
    beq $t0, $zero, horizontal_next
    move $a0, $s0
    move $a1, $s1
    li $a2, 0x003a4759
    jal draw_unit
    addiu $s0, $s0, 1
    j horizontal_point_loop
horizontal_next:
    addiu $s1, $s1, 8
    j horizontal_line_loop

grid_done:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addiu $sp, $sp, 12
    jr $ra


# -----------------------------------------------------------------------------
# Upper-left grid line for this cell:
# x = 4 + 8*col; y = 2 + 8*row.
# -----------------------------------------------------------------------------
draw_bubbles:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)

    li $s0, 0                       # row
bubble_row_loop:
    slti $t0, $s0, 14
    beq $t0, $zero, bubbles_done
    li $s1, 0                       # column
bubble_col_loop:
    slti $t0, $s1, 7
    beq $t0, $zero, bubble_next_row

    # Index = 7*row + col; use 7*row = 8*row - row.
    sll $t0, $s0, 3
    subu $t0, $t0, $s0
    addu $t0, $t0, $s1
    sll $t0, $t0, 2                 # word byte offset
    la $t1, grid
    addu $t1, $t1, $t0
    lw $s2, 0($t1)                 # $s2 has the colour number (0..4)
    # find the cell and load its value into $s2

    # If a bubble exists, draw over its previous image; check if it has bubble
    # If $s2 isn't zero, jump to bubble_has_color because a bubble should exist in that cell
    bne $s2, $zero, bubble_has_color

    # Clear the cell only when it is empty
    sll $a0, $s1, 3
    addiu $a0, $a0, 5
    sll $a1, $s0, 3
    addiu $a1, $a1, 3
    jal clear_cell_interior

    # Move to the next cell
    j bubble_next_col

bubble_has_color:
    # Draw the bubble without clearing it first
    slti $t0, $s2, 5
    beq $t0, $zero, bubble_next_col # ignore invalid colours >=5
    slt $t0, $s2, $zero
    bne $t0, $zero, bubble_next_col # ignore invalid colours <0

    # Convert the colour number to an actual 0x00RRGGBB value.
    sll $t0, $s2, 2
    la $t1, colors
    addu $t1, $t1, $t0
    lw $a2, 0($t1)

    # Upper-left grid line for this cell:
    # x = 4 + 8*col; y = 2 + 8*row.
    sll $a0, $s1, 3
    addiu $a0, $a0, 4
    sll $a1, $s0, 3
    addiu $a1, $a1, 2
    jal draw_bubble_cell
    # Doesn't erase the bubble first 

bubble_next_col:
    addiu $s1, $s1, 1
    j bubble_col_loop
bubble_next_row:
    addiu $s0, $s0, 1
    j bubble_row_loop

bubbles_done:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra


# -----------------------------------------------------------------------------
# draw_bubble_cell: draw a round pixel-art bubble inside an 8x8 cell.
# Inputs: $a0 = grid-cell upper-left x, $a1 = upper-left y,
#         $a2 = RGB colour.
# Draws a circular pattern using a 7x7 area.
# The pattern is:
#   0011100
#   0111110
#   1111111
#   1111111
#   1111111
#   0111110
#   0011100
# -----------------------------------------------------------------------------
draw_bubble_cell:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)

    move $s0, $a0
    move $s1, $a1
    move $s2, $a2

    li $s3, 0

circle_row_loop:
    slti $t2, $s3, 7
    beq $t2, $zero, circle_done
    li $s4, 0

circle_col_loop:
    slti $t2, $s4, 7
    beq $t2, $zero, circle_next_row

    beq $s3, $zero, circle_narrow
    li $t2, 6
    beq $s3, $t2, circle_narrow

    li $t2, 1
    beq $s3, $t2, circle_medium
    li $t2, 5
    beq $s3, $t2, circle_medium

    j circle_draw

circle_narrow:
    slti $t2, $s4, 2
    bne $t2, $zero, circle_skip
    slti $t2, $s4, 5
    beq $t2, $zero, circle_skip
    j circle_draw

circle_medium:
    beq $s4, $zero, circle_skip
    li $t2, 6
    beq $s4, $t2, circle_skip

circle_draw:
    addu $a0, $s0, $s4
    addiu $a0, $a0, 1

    addu $a1, $s1, $s3
    addiu $a1, $a1, 1

    move $a2, $s2
    jal draw_unit

circle_skip:
    addiu $s4, $s4, 1
    j circle_col_loop

circle_next_row:
    addiu $s3, $s3, 1
    j circle_row_loop

circle_done:
    lw $s4, 0($sp)
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra


# -----------------------------------------------------------------------------
# draw_player: simple 5-unit-wide sprite below the board.
# Player column is stored separately, not within the board array.
# Player center x = 8 + 8*player_col; y coordinates = 120..123.
# -----------------------------------------------------------------------------
draw_player:
    addiu $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    lw $t0, player_col
    sll $s0, $t0, 3
    addiu $s0, $s0, 8              # x center

    # Head: one light-yellow unit at y = 120.
    move $a0, $s0
    li $a1, 120
    li $a2, 0x00ffe0a8
    jal draw_unit

    # Torso: 3 cyan units at y = 121.
    addiu $s1, $s0, -1

player_torso_loop:
    addiu $t0, $s0, 2
    slt $t1, $s1, $t0
    beq $t1, $zero, player_arms
    move $a0, $s1
    li $a1, 121
    li $a2, 0x0000c8ff
    jal draw_unit
    addiu $s1, $s1, 1
    j player_torso_loop

player_arms:
    addiu $a0, $s0, -2             # left arm
    li $a1, 122
    li $a2, 0x0000c8ff
    jal draw_unit
    move $a0, $s0                  # middle body
    li $a1, 122
    li $a2, 0x0000c8ff
    jal draw_unit
    addiu $a0, $s0, 2              # right arm
    li $a1, 122
    li $a2, 0x0000c8ff
    jal draw_unit

    addiu $a0, $s0, -1             # left foot
    li $a1, 123
    li $a2, 0x00ffffff
    jal draw_unit
    addiu $a0, $s0, 1              # right foot
    li $a1, 123
    li $a2, 0x00ffffff
    jal draw_unit

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addiu $sp, $sp, 12
    jr $ra

# -----------------------------------------------------------------------------
# clear_player_area: erase the old player and held-bubble markers.
# Only clears a small area below the grid to reduce flickering.
# -----------------------------------------------------------------------------
clear_player_area:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)

    # Find the current player's center x-coordinate
    lw $t0, player_col
    sll $s0, $t0, 3
    addiu $s0, $s0, 8

    # Start at the top of the player area
    li $s1, 116

clear_player_row:
    # Stop after y = 123
    bge $s1, 124, clear_player_done

    # Begin three units to the left of the player center
    addiu $s2, $s0, -3

clear_player_col:
    # Stop after three units to the right
    addiu $t0, $s0, 4
    bge $s2, $t0, clear_player_next_row

    # Set this bitmap unit to black
    move $a0, $s2
    move $a1, $s1
    move $a2, $zero
    jal draw_unit

    addiu $s2, $s2, 1
    j clear_player_col

clear_player_next_row:
    addiu $s1, $s1, 1
    j clear_player_row

clear_player_done:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

# -----------------------------------------------------------------------------
# clear_cell_interior: clear the 7x7 interior of one grid cell.
# Input: $a0 = interior x, $a1 = interior y
# -----------------------------------------------------------------------------
clear_cell_interior:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)

    move $s0, $a0
    move $s1, $a1
    li $s2, 0

clear_cell_row:
    bge $s2, 7, clear_cell_done
    li $t2, 0

clear_cell_col:
    bge $t2, 7, clear_cell_next_row

    addu $a0, $s0, $t2
    addu $a1, $s1, $s2
    move $a2, $zero
    jal draw_unit

    addiu $t2, $t2, 1
    j clear_cell_col

clear_cell_next_row:
    addiu $s2, $s2, 1
    j clear_cell_row

clear_cell_done:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
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

# -----------------------------------------------------------------------------
# draw_held_bubbles: show the bubbles the player is holding.
# Each held bubble is represented by a small coloured marker.
# Markers appear above the player, below the grid.
# Displays up to 14 markers in two rows.
# -----------------------------------------------------------------------------
draw_held_bubbles:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)

    # Check how many bubbles the player is holding
    lw $s1, held_count
    blez $s1, held_done

    # Get the colour of the held bubbles
    lw $t0, held_color
    blez $t0, held_done
    li $t1, 5
    bge $t0, $t1, held_done

    # Convert colour number into an RGB value
    sll $t0, $t0, 2
    la $t1, colors
    addu $t1, $t1, $t0
    lw $s2, 0($t1)

    # Find the player's horizontal position
    lw $t0, player_col
    sll $s0, $t0, 3
    addiu $s0, $s0, 8

    # Start drawing from the first marker
    li $s3, 0

held_draw_loop:
    # Stop after drawing all held bubbles
    bge $s3, $s1, held_done

    # Only 14 markers fit in this display area
    li $t0, 14
    bge $s3, $t0, held_done

    # First 7 markers are on y = 116
    # Next 7 markers are on y = 118
    li $t0, 7
    blt $s3, $t0, held_first_row

    # Second row: marker index - 7
    addiu $s4, $s3, -7
    li $a1, 118
    j held_draw_marker

held_first_row:
    move $s4, $s3
    li $a1, 116

held_draw_marker:
    # x = player center - 3 + marker index
    addiu $a0, $s0, -3
    addu $a0, $a0, $s4

    # Draw the marker using the held bubble colour
    move $a2, $s2
    jal draw_unit

    # Move to the next held bubble
    addiu $s3, $s3, 1
    j held_draw_loop

held_done:
    # Restore saved registers
    lw $s4, 0($sp)
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
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
    # Draw the final board before ending the game
    jal clear_screen
    jal draw_grid
    jal draw_bubbles
    jal draw_player
    jal draw_held_bubbles

    # Keep the final board visible for 2 seconds
    li $v0, 32
    li $a0, 2000
    syscall

    # End the game
    li $v0, 10
    syscall

# -----------------------------------------------------------------------------
# check_match
# Input: $a0 = column (0..6)
# Clears the bottommost consecutive same-colour group if it contains 3 or more bubbles.
# -----------------------------------------------------------------------------
check_match:
    bltz $a0, match_done
    bge $a0, 7, match_done

    la $t0, grid
    li $t1, 13        # current row
    li $t2, 0        # previous color
    li $t3, 0        # match count
    li $t4, 0        # start row of current run

# Find the bottommost occupied cell
match_find_bottom:
    bltz $t1, match_done

    li $t5, 7
    mul $t6, $t1, $t5
    add $t6, $t6, $a0
    sll $t6, $t6, 2
    add $t7, $t0, $t6
    lw $t8, 0($t7)

    bne $t8, $zero, match_find_start

    addiu $t1, $t1, -1
    j match_find_bottom

# Find the beginning of the same-colour group
match_find_start:
    move $t2, $t8

match_find_up:
    addiu $t1, $t1, -1
    bltz $t1, match_start

    addiu $t7, $t7, -28
    lw $t8, 0($t7)

    beq $t8, $t2, match_find_up

match_start:
    addiu $t1, $t1, 1
    move $t4, $t1
    li $t2, 0

match_loop:
    # stop after row 13
    bge $t1, 14, match_finish

    # calculate cell address
    li $t5, 7
    mul $t6, $t1, $t5
    add $t6, $t6, $a0
    sll $t6, $t6, 2
    add $t7, $t0, $t6

    # read current color
    lw $t8, 0($t7)

    # empty cell ends a run
    beq $t8, $zero, match_change

    # same color as previous?
    beq $t8, $t2, match_same

match_change:
    # save current row
    move $t9, $t1

    # clear previous run if count >= 3
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
    # clear run starting at row $t4 and ending before row $t9
    move $t5, $t4

match_clear_loop:
    bge $t5, $t9, match_clear_done

    li $t6, 7
    mul $t7, $t5, $t6
    add $t7, $t7, $a0
    sll $t7, $t7, 2
    add $t7, $t0, $t7

    sw $zero, 0($t7)

    addi $t5, $t5, 1
    j match_clear_loop

match_clear_done:
    j match_done

match_finish:
    # handle run ending at row 13
    blt $t3, 3, match_done

    move $t9, $t1
    move $t5, $t4

match_finish_clear:
    bge $t5, $t9, match_done

    li $t6, 7
    mul $t7, $t5, $t6
    add $t7, $t7, $a0
    sll $t7, $t7, 2
    add $t7, $t0, $t7

    sw $zero, 0($t7)

    addi $t5, $t5, 1
    j match_finish_clear

match_done:
    jr $ra

# --------------------------------------------------------------
# Refresh the display after a throw.
# The game logic updates the grid and held_count beforehand.
# --------------------------------------------------------------

refresh_after_throw:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    # Remove the old held-bubble markers
    jal clear_player_area

    # Draw the updated board
    jal draw_bubbles

    # Draw the player and remaining held bubbles
    jal draw_player
    jal draw_held_bubbles

    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra


# --------------------------------------------------------------
# throw_ball
# Throw held bubbles into the current player column.
# Output: $v0 = 1 if successful, 0 otherwise
# --------------------------------------------------------------

throw_ball:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)

    # Get player position and held bubbles
    lw $s0, player_col
    lw $s1, held_count
    lw $s2, held_color

    # Cannot throw if no bubbles are held
    beq $s1, $zero, throw_failed

    # Start searching from the bottom row
    li $s3, 13

throw_find:
    bltz $s3, throw_empty_column

    # Get the current cell value
    move $a0, $s3
    move $a1, $s0
    jal get_cell

    # Stop if an occupied cell is found
    bne $v0, $zero, throw_found

    # Otherwise, move one row upward
    addiu $s3, $s3, -1
    j throw_find

throw_found:
    # Place bubbles below the existing bubble
    addiu $s3, $s3, 1
    j throw_check_space

throw_empty_column:
    # If the column is empty, start at row 0
    li $s3, 0

throw_check_space:
    # Calculate the number of available cells
    li $t0, 14
    subu $t0, $t0, $s3

    # Cancel if the held bubbles do not fit
    bgt $s1, $t0, throw_failed

    # Number of bubbles thrown so far
    li $s4, 0

throw_place_loop:
    # Stop after placing all held bubbles
    bge $s4, $s1, throw_success

    # set_cell(row, column, color)
    move $a0, $s3
    move $a1, $s0
    move $a2, $s2
    jal set_cell

    # Move down to the next available row
    addiu $s3, $s3, 1

    # Increase the number of thrown bubbles
    addiu $s4, $s4, 1

    j throw_place_loop

throw_success:
    # Player is no longer holding any bubbles
    sw $zero, held_count
    sw $zero, held_color

    li $v0, 1
    j throw_done

throw_failed:
    li $v0, 0

throw_done:
    lw $s4, 0($sp)
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24

    jr $ra