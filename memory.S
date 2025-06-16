@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@

    .include "forth.inc"

@
@   Data Reservations
@

    .data

    @ Forth data stack
    .balign 4
    .space 8                            @ reserve space for the bottom of the stack pointer in case of overflow   
    .global data_stack, data_stack_top
data_stack:
    .space DATA_STACK_SIZE
data_stack_top:                         @ initial top of data stack
    .space 8                            @ reserve space for the top of the stack pointer in case of underflow   

    @ Forth return stack
    .balign 4
    .space 8                            @ reserve space for the bottom of the stack pointer in case of overflow   
    .global return_stack, return_stack_top
return_stack:
    .space RETURN_STACK_SIZE
return_stack_top:                       @ initial top of return stacki
    .space 8                            @ reserve space for the top of the stack pointer in case of underflow

    @ Forth float stack
    .balign 4
    .space 8                            @ reserve space for the bottom of the stack pointer in case of overflow   
    .global float_stack, float_stack_top
float_stack:
    .space FLOAT_STACK_SIZE
float_stack_top:                        @ initial top of float stack
    .space 8                            @ reserve space for the top of the stack pointer in case of underflow

    @ Forth data space
    .balign 4
    .global data_space, data_space_top
data_space:
    .space DATA_SPACE_SIZE
data_space_top:                      @ bottom of data space
    .space 8                            @ reserve space for the bottom of the data space pointer in case of overflow

    @ Forth Pad Storage
    .balign 4
    .global pad_storage
pad_storage:
    .space PAD_SIZE

    @ Forth Terminal input buffer
    .balign 4
    .global terminal_input_buffer
terminal_input_buffer:
    .space TERMINAL_INPUT_BUFFER_SIZE   @ reserve bytes for the terminal input buffer

    @ Forth s-quoted string buffer
    .balign 4
    .global s_quoted_string_buffer
s_quoted_string_buffer:
    .space S_QUOTED_STRING_BUFFER_SIZE  @ reserve bytes for the s-quoted string buffer
