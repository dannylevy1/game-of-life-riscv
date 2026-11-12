.section ".word"
   /* Game state memory locations */
  .equ CURR_STATE, 0x90001000       /* Current state of the game */
  .equ GSA_ID, 0x90001004           /* ID of the GSA holding the current state */
  .equ PAUSE, 0x90001008            /* Is the game paused or running */
  .equ SPEED, 0x9000100C            /* Current speed of the game */
  .equ CURR_STEP,  0x90001010       /* Current step of the game */
  .equ SEED, 0x90001014             /* Which seed was used to start the game */
  .equ GSA0, 0x90001018             /* Game State Array 0 starting address */
  .equ GSA1, 0x90001058             /* Game State Array 1 starting address */
  .equ CUSTOM_VAR_START, 0x90001200 /* Start of free range of addresses for custom vars */
  .equ CUSTOM_VAR_END, 0x90001300   /* End of free range of addresses for custom vars */
  .equ RANDOM, 0x40000000           /* Random number generator address */
  .equ LEDS, 0x50000000             /* LEDs address */
  .equ SEVEN_SEGS, 0x60000000       /* 7-segment display addresses */
  .equ BUTTONS, 0x70000004          /* Buttons address */

  /* States */
  .equ INIT, 0
  .equ RAND, 1
  .equ RUN, 2

  /* Colors (0bBGR) */
  .equ RED, 0x100
  .equ BLUE, 0x400

  /* Buttons */
  .equ JT, 0x10
  .equ JB, 0x8
  .equ JL, 0x4
  .equ JR, 0x2
  .equ JC, 0x1
  .equ BUTTON_2, 0x80
  .equ BUTTON_1, 0x20
  .equ BUTTON_0, 0x40

  /* LED selection */
  .equ ALL, 0xF

  /* Constants */
  .equ N_SEEDS, 4           /* Number of available seeds */
  .equ N_GSA_LINES, 10       /* Number of GSA lines */
  .equ N_GSA_COLUMNS, 12    /* Number of GSA columns */
  .equ MAX_SPEED, 10        /* Maximum speed */
  .equ MIN_SPEED, 1         /* Minimum speed */
  .equ PAUSED, 0x00         /* Game paused value */
  .equ RUNNING, 0x01        /* Game running value */

.section ".text.init"
  .globl main
  .globl _start

_start:
main:
  li sp, CUSTOM_VAR_END /* Set stack pointer, grows downwards */

main_reset:
  call reset_game
  call get_input

main_loop:
  mv s0, a0

  mv a0, s0
  call select_action

  mv a0, s0
  call update_state

  call update_gsa
  call clear_leds
  call mask
  call draw_gsa
  call wait
  call decrement_step
  bnez a0, main_reset

  call get_input
  j main_loop

/* BEGIN:auxiliary */
/* Place all auxiliary procedures and additional constants 
   that may be used by other procedures in this section */

/* END:auxiliary */

/* BEGIN:clear_leds */
clear_leds:
  li t0, LEDS
  li t1, 0x7FF              /* value=0, RGB selected, all rows/columns */
  sw t1, 0(t0)
  ret
/* END:clear_leds */

/* BEGIN:set_pixel */
set_pixel:
  li t0, 1
  slli t0, t0, 16           /* Pixel value */
  ori t0, t0, RED           /* Update the red component */
  slli t1, a1, 4
  or t0, t0, t1             /* Row */
  or t0, t0, a0             /* Column */
  li t1, LEDS
  sw t0, 0(t1)
  ret
/* END:set_pixel */

/* BEGIN:wait */
wait:
  li t0, SPEED
  lw t1, 0(t0)
  bgtz t1, wait_speed_ok
  li t1, MIN_SPEED
wait_speed_ok:
  li t0, 1024               /* Recommended base delay: 2^10 */
wait_loop:
  sub t0, t0, t1            /* Approximately 1024 / SPEED iterations */
  bgtz t0, wait_loop
  ret
/* END:wait */

/* BEGIN:set_gsa */
set_gsa:
  li t0, GSA_ID
  lw t0, 0(t0)
  slli t0, t0, 6            /* GSA1 is 64 bytes after GSA0 */
  li t1, GSA0
  add t1, t1, t0
  slli t0, a1, 2
  add t1, t1, t0
  sw a0, 0(t1)
  ret
/* END:set_gsa */

/* BEGIN:get_gsa */
get_gsa:
  li t0, GSA_ID
  lw t0, 0(t0)
  slli t0, t0, 6            /* GSA1 is 64 bytes after GSA0 */
  li t1, GSA0
  add t1, t1, t0
  slli a0, a0, 2
  add t1, t1, a0
  lw a0, 0(t1)
  ret
/* END:get_gsa */

/* BEGIN:draw_gsa */
draw_gsa:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw s0, 8(sp)

  li s0, 0                  /* y */
draw_gsa_row_loop:
  mv a0, s0
  call get_gsa

  li t0, 0xFFF             /* Only the 12 display columns are relevant */
  and a0, a0, t0
  slli t0, a0, 16          /* Complete red state of the current row */
  ori t0, t0, RED
  slli t1, s0, 4
  or t0, t0, t1
  ori t0, t0, ALL          /* Select every column of this row */
  li t1, LEDS
  sw t0, 0(t1)

  addi s0, s0, 1
  li t0, N_GSA_LINES
  blt s0, t0, draw_gsa_row_loop

  lw s0, 8(sp)
  lw ra, 12(sp)
  addi sp, sp, 16
  ret
/* END:draw_gsa */

/* BEGIN:random_gsa */
random_gsa:
  addi sp, sp, -32
  sw ra, 28(sp)
  sw s0, 24(sp)
  sw s1, 20(sp)
  sw s2, 16(sp)
  sw s3, 12(sp)

  li s0, 0                  /* y */
  li s3, RANDOM
random_gsa_row_loop:
  li s1, 0                  /* New row */
  li s2, 0                  /* x */
random_gsa_column_loop:
  lw t0, 0(s3)
  andi t0, t0, 1
  sll t0, t0, s2
  or s1, s1, t0
  addi s2, s2, 1
  li t0, N_GSA_COLUMNS
  blt s2, t0, random_gsa_column_loop

  mv a0, s1
  mv a1, s0
  call set_gsa
  addi s0, s0, 1
  li t0, N_GSA_LINES
  blt s0, t0, random_gsa_row_loop

  lw s3, 12(sp)
  lw s2, 16(sp)
  lw s1, 20(sp)
  lw s0, 24(sp)
  lw ra, 28(sp)
  addi sp, sp, 32
  ret
/* END:random_gsa */

/* BEGIN:change_speed */
change_speed:
  li t0, SPEED
  lw t1, 0(t0)
  bnez a0, change_speed_decrease

  li t2, MAX_SPEED
  bge t1, t2, change_speed_done
  addi t1, t1, 1
  j change_speed_store

change_speed_decrease:
  li t2, MIN_SPEED
  ble t1, t2, change_speed_done
  addi t1, t1, -1

change_speed_store:
  sw t1, 0(t0)
change_speed_done:
  ret
/* END:change_speed */

/* BEGIN:pause_game */
pause_game:
  li t0, PAUSE
  lw t1, 0(t0)
  xori t1, t1, 1
  sw t1, 0(t0)
  ret
/* END:pause_game */

/* BEGIN:change_steps */
change_steps:
  li t0, CURR_STEP
  lw t1, 0(t0)

  add t1, t1, a0           /* Units:    +1 when button 0 is pressed */
  slli t2, a1, 4
  add t1, t1, t2           /* Tens:    +16 when button 1 is pressed */
  slli t2, a2, 8
  add t1, t1, t2           /* Hundreds:+256 when button 2 is pressed */
  sw t1, 0(t0)
  ret
/* END:change_steps */

/* BEGIN:set_seed */
set_seed:
  addi sp, sp, -32
  sw ra, 28(sp)
  sw s0, 24(sp)
  sw s1, 20(sp)

  la t0, SEEDS
  slli t1, a0, 2
  add t0, t0, t1
  lw s0, 0(t0)              /* Address of selected seed */
  li s1, 0                  /* y */
set_seed_loop:
  lw a0, 0(s0)
  mv a1, s1
  call set_gsa
  addi s0, s0, 4
  addi s1, s1, 1
  li t0, N_GSA_LINES
  blt s1, t0, set_seed_loop

  lw s1, 20(sp)
  lw s0, 24(sp)
  lw ra, 28(sp)
  addi sp, sp, 32
  ret
/* END:set_seed */

/* BEGIN:increment_seed */
increment_seed:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw s0, 8(sp)

  li t0, SEED
  lw s0, 0(t0)
  li t1, N_SEEDS
  bge s0, t1, increment_seed_random

  addi s0, s0, 1
  sw s0, 0(t0)
  bge s0, t1, increment_seed_random
  mv a0, s0
  call set_seed
  j increment_seed_done

increment_seed_random:
  call random_gsa

increment_seed_done:
  lw s0, 8(sp)
  lw ra, 12(sp)
  addi sp, sp, 16
  ret
/* END:increment_seed */

/* BEGIN:update_state */
update_state:
  addi sp, sp, -16
  sw ra, 12(sp)

  li t0, CURR_STATE
  lw t1, 0(t0)
  li t2, RUN
  beq t1, t2, update_state_run

  andi t2, a0, JR
  bnez t2, update_state_start_run
  andi t2, a0, JC
  beqz t2, update_state_done
  li t2, SEED
  lw t2, 0(t2)
  li t3, N_SEEDS
  bne t2, t3, update_state_done
  li t1, RAND
  sw t1, 0(t0)
  j update_state_done

update_state_start_run:
  li t1, RUN
  sw t1, 0(t0)
  li t0, PAUSE
  li t1, RUNNING
  sw t1, 0(t0)
  j update_state_done

update_state_run:
  andi t2, a0, JB
  beqz t2, update_state_done
  call reset_game

update_state_done:
  lw ra, 12(sp)
  addi sp, sp, 16
  ret
/* END:update_state */

/* BEGIN:select_action */
select_action:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw s0, 8(sp)
  sw s1, 4(sp)

  mv s0, a0                 /* Buttons */
  li t0, CURR_STATE
  lw s1, 0(t0)
  li t0, RUN
  beq s1, t0, select_action_run

  andi t0, s0, JC
  beqz t0, select_action_steps
  li t0, RAND
  beq s1, t0, select_action_random_seed
  call increment_seed
  j select_action_steps

select_action_random_seed:
  call random_gsa

select_action_steps:
  andi t0, s0, BUTTON_0
  sltu a0, zero, t0
  andi t0, s0, BUTTON_1
  sltu a1, zero, t0
  andi t0, s0, BUTTON_2
  sltu a2, zero, t0
  or t0, a0, a1
  or t0, t0, a2
  beqz t0, select_action_done
  call change_steps
  j select_action_done

select_action_run:
  andi t0, s0, JC
  beqz t0, select_action_faster
  call pause_game

select_action_faster:
  andi t0, s0, JR
  beqz t0, select_action_slower
  li a0, 0
  call change_speed

select_action_slower:
  andi t0, s0, JL
  beqz t0, select_action_random
  li a0, 1
  call change_speed

select_action_random:
  andi t0, s0, JT
  beqz t0, select_action_done
  call random_gsa

select_action_done:
  lw s1, 4(sp)
  lw s0, 8(sp)
  lw ra, 12(sp)
  addi sp, sp, 16
  ret
/* END:select_action */

/* BEGIN:cell_fate */
cell_fate:
  li t0, 3
  beq a0, t0, cell_fate_alive
  li t0, 2
  bne a0, t0, cell_fate_dead
  andi a0, a1, 1
  ret
cell_fate_alive:
  li a0, 1
  ret
cell_fate_dead:
  li a0, 0
  ret
/* END:cell_fate */

/* BEGIN:find_neighbours */
find_neighbours:
  addi sp, sp, -32
  sw ra, 28(sp)
  sw s0, 24(sp)
  sw s1, 20(sp)
  sw s2, 16(sp)
  sw s3, 12(sp)
  sw s4, 8(sp)
  sw s5, 4(sp)

  mv s0, a0                 /* x */
  mv s1, a1                 /* y */
  li s2, -1                 /* dy */
  li s3, 0                  /* Number of neighbours */
  li s5, 0                  /* State of examined cell */

find_neighbours_row_loop:
  add t0, s1, s2
  bgez t0, find_neighbours_y_nonnegative
  li t1, N_GSA_LINES
  add t0, t0, t1            /* y - 1 wrapped from row 0 */
find_neighbours_y_nonnegative:
  li t1, N_GSA_LINES
  blt t0, t1, find_neighbours_y_ready
  addi t0, t0, -10
find_neighbours_y_ready:
  mv a0, t0
  call get_gsa
  mv s4, a0                 /* Row containing this dy */
  li t2, -1                 /* dx */

find_neighbours_column_loop:
  bnez s2, find_neighbours_not_center
  beqz t2, find_neighbours_center
find_neighbours_not_center:
  add t0, s0, t2
  bgez t0, find_neighbours_x_nonnegative
  li t1, N_GSA_COLUMNS
  add t0, t0, t1            /* x - 1 wrapped from column 0 */
find_neighbours_x_nonnegative:
  li t1, N_GSA_COLUMNS
  blt t0, t1, find_neighbours_x_ready
  addi t0, t0, -12
find_neighbours_x_ready:
  srl t1, s4, t0
  andi t1, t1, 1
  add s3, s3, t1
  j find_neighbours_next_column

find_neighbours_center:
  srl t1, s4, s0
  andi s5, t1, 1

find_neighbours_next_column:
  addi t2, t2, 1
  li t0, 2
  blt t2, t0, find_neighbours_column_loop
  addi s2, s2, 1
  li t0, 2
  blt s2, t0, find_neighbours_row_loop

  mv a0, s3
  mv a1, s5
  lw s5, 4(sp)
  lw s4, 8(sp)
  lw s3, 12(sp)
  lw s2, 16(sp)
  lw s1, 20(sp)
  lw s0, 24(sp)
  lw ra, 28(sp)
  addi sp, sp, 32
  ret
/* END:find_neighbours */

/* BEGIN:update_gsa */
update_gsa:
  li t0, PAUSE
  lw t0, 0(t0)
  beqz t0, update_gsa_return

  addi sp, sp, -32
  sw ra, 28(sp)
  sw s0, 24(sp)
  sw s1, 20(sp)
  sw s2, 16(sp)
  sw s3, 12(sp)
  sw s4, 8(sp)

  li t0, GSA_ID
  lw s0, 0(t0)              /* Current GSA ID */
  xori t1, s0, 1
  slli t1, t1, 6
  li s1, GSA0
  add s1, s1, t1            /* Address of next GSA */
  li s2, 0                  /* y */

update_gsa_row_loop:
  li s3, 0                  /* x */
  li s4, 0                  /* Next row bits */
update_gsa_column_loop:
  mv a0, s3
  mv a1, s2
  call find_neighbours
  call cell_fate
  beqz a0, update_gsa_dead_cell
  li t0, 1
  sll t0, t0, s3
  or s4, s4, t0
update_gsa_dead_cell:
  addi s3, s3, 1
  li t0, N_GSA_COLUMNS
  blt s3, t0, update_gsa_column_loop

  slli t0, s2, 2
  add t0, s1, t0
  sw s4, 0(t0)
  addi s2, s2, 1
  li t0, N_GSA_LINES
  blt s2, t0, update_gsa_row_loop

  xori s0, s0, 1
  li t0, GSA_ID
  sw s0, 0(t0)

  lw s4, 8(sp)
  lw s3, 12(sp)
  lw s2, 16(sp)
  lw s1, 20(sp)
  lw s0, 24(sp)
  lw ra, 28(sp)
  addi sp, sp, 32
update_gsa_return:
  ret
/* END:update_gsa */

/* BEGIN:get_input */
get_input:
  li t0, BUTTONS
  lw a0, 0(t0)
  sw zero, 0(t0)            /* Any write clears the complete register */
  ret
/* END:get_input */

/* BEGIN:decrement_step */
decrement_step:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw s0, 8(sp)

  li t0, CURR_STATE
  lw t1, 0(t0)
  li t2, RUN
  bne t1, t2, decrement_step_display
  li t0, PAUSE
  lw t1, 0(t0)
  beqz t1, decrement_step_paused

  li t0, CURR_STEP
  lw s0, 0(t0)
  beqz s0, decrement_step_finished
  addi s0, s0, -1
  sw s0, 0(t0)
  beqz s0, decrement_step_finished
  j decrement_step_render

decrement_step_display:
  li t0, CURR_STEP
  lw s0, 0(t0)

decrement_step_render:
  la t0, font_data
  li t1, 0                  /* Packed 7-segment word */
  li t2, 0                  /* Digit index */
decrement_step_digit_loop:
  andi t3, s0, 0xF
  slli t3, t3, 2
  add t3, t0, t3
  lw t3, 0(t3)
  slli t4, t2, 3
  sll t3, t3, t4
  or t1, t1, t3
  srli s0, s0, 4
  addi t2, t2, 1
  li t3, 4
  blt t2, t3, decrement_step_digit_loop
  li t0, SEVEN_SEGS
  sw t1, 0(t0)
  li a0, 0
  j decrement_step_done

decrement_step_finished:
  li a0, 1
  j decrement_step_done

decrement_step_paused:
  li a0, 0

decrement_step_done:
  lw s0, 8(sp)
  lw ra, 12(sp)
  addi sp, sp, 16
  ret
/* END:decrement_step */

/* BEGIN:reset_game */
reset_game:
  addi sp, sp, -16
  sw ra, 12(sp)
  sw s0, 8(sp)

  li t0, CURR_STEP
  li t1, 1
  sw t1, 0(t0)
  li t0, SEED
  sw zero, 0(t0)
  li t0, CURR_STATE
  sw zero, 0(t0)            /* INIT */
  li t0, GSA_ID
  sw zero, 0(t0)
  li t0, PAUSE
  sw zero, 0(t0)            /* PAUSED */
  li t0, SPEED
  li t1, MIN_SPEED
  sw t1, 0(t0)

  li a0, 0
  call set_seed
  call clear_leds
  call mask
  call draw_gsa

  li s0, 1
  la t0, font_data
  li t1, 0
  li t2, 0
reset_game_digit_loop:
  andi t3, s0, 0xF
  slli t3, t3, 2
  add t3, t0, t3
  lw t3, 0(t3)
  slli t4, t2, 3
  sll t3, t3, t4
  or t1, t1, t3
  srli s0, s0, 4
  addi t2, t2, 1
  li t3, 4
  blt t2, t3, reset_game_digit_loop
  li t0, SEVEN_SEGS
  sw t1, 0(t0)

  lw s0, 8(sp)
  lw ra, 12(sp)
  addi sp, sp, 16
  ret
/* END:reset_game */

/* BEGIN:mask */
mask:
  addi sp, sp, -32
  sw ra, 28(sp)
  sw s0, 24(sp)
  sw s1, 20(sp)
  sw s2, 16(sp)
  sw s3, 12(sp)

  li t0, SEED
  lw t1, 0(t0)
  li t0, N_SEEDS
  ble t1, t0, mask_seed_valid
  li t1, N_SEEDS           /* Invalid values use the random mask */
mask_seed_valid:
  la t0, MASKS
  slli t1, t1, 2
  add t0, t0, t1
  lw s0, 0(t0)             /* Selected mask address */
  li s1, 0                 /* y */
  li s3, 0xFFF

mask_row_loop:
  mv a0, s1
  call get_gsa
  lw s2, 0(s0)
  and a0, a0, s2
  mv a1, s1
  call set_gsa

  xor t0, s2, s3           /* Wall bits inside the 12-column display */
  slli t0, t0, 16
  ori t0, t0, BLUE
  slli t1, s1, 4
  or t0, t0, t1
  ori t0, t0, ALL
  li t1, LEDS
  sw t0, 0(t1)

  addi s0, s0, 4
  addi s1, s1, 1
  li t0, N_GSA_LINES
  blt s1, t0, mask_row_loop

  lw s3, 12(sp)
  lw s2, 16(sp)
  lw s1, 20(sp)
  lw s0, 24(sp)
  lw ra, 28(sp)
  addi sp, sp, 32
  ret
/* END:mask */

/* 7-segment display */
font_data:
  .word 0x3F
  .word 0x06
  .word 0x5B
  .word 0x4F
  .word 0x66
  .word 0x6D
  .word 0x7D
  .word 0x07
  .word 0x7F
  .word 0x6F
  .word 0x77
  .word 0x7C
  .word 0x39
  .word 0x5E
  .word 0x79
  .word 0x71

  seed0:
	.word 0xC00
	.word 0xC00
	.word 0x000
	.word 0x060
	.word 0x0A0
	.word 0x0C6
	.word 0x006
	.word 0x000
  .word 0x000
  .word 0x000

seed1:
	.word 0x000
	.word 0x000
	.word 0x05C
	.word 0x040
	.word 0x240
	.word 0x200
	.word 0x20E
	.word 0x000
  .word 0x000
  .word 0x000

seed2:
	.word 0x000
	.word 0x010
	.word 0x020
	.word 0x038
	.word 0x000
	.word 0x000
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000

seed3:
	.word 0x000
	.word 0x000
	.word 0x090
	.word 0x008
	.word 0x088
	.word 0x078
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000


# Predefined seeds
SEEDS:
  .word seed0
  .word seed1
  .word seed2
  .word seed3

mask0:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
  .word 0xFFF
  .word 0xFFF

mask1:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x1FF
	.word 0x1FF
	.word 0x1FF
  .word 0x1FF
  .word 0x1FF

mask2:
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
  .word 0x7FF
  .word 0x7FF

mask3:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

mask4:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

MASKS:
  .word mask0
  .word mask1
  .word mask2
  .word mask3
  .word mask4
