@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth initialisation and support code.
@

    .include "forth.inc"
    #include "version.h"

@   Register Usage:
@       r0-r4:      General purpose/scratch registers
@       r5:         Instruction register [I]
@       r6:         Return stack register [R]
@       r7:         Float stack register [F] 
@       r8:         Data stack register [S]
@       r9:         Reserved by RP2040 SDK (Platform register)
@       r10-r11:    Reserved for C compiler (Frame pointers)
@       r12:        IP (Intra-Procedure-call scratch)
@       r13:        SP (Stack pointer)
@       r14:        LR (Link register)
@       r15:        PC (Program counter)

@   Naming conventions:
@       LABEL:      Secondary word that completes with EXIT.
@       _label:     Primary word that completes with NEXT.
@       __label:    Internal routine where parameters and outputs
@.                  in r0-r3 and completes with bx lr or pop {..., pc}.



@
@   Interpreter bootstrap
@

    .section .rodata
    .balign 4
bootstrap:
    .word QUIT 
   
@
@   To get things going:
@
@   bootstrap <- r5
@   |
@   v
@   +--------+
@   | QUIT   |
@   +--------+
@
@   We load r5 to hold the address of the first execution token (QUIT) to execute,
@   which points to _quit. We are using indirect threaded code.
@
@   We use the macro NEXT to get started. The NEXT macro calls the interpreter or
@   hand-crafted code of the execution token in r5.
@
@   What NEXT does:  loads r0 with the execution token pointed to by r5 (QUIT)
@   and (since indirect) NEXT loads from r0 the address of the interpreter or
@   hand-crafted code:
@
@   +--------+
@   | QUIT   |
@   +-|------+
@     |
@     r0
@      |
@      +------------------------------------------------+
@                                                       |
@   +--------+--------+---+---+---+---+---+---+---+---+-v------+
@   | LOCATE | LINK   | 4 | Q | U | I | T | 0 | 0 | 0 | _quit  |
@   +--------+--------+---+---+---+---+---+---+---+---+--------+
@
@   and calls, in this case, the hand-crafted code, _quit.
@

    .text
    .balign 4

@
@   Forth System Initialisation
@

    .global forth_start
    .thumb_func
forth_start:
    @ print welcome message
    bl __type_welcome

    @ Bootstrap the interpreter
    movw r5, :lower16:bootstrap
    movt r5, :upper16:bootstrap
    NEXT                                @ run the interpreter!


    @   6.1.2050    QUIT ( -- ) ( R: i*x -- )
    @
    @   Empty the return stack, store zero in SOURCE-ID if it is present, make the user input device
    @   the input source, and enter interpretation state. Do not display a message. Repeat the
    @   following:
    @       - Accept a line from the input source into the input buffer, set >IN to zero, and interpret.
    @       - Display the implementation-defined system prompt if in interpretation state, all
    @         processing has been completed, and no ambiguous condition exists.

    .global _quit
    .thumb_func
_quit:
    @ Reset the stacks and variables
    movw r8, :lower16:data_stack_top
    movt r8, :upper16:data_stack_top    @ initialise the data stack pointer

    movw r7, :lower16:float_stack_top
    movt r7, :upper16:float_stack_top   @ initialise the float stack
    
    eor r0, r0
    ldr r1, =var_SOURCE_ID
    str r0, [r1]                        @ clear the source ID (0 = teminal input stream)
    ldr r1, =var_STATE
    str r0, [r1]                        @ clear the state variable (0 = interpreting, 1 = compiling)

0:  movw r6, :lower16:return_stack_top
    movt r6, :upper16:return_stack_top  @ initialise the return stack

1:  bl __refill                         @ refill the input stream
    cmp r0, #0                          @ check for input error
    beq 0b                              @ error, reset return stack and refill input stream

2:  bl __interpret                      @ process the input stream
    mov r4, r0                          @ r4 = the result of the interpretation (0 = no input, 1 = ok, -1 = error)
    bl __check_stacks                   @ check system status
    cmp r0, #ERR_OK                     @ check if there was an error
    bne 4f                              @ if there was an error, branch to error handling
    bl __key_available                  @ check if there is a user abort (if so, __key_available never returns)   
    cmp r4, #0                          @ check if buffer empty
    bne 2b

    ldr r1, =var_STATE
    ldr r0, [r1]                        @ load the state (0 = interpreting, 1 = compiling)
    cmp r0, #0                          @ check if we are interpreting or compiling
    beq 3f                              @ if interpreting, branch to ok prompt

    ldr r0, =compile_prompt
    bl __type_cstr                      @ print the compile prompt if compiling
    b 1b

3:  ldr r0, =ok_prompt
    bl __type_cstr                      @ print the ok prompt if interpreting
    b 1b

4:  bl __type_error                     @ emit the error message
    b _quit

ok_prompt:
    .asciz " ok\015\012"
compile_prompt:
    .asciz "\015\012  "
    .balign 4


@
@ No-op
@

    .global _noop
    .thumb_func
_noop:
    NEXT


@
@   Type the welcome message
@

    .global __type_welcome
    .thumb_func
__type_welcome:
    push {lr}
    ldr r0, =.Lmsg_welcome
    bl __type_cstr
    pop {pc}

.Lmsg_welcome:
    .ascii "\033cANS Forth for the Pico 2\n\r"
    .ascii "Copyright Blair Leduc.\n\r"
    .ascii "Version "
    .ascii PICO_ANS_FORTH_VERSION
    .asciz "\n\r"
    .balign 4


@
@   Type an error message
@

    .global __type_error
    .thumb_func
__type_error:
    push {r4, lr}
    mov r4, r0
    cmp r0, #0
    bge 2f                              @ if r0 is positive, it is an app throw code
    cmp r0, #-58
    bge 3f                              @ if r0 is -58 or greater, it is a standard throw code

    ldr r0, =.Lerror_sys
    bl __type_cstr

1:  mov r0, r4
    bl __dot
    ldr r0, =.Lerror_cr
    bl __type_cstr
    pop {r4, pc}
    
2:  ldr r0, =.Lerror_app
    bl __type_cstr
    b 1b

    // r0 in [-58, 0], index = -r0
3:  rsb r2, r0, #0
    ldr r3, =.Lerror_table
    ldr r3, [r3, r2, lsl #2]
    mov r0, r3
    bl __type_cstr
    pop {r4, pc}
    
    .section .rodata
    .balign 4
.Lerror_table:
    .word .Lerror_0, .Lerror_1, .Lerror_2, .Lerror_3, .Lerror_4
    .word .Lerror_5, .Lerror_6, .Lerror_7, .Lerror_8, .Lerror_9
    .word .Lerror_10, .Lerror_11, .Lerror_12, .Lerror_13, .Lerror_14
    .word .Lerror_15, .Lerror_16, .Lerror_17, .Lerror_18, .Lerror_19
    .word .Lerror_20, .Lerror_21, .Lerror_22, .Lerror_23, .Lerror_24
    .word .Lerror_25, .Lerror_26, .Lerror_27, .Lerror_28, .Lerror_29
    .word .Lerror_30, .Lerror_31, .Lerror_32, .Lerror_33, .Lerror_34
    .word .Lerror_35, .Lerror_36, .Lerror_37, .Lerror_38, .Lerror_39
    .word .Lerror_40, .Lerror_41, .Lerror_42, .Lerror_43, .Lerror_44
    .word .Lerror_45, .Lerror_46, .Lerror_47, .Lerror_48, .Lerror_49
    .word .Lerror_50, .Lerror_51, .Lerror_52, .Lerror_53, .Lerror_54
    .word .Lerror_55, .Lerror_56, .Lerror_57, .Lerror_58

.Lerror_0:    .asciz "No error\n\r"
.Lerror_1:    .asciz "ABORT\n\r"
.Lerror_2:    .asciz "ABORT with message\n\r"
.Lerror_3:    .asciz "Stack overflow\n\r"
.Lerror_4:    .asciz "Stack underflow\n\r"
.Lerror_5:    .asciz "Return stack overflow\n\r"
.Lerror_6:    .asciz "Return stack underflow\n\r"
.Lerror_7:    .asciz "Do-loops nested too deeply during execution\n\r"
.Lerror_8:    .asciz "Dictionary overflow\n\r"
.Lerror_9:    .asciz "Invalid memory address\n\r"
.Lerror_10:   .asciz "Division by zero\n\r"
.Lerror_11:   .asciz "Result out of range\n\r"
.Lerror_12:   .asciz "Argument type mismatch\n\r"
.Lerror_13:   .asciz "Undefined word\n\r"
.Lerror_14:   .asciz "Interpreting a compile-only word\n\r"
.Lerror_15:   .asciz "Invalid FORGET\n\r"
.Lerror_16:   .asciz "Attempt to use zero-length string as a name\n\r"
.Lerror_17:   .asciz "Pictured numeric output string overflow\n\r"
.Lerror_18:   .asciz "Parsed string overflow\n\r"
.Lerror_19:   .asciz "Definition name too long\n\r"
.Lerror_20:   .asciz "Write to a read-only location\n\r"
.Lerror_21:   .asciz "Unsupported operation\n\r"
.Lerror_22:   .asciz "Control structure mismatch\n\r"
.Lerror_23:   .asciz "Address alignment exception\n\r"
.Lerror_24:   .asciz "Invalid numeric argument\n\r"
.Lerror_25:   .asciz "Return stack imbalance\n\r"
.Lerror_26:   .asciz "Loop parameters unavailable\n\r"
.Lerror_27:   .asciz "Invalid recursion\n\r"
.Lerror_28:   .asciz "User interrupt\n\r"
.Lerror_29:   .asciz "Compiler nesting\n\r"
.Lerror_30:   .asciz "Obsolescent feature\n\r"
.Lerror_31:   .asciz ">BODY used on non-CREATEd definition\n\r"
.Lerror_32:   .asciz "Invalid name argument (e.g., TO xxx)\n\r"
.Lerror_33:   .asciz "Block read exception\n\r"
.Lerror_34:   .asciz "Block write exception\n\r"
.Lerror_35:   .asciz "Invalid block number\n\r"
.Lerror_36:   .asciz "Invalid file position\n\r"
.Lerror_37:   .asciz "File I/O exception\n\r"
.Lerror_38:   .asciz "Non-existent file\n\r"
.Lerror_39:   .asciz "Unexpected end of file\n\r"
.Lerror_40:   .asciz "Invalid BASE for floating point conversion\n\r"
.Lerror_41:   .asciz "Loss of precision\n\r"
.Lerror_42:   .asciz "Floating-point divide by zero\n\r"
.Lerror_43:   .asciz "Floating-point result out of range\n\r"
.Lerror_44:   .asciz "Floating-point stack overflow\n\r"
.Lerror_45:   .asciz "Floating-point stack underflow\n\r"
.Lerror_46:   .asciz "Floating-point invalid argument\n\r"
.Lerror_47:   .asciz "Compilation word list deleted\n\r"
.Lerror_48:   .asciz "Invalid POSTPONE\n\r"
.Lerror_49:   .asciz "Search-order overflow\n\r"
.Lerror_50:   .asciz "Search-order underflow\n\r"
.Lerror_51:   .asciz "Compilation word list changed\n\r"
.Lerror_52:   .asciz "Control-flow stack overflow\n\r"
.Lerror_53:   .asciz "Exception stack overflow\n\r"
.Lerror_54:   .asciz "Floating-point underflow\n\r"
.Lerror_55:   .asciz "Floating-point unidentified fault\n\r"
.Lerror_56:   .asciz "QUIT\n\r"
.Lerror_57:   .asciz "Exception in sending or receiving a character\n\r"
.Lerror_58:   .asciz "[IF], [ELSE], or [THEN] exception\n\r"
.Lerror_app:  .asciz "Application exception: "
.Lerror_sys:  .asciz "Unknown system exception: "
.Lerror_cr:   .asciz "\n\r"
