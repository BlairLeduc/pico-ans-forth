@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains common definitions and macros used by the assembler.
@

    .syntax unified
    .cpu cortex-m33

    @ Define the initial size of the stacks and storage space.
    .set DATA_STACK_SIZE, 512           @ 128 cells for the data stack
    .set RETURN_STACK_SIZE, 512         @ 128 cells for the return stack
    .set FLOAT_STACK_SIZE, 512          @ 128 cells for the float stack
    .set PAD_SIZE, 128                  @ 128 bytes for the scratch PAD
    .set DATA_SPACE_SIZE, 393216        @ 384K (TODO: how do we get an accurate value?) for data space
    .set TERMINAL_INPUT_BUFFER_SIZE, 80 @ 80 bytes is standard for the terminal input buffer
    .set S_QUOTED_STRING_BUFFER_SIZE, 80 @ 80 bytes for the S" quoted string buffer

    @ Output formatting (80 characters per line, 16 bytes per row in dump)
@    .equ CPL, 80                        @ characters per line
@    .equ BPR, 16                        @ bytes per row in dump

@    @ Output formatting (40 characters per line, 4 bytes per row in dump)
    .equ CPL, 40                        @ characters per line
    .equ BPR, 4                         @ bytes per row in dump

@
@   The NEXT macro is used to execute the next instruction stored in the word's data fields.
@
@   We use indirect threaded code that is excuted using the DOCOL interpreter. The DOCOL interpreter
@   executes each execution token stored in the data fields of the word.
@

    .macro NEXT
    ldr r0, [r5], #4                    @ r5 points to the next instruction
    ldr r1, [r0]                        @ get the interpreter address stored in the execution token (indirect)
    orr r1, #1                          @ set the thumb bit (make sure we stay in thumb mode)
    blx r1                              @ branch to the interpreter/hand-crafted code
    .endm

@
@   Stack Macros
@
@   These macros are used to manipulate the data stack, return stack and floating point stack.
@

@   The data stack (r8) is used to store data values.
    .macro pushd reg
    str \reg, [r8, #-4]!                @ push reg on to data stack
    .endm

    .macro popd reg
    ldr \reg, [r8], #4                  @ pop reg from data stack
    .endm

@   The return stack (r6) is used to store return addresses for function calls.
    .macro pushr reg
    str \reg, [r6, #-4]!                @ push reg on to return stack
    .endm

    .macro popr reg
    ldr \reg, [r6], #4                  @ pop reg from return stack
    .endm

@   The floating point stack (r7) is used to store floating point values.
    .macro pushf reg
    str \reg, [r7, #-4]!                @ push reg on to floating point stack
    .endm

    .macro popf reg
    ldr \reg, [r7], #4                  @ pop reg from floating point stack
    .endm

@
@   1.1.2 Dictionary
@
@   Control bits (FPH, p6)
@

    .equ CB_PRECEDENCE, 0x80            @ precedence or immediate bit
    .equ CB_SMUDGE,     0x20            @ smudge  or hiddent bit
    .equ CB_LENGTH,     0x1f            @ remove the control bits

@
@   Dictionary Macros
@
@   These macros are used to define words in flash that appear in the dictionary.
@

@
@   Create a "compiled" (DOCOL) definition for a word in the dictionary.
@
@   This dictionary definition is stored in the .section .rodata section, which is read-only.
@   The code field points to the DOCOL interpreter.
@
@   Example: : DOUBLE DUP + ;
@                                                               first execution token in definition
@   +--------+--------+---+---+---+---+---+---+---+---+--------+-|------+--------+--------+
@   | LOCATE | LINK   | 6 | D | O | U | B | L | E | 0 | DOCOL  | DUP    | +      | EXIT   |
@   +--------+--------+---+---+---+---+---+---+---+---+-|------+--------+--------+--------+
@                                                      points to the DOCOL interpreter.

    .macro defword name, control=0, label
    .section .rodata
    .balign 4                           @ make sure we are on a 4 byte boundary
    .word 0                             @ locate
1:
    .word link                          @ link
    .byte 3f - 2f + \control            @ control bits + length byte
2:
    .ascii "\name"                      @ the name
3:
    .balign 4                           @ pad with 0's to next 4 byte boundary
    .global \label
\label:                                 @ CFA for the word
    .word _docol                        @ code field - points to the DOCOL interpreter

    .set link, 1b
    @ list of word pointers follow (each point to the CFA of the word)
    .endm


@
@   Create a code definition for a word in the dictionary.
@
@   This dictionary definition is stored in the .section .rodata section, which is read-only.
@   The code field points to the assembly code that implements the behaviour of the word
@   which is stored in the .text section.
@
@   **NOTE**: This dictionary entry structure is only created for words that have
@             hand-crafted code, which are these that are baked into the flash memory.
@             The text interpreter will never create this structure at runtime.
@
@   Example: DUP
@
@   +--------+---------+---+---+---+---+--------+
@   | LOCATE | LINK    | 3 | D | U | P | _dup   |
@   +--------+---------+---+---+---+---+-|------+
@                                      points to the assembly code used to write DUP,
@                                      and completes with NEXT.

    .macro defcode name, control=0, label, code
    .section .rodata
    .balign 4                           @ make sure we are on a 4 byte boundary
    .word 0                             @ locate
1:
    .word link                          @ link
    .byte 3f - 2f + \control            @ control + length byte
2:
    .ascii "\name"                      @ the name
3:
    .balign 4                           @ pad with 0's to 4 byte boundary
    .global \label
\label:                                 @ CFA for the word
    .word \code                         @ code field - points to the assembly code for the word (must be defined
                                        @ in the .text section)
    .set link, 1b
    .endm


@
@   Create a constant definition for a word in the dictionary.
@
@   This dictionary definition is stored in the .section .rodata section, which is read-only.
@   A small word defintion is used to define a constant in the dictionary that pushes the value onto the
@   data stack when executed.
@
@   Example: 10 CONSTANT TEN
@                                                    constant value
@   +--------+---------+---+---+---+---+------------+-|------+
@   | LOCATE | LINK    | 3 | T | E | N | (CONSTANT) | 10     |
@   +--------+---------+---+---+---+---+-|----------+--------+
@                                       points to the (CONSTANT) interpreter.

    .macro defconst name, label, value
    .section .rodata
    .balign 4                           @ make sure we are on a 4 byte boundary
    .word 0                             @ locate
1:
    .word link                          @ link
    .byte 3f - 2f                       @ length byte
2:
    .ascii "\name"                      @ the name
3:
    .balign 4                           @ pad with 0's to 4 byte boundary
    .global \label
\label:                                 @ CFA for the word
    .word _paren_constant               @ code field - points to the DOCOL interpreter
    .word \value                        @ value of the constant

    .set link, 1b
    .endm


@
@   Create a value definition for a word in the dictionary.
@
@   This dictionary definition is stored in the .data section, which is writable.
@   A small word defintion is used to define a value in the dictionary that pushes the value onto the
@   data stack when executed.
@
@   Use TO and +TO to change the value.
@
@   Example: 42 VALUE VAL
@                                                    value
@   +--------+---------+---+---+---+---+------------+-|------+
@   | LOCATE | LINK    | 3 | V | A | L | (CONSTANT) | 42     |
@   +--------+---------+---+---+---+---+-|----------+--------+
@                                       points to the (CONSTANT) interpreter.

    .macro defvalue name, label, value
    .data
    .balign 4                           @ make sure we are on a 4 byte boundary
    .word 0                             @ locate
1:
    .word link                          @ link
    .byte 3f - 2f                       @ length byte
2:
    .ascii "\name"                      @ the name
3:
    .balign 4                           @ pad with 0's to 4 byte boundary
    .global \label
\label:                                 @ CFA for the word
    .word _paren_constant               @ code field - points to the DOCOL interpreter
    .word \value                        @ value of the constant

    .set link, 1b
    .endm


@
@   Create a variable definition for a word in the dictionary.
@
@   This dictionary definition is stored in the .data section, which is writable.
@   The data field stores the value of the variable.
@
@   Example: VARIABLE DATA
@
@                                                                  variable value
@   +--------+---------+---+---+---+---+---+---+---+---+----------+-|------+
@   | LOCATE | LINK    | 4 | D | A | T | A | 0 | 0 | 0 | (CREATE) | 0      |
@   +--------+---------+---+---+---+---+---+---+---+---+-|--------+--------+
@                                                       points to the (CREATE) interpreter.

    .macro defvar name, label, initial=0
    .data
    .balign 4                           @ make sure we are on a 4 byte boundary
    .word 0                             @ locate
1:
    .word link                          @ link
    .byte 3f - 2f                       @ length byte
2:
    .ascii "\name"                      @ the name
3:
    .balign 4                           @ pad with 0's to 4 byte boundary
    .global \label
\label:                                 @ CFA for the word
    .word _paren_create
    .global var_\label
var_\label:                             @ DFA for the variable
    .word \initial                      @ initial value of the variable

    .set link, 1b
    .endm


@
@   Error Codes
@

    .EQU ERR_OK,                          0
    .equ ERR_ABORT,                      -1 
    .equ ERR_ABORT_QUOTE,                -2 
    .equ ERR_STACK_OVERFLOW,             -3 
    .equ ERR_STACK_UNDERFLOW,            -4 
    .equ ERR_RETURN_STACK_OVERFLOW,      -5 
    .equ ERR_RETURN_STACK_UNDERFLOW,     -6 
    .equ ERR_DO_LOOPS_NESTED_TOO_DEEPLY, -7 
    .equ ERR_DICTIONARY_OVERFLOW,        -8 
    .equ ERR_INVALID_MEMORY_ADDRESS,     -9 
    .equ ERR_DIVISION_BY_ZERO,          -10
    .equ ERR_RESULT_OUT_OF_RANGE,       -11
    .equ ERR_ARGUMENT_TYPE_MISMATCH,    -12
    .equ ERR_UNDEFINED_WORD,            -13
    .equ ERR_COMPILE_ONLY_WORD,         -14
    .equ ERR_INVALID_FORGET,            -15
    .equ ERR_ATTEMPT_TO_EMPTY_NAME,     -16
    .equ ERR_PIC_NUM_OUTPUT_OVERFLOW,   -17
    .equ ERR_PARSED_STRING_OVERFLOW,    -18
    .equ ERR_DEFINITION_NAME_TOO_LONG,  -19
    .equ ERR_WRITE_TO_ROM,              -20
    .equ ERR_UNSUPPORTED_OPERATION,     -21
    .equ ERR_CONTROL_STRUCT_MISMATCH,   -22
    .equ ERR_ADDR_ALIGNMENT_EXCEPTION,  -23
    .equ ERR_INVALID_NUMERIC_ARGUMENT,  -24
    .equ ERR_RETURN_STACK_IMBALANCE,    -25
    .equ ERR_LOOP_PARAMS_UNAVAILABLE,   -26
    .equ ERR_INVALID_RECURSION,         -27
    .equ ERR_USER_INTERRUPT,            -28
    .equ ERR_COMPILER_NESTING,          -29
    .equ ERR_OBSOLESCENT_FEATURE,       -30
    .equ ERR_TO_BODY_USED_INCORRECTLY,  -31
    .equ ERR_INVALID_NAME_ARGUMENT,     -32
    .equ ERR_BLOCK_READ_EXCEPTION,      -33
    .equ ERR_BLOCK_WRITE_EXCEPTION,     -34
    .equ ERR_INVALID_BLOCK_NUMBER,      -35
    .equ ERR_INVALID_FILE_POSITION,     -36
    .equ ERR_FILE_IO_EXCEPTION,         -37
    .equ ERR_NONEXISTENT_FILE,          -38
    .equ ERR_UNEXPECTED_EOF,            -39
    .equ ERR_FP_INVALID_BASE,           -40
    .equ ERR_FP_LOSS_OF_PRECISION,      -41
    .equ ERR_FP_DIVIDE_BY_ZERO,         -42
    .equ ERR_FP_RESULT_OUT_OF_RANGE,    -43
    .equ ERR_FP_STACK_OVERFLOW,         -44
    .equ ERR_FP_STACK_UNDERFLOW,        -45
    .equ ERR_FP_INVALID_ARGUMENT,       -46
    .equ ERR_COMP_WORDLIST_DELETED,     -47
    .equ ERR_INVALID_POSTPONE,          -48
    .equ ERR_SEARCHORDER_OVERFLOW,      -49
    .equ ERR_SEARCHORDER_UNDERFLOW,     -50
    .equ ERR_COMP_WORDLIST_CHANGED,     -51
    .equ ERR_CF_STACK_OVERFLOW,         -52
    .equ ERR_EXCEPTION_STACK_OVERFLOW,  -53
    .equ ERR_FP_UNDERFLOW,              -54
    .equ ERR_FP_UNIDENTIFIED_FAULT,     -55
    .equ ERR_QUIT,                      -56
    .equ ERR_EXCEPTION_IN_SEND_RECEIVE, -57
    .equ ERR_IF_ELSE_THEN_EXCEPTION,    -58
