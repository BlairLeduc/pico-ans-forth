@
@   Leduc Forth - a simple FORTH compiler/interpreter for the PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (arithmatic)
@   See 4.1 THE TEXT INTERPRETER (FPH, p119)
@

    .include "forth.inc"

    .section .text

@
@   DOCOL executes a list of execution tokens.
@
@   Parameters:
@       r0 - the code field address of the word executing
@       r5 - return instruction pointer (used when we call EXIT)
@
@   Example: : DOUBLE DUP + ;
@
@   +--------+--------+---+---+---+---+---+---+---+---+--------+--------+--------+--------+
@   | LOCATE | LINK   | 6 | D | O | U | B | L | E | 0 | _docol | DUP    | +      | EXIT   |
@   +--------+--------+---+---+---+---+---+---+---+---+-|------+--------+--------+--------+
@                                                       |
@                                                       r0
@
@   A copy of NEXT for easy reference, this is the main interpreter loop.
@
@   NEXT:
@       ldr r0, [r5], #4                @ r5 points to the next instruction
@       ldr r1, [r0]                    @ get the interpreter address stored in the execution token
@       orr r1, #1                      @ set the thumb bit (make sure we stay in thumb mode)
@       blx r1                          @ branch to the interpreter/hand-crafted code
@
@   NEXT is called by the previous word's EXIT, which brings us to _docol.

@   Process the execution tokens in the word pointed to by r0. 
    .global _docol
_docol:
    pushr r5                            @ push the return instruction pointer on to the return stack
    add r5, r0, #4                      @ set r5 to point the the first execution token in this word
    NEXT                                @ call the interpreter or hand-crafted code of the execution token in r5.

@   Return to the interpreter that called DOCOL.
    .global _exit
_exit:
    popr r5                             @ pop return instruction pointer from the return stack
    cmp r5, #0                          @ check if we have a return instruction pointer
    beq 1f                              @ if not, branch to error handling
    NEXT                                @ call the interpreter or hand-crafted code of the execution token in r5.
1:  ldr r0, =ERR_RETURN_STACK_IMBALANCE @ set error code for exit on exception frame
    bl __type_error                       @ emit the error message
    b _quit                             @ return to the terminal

@
@   DODOES executes a list of execution tokens.
@
@   Parameters:
@       r0 - the code field address of the word executing
@       r5 - return instruction pointer (used when we call EXIT)
@
@   Basic structure:
@
@   +--------+--------+---+---+---+---+---------+--------+--------+--------...------+--------+
@   | LOCATE | LINK   | 3 | V | A | R | _dodoes | OFFSET | data   | behaviour words | EXIT   |
@   +--------+--------+---+---+---+---+-|-------+-|------+--------+--------...------+--------+
@                                       |         |                 ^
@                                       r0        |                 |
@                                                 +-----------------+
@
@   When the OFFSET is zero, representing no behaviour words are defined, DODOES performs the
@   default behaviour of pushing the pointer to the data onto the stack.
@
@   +--------+--------+---+---+---+---+---------+--------+--------+
@   | LOCATE | LINK   | 3 | V | A | R | _dodoes | 0      | data   |
@   +--------+--------+---+---+---+---+-|-------+-|------+--------+
@                                       |        no behaviour words
@                                       r0
@

    .global _dodoes
_dodoes:
    ldr r1, [r0, #4]                    @ r1 = behavior pointer
    cmp r1, #0                          @ Is it zero?
    beq 1f                              @ If so, skip the behavior words
    pushr r5
    add r5, r0, #4
1:  add r0, #8
    pushd r0                           @ Push the pointer to its data
    NEXT

@
@ No-op
@

    .global _noop
_noop:
    NEXT


    .global _lit
_lit:
@   LIT pushes a literal number onto the stack.
    @ r5 points to the next command, but in this case it points to the next
    @ literal 32 bit integer.  Get that literal into r0 and increment r5.
    ldr r0, [r5], #4
    pushd r0                            @ push the literal number on to the stack
    NEXT


    .global _parse_word
_parse_word:
    mov r0, #0x20                       @ space delimiter
    mov r1, #1
    bl __parse                          @ skip initial delimiters
    pushd r0
    pushd r1
    NEXT

    .global _parse
_parse:
    popd r0                             @ delimiter
    eor r1, r1                          @ don't skip initial delimiters
    bl __parse
    pushd r0
    pushd r1
    NEXT

    .global __parse
__parse: @ r0 = delimiter, r1 = skip initial spaces
    push {r4-r7}

    movw r4, :lower16:input_source
    movt r4, :upper16:input_source
    ldmia r4, {r4, r5}                  @ r4 = source buffer address, r5 = source size 
        
    movw r6, :lower16:var_TOIN
    movt r6, :upper16:var_TOIN
    ldr r6, [r6]                        @ position in source

    add r4, r6                          @ get addr of the parse area
    mov r7, r4                          @ save address of the parse area
    mov r3, r1
    eor r1, r1                          @ set word length to 0

1:  cmp r3, #0                          @ check if we are skipping initial delimiters
    beq 4f

2:  cmp r6, r5                          @ have we reached the end of the source?
    bge 6f
    ldrb r2, [r4], #1                   @ load the next character from the source
    add r6, #1                          @ increment the position
    add r7, #1                          @ increment the parse area pointer
    cmp r2, #32                         @ is it a space?
    beq 2b                              @ if so, branch to skip initial delimiters

    sub r7, #1                          @ adjust for delimiter
    add r1, #1                          @ increment word length

3:  @ Scan the input buffer looked for the end of the word
4:  cmp r6, r5                          @ have we reached the end of the source?
    bge 5f                              @ if so, exit
    ldrb r2, [r4], #1
    add r6, #1                          @ increment >IN
    add r1, #1
    cmp r2, r0                          @ is it a delimiter?
    bne 3b                              @ if not, continue scanning                  		                    

5:  sub r1, #1                          @ adjust for delimiter
6:  movw r3, :lower16:var_TOIN
    movt r3, :upper16:var_TOIN
    str r6, [r3]                        @ store new >IN value

    mov r0, r7                          @ restore address of the parsed text
    pop {r4-r7}
    bx lr

    .global _evaluate
_evaluate:
    NEXT

    .global _interpret
_interpret:
    bl __interpret
    NEXT

    .global __interpret
__interpret:
    push {r4-r7, lr}                    @ save registers
    mov r0, #0x20                       @ delimiter
    bl __word                           @ returns r0 = pointer to counted-string, r1 = length of the word
    cmp r1, #0                          @ is it a zero-length word?
    bne 1f                              @ no, look for the word in the dictionary   
    mov r0, #0                          @ return false
    pop {r4-r7, pc}

1:  @ Find word in the dictionary
    mov r4, r0                          @ save r4 = address of the word 
    mov r5, r1                          @ save r5 = length of the word
    bl __find                           @ returns r0 = pointer to header or 0 if not found
    cmp r0, #0                          @ found?
    beq 2f                              @ no, so assume it's a number

    @ Word was found in the dictionary
    add r0, #4                          @ r0 = address of the flags byte
    ldrb r1, [r0], #1                   @ Get the flags byte.
    mov r2, r1                          @ r1 = flags byte
    and r2, #CB_LENGTH                  @ r1 = length of name (remove fields)
    add r0, r2                          @ r0 = address of the code field
	add r0, #3                          @ align
	and r0, #~3
    ands r6, r2, #CB_PRECEDENCE         @ is precedence flag set?
    bne 5f                              @ yes, execute the word (interpret)
    b 4f                                @ else, interpret or compile it based on STATE

2:	@ Not in the dictionary (not a word) so assume it's a number
    mov r0, r5                          @ r0 = length of the word
    mov r1, r4                          @ r1 = address of the word
    add r1, #1                          @ move past the length in the counted string
    bl __number                         @ returns the parsed number in r0, r1 > 0 if error
    cmp r1, #0                          @ is it a number?
    bne interpret_error                 @ no, so issue message and abort.  

	@ Have number, are we compiling or executing?
    ldr r2, =var_STATE
    ldr r2, [r2]
    cmp r2, #0                          @ is STATE 0? (interpreting)
    bne 3f                              @ jump if compiling

    @ Interpreting a literal number - push the number on the data stack.
    pushd r0
    mov r0, #-1                         @ return true
    pop {r4-r7, pc}

    @ Compiling a liternal number - just append the word to the current dictionary definition.
3:  mov r7, r0                          @ r7 = the literal number
    ldr r0, =LIT
    bl __comma
    mov r0, r7                          @ LIT is followed by the number.
    bl __comma
    mov r0, #-1                         @ return true  
    pop {r4-r7, pc}

4:	@ Have word, are we compiling or executing?
    ldr r2, =var_STATE
    ldr r2, [r2]
    cmp r2, #0                          @ is STATE 0? (interpreting)
    bne 6f                              @ jump if compiling

    @ Interpreting a word - execute it.
5:  pop {r4-r7, lr}
    push {lr}
    pushr r5
    ldr r5, =interupt_done_xt
    ldr r1, [r0]
    orr r1, #1                          @ set the thumb bit   
    blx r1                              @ execute the code field
interpret_done:
    mov r0, #-1                         @ return true
    pop {pc}

6:  @ Compiling a word - append the word to the current dictionary definition.
    bl __tcfa                           @ get the address of the code field 
    bl __comma                          @ append the code field address to the dictionary  
    mov r0, #-1                         @ return true
    pop {r4-r7, pc}                     @ pop the parameters off the stack and return

interpret_error:	@ Not a word in the dictionary and not a number, so emit an error and abort.
    mov r0, r4
    add r0, #1                          @ r0 = address of the word (skip length byte)
    mov r1, r5
    bl __type
    ldr r0, =errmsg
    bl __type_cstr

    pop {r4-r7, lr}
    b _quit

errmsg:
    .asciz " ?\x0D"
    .balign 4
interupt_done_xt:
    .word interpret_done_vector                    @ address to return to after executing the word
interpret_done_vector:
    .word interpret_done                @ address to return to after executing the word


    @   QUIT is the main entry point for the interpreter.
    .global _quit
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
    .asciz " ok\x0D"
compile_prompt:
    .asciz "\x0D    "
    .balign 4

    .global _execute
_execute:
    popd r0                             @ get xt into r0
    ldr r0, [r0]                        @ get the address of the code field
    orr r0, #1                          @ set the thumb bit
    blx r0                              @ execute


    .global _refill
_refill:
    bl __refill
    pushd r0                             @ get the result of the refill
    NEXT

    .global __refill
__refill:
    push {lr}
    movw r0, :lower16:var_BLK           @ load the BLK source
    movt r0, :upper16:var_BLK
    ldr r0, [r0]                        @ get the current block number
    cmp r0, #0                          @ is it zero?
    beq 1f                              @ if so, check SOURCE_ID to determine input source

    @ Block input stream (BLK > 0)
    eor r0, r0                          @ not implemented: clear r0
    pop {pc}                            @ always return false (no input available) until we implement block input

1:  movw r0, :lower16:var_SOURCE_ID     @ load the source ID
    movt r0, :upper16:var_SOURCE_ID
    ldr r0, [r0]                        @ get the current source ID
    cmp r0, #0                          @ the source is?
    beq 2f                              @ = 0, refill from terminal
    bgt 3f                              @ > 0, refill from a text file

    @ Character String input stream or some unknown source (SOURCE_ID < 0)
    eor r0, r0                          @ refill does not apply to character strings (or unknown sources)
    pop {pc}                            @ always return false (no input available)

    @ Terminal input stream (SOURCE_ID = 0)
2:  movw r0, :lower16:terminal_input_buffer
    movt r0, :upper16:terminal_input_buffer
    movw r1, :lower16:input_source
    movt r1, :upper16:input_source
    str r0, [r1]
    mov r1, #TERMINAL_INPUT_BUFFER_SIZE
    bl __accept
    movw r1, :lower16:input_source + 4
    movt r1, :upper16:input_source + 4
    str r0, [r1]
    movw r1, :lower16:var_TOIN
    movt r1, :upper16:var_TOIN
    eor r0,r0
    str r0, [r1]                        @ reset >IN to 0
    mov r0, #-1
    pop {pc}

    @ File input stream (SOURCE_ID > 0)
3:  eor r0, r0                          @ not implemented: clear r0
    pop {pc}                            @ always return false (no input available) until we implement file input


    .global _restore_input
_restore_input:
    popd r2                             @ the number of items to restore
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    popd r0                             
    ldr r1, =var_BLK
    str r0, [r1]                        @ restore the BLK variable
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    popd r0                             @ the source ID
    ldr r1, =var_SOURCE_ID
    str r0, [r1]                        @ restore the SOURCE_ID variable
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    popd r1                             @ the source size
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    popd r0                             @ the source pointer
    movw r3, :lower16:input_source
    movt r3, :upper16:input_source
    stmia r3, {r0, r1}                  @ restore the source pointer and size
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    
1:  cmp r2, #0                          @ check if we have more items to remove
    ble 2f                              @ if not, we're done
    popd r0                             @ remove extra item from stack
    subs r2, #1                         @ decrement counter
    b 1b                                @ loop until all extra items removed

2:  eor r2, r2                          @ clear r2 (success)
3:  pushd r2                            @ push success flag
    NEXT



    .global _save_input
_save_input:
    movw r0, :lower16:input_source
    movt r0, :upper16:input_source
    ldmia r0, {r0, r1}                  @ r4 = source buffer address, r5 = source size 
    pushd r0
    pushd r1
    ldr r0, =var_TOIN
    ldr r0, [r0]
    pushd r0
    ldr r0, =var_SOURCE_ID
    ldr r0, [r0]
    pushd r0
    ldr r0, =var_BLK
    ldr r0, [r0]
    pushd r0
    mov r0, #5
    pushd r0                            @ push the number of items to save
    NEXT

    .global _source
_source:
    movw r0, :lower16:input_source
    movt r0, :upper16:input_source
    ldmia r0, {r0, r1}                  @ r4 = source buffer address, r5 = source size 
    pushd r0
    pushd r1
    NEXT

    .global _tib
_tib:
    movw r0, :lower16:terminal_input_buffer
    movt r0, :upper16:terminal_input_buffer
    pushd R0
    NEXT

    .global _tick
_tick:
    bl __tick
    pushd r0                            @ push execution token
    NEXT

    .global __tick
__tick:
    push {r4-r5, lr}
    mov r0, #0x20                       @ space delimiter
    bl __word                           @ get next word
    mov r4, r0                          @ save word address
    mov r5, r1                          @ save word length
    bl __find                           @ find in dictionary
    cmp r0, #0                          @ found?
    beq 1f                              @ no, error
    bl __tcfa                           @ convert to code field address
    pop {r4-r5, pc}                            @ return

1:  pop {r4-r5, lr}
    mov r0, r4                          @ restore word address
    add r0, #1                          @ skip length byte
    mov r1, r5                          @ restore length
    bl __type                           @ print the word
    ldr r0, =tick_error                 @ load error message
    bl __type_cstr                      @ print it
    b _quit                             @ abort

tick_error:
    .asciz " ?\x0D"
    .balign 4

    .global _bracket_tick
_bracket_tick:
    ldr r0, [r5], #4			        @ get the address of the next word and skip it.
    pushd r0		                    @ gush it on the stack.
    NEXT

    .global _find
_find:
    popd r1                            @ r0 = the length of the search string
    popd r0                            @ r1 = address of the search string
    bl __find
    pushd r0                           @ r0 = address of dictionary entry (or NULL)
    NEXT

__find: @ r0 = address of the search string, r1 = length of the search string
    push {r4-r7}
    ldr r2, =var_LATEST                 @ points to current dictionary entry
 1: ldr r7, [r2]
    cmp r7, #0                          @ end of dictionary?
    beq 6f

    mov r6, r0                          @ address of the search string
    add r7, #4                          @ address of the current word's name
    @ Compare the length expected and the length of the word
    ldrb r3, [r7], #1                   @ flags + length field of current entry
    and r3, #CB_SMUDGE|CB_LENGTH        @ name length + smudge flag
    cmp r3, r1		                    @ length is the same? (smudge flag set will corrupt the comparison)
    bne 5f                              @ no, so skip to next entry.   

    @ Compare the strings in detail.
    add r6, #1                          @ move past length byte
2:  ldrb r4, [r6], #1                   @ load char from the search string
    ldrb r5, [r7], #1                   @ load char from the current entry name
    
    @ Convert r4 to uppecase if it's lowercase
    cmp r4, #'a'
    blt 3f
    cmp r4, #'z'
    bgt 3f
    sub r4, #32                         @ Convert to uppercase by adding 32

    @ Convert r5 to uppercase if it's lowercase 
3:  cmp r5, #'a'
    blt 4f
    cmp r5, #'z'
    bgt 4f
    sub r5, #32                         @ Convert to uppercase by adding 32

4:  cmp r4, r5                          @ Compare characters
    bne 5f                              @ Not the same, so skip to next entry
    subs r3, #1                         @ Decrement length
    bne 2b         
    
    @ The strings are the same - return the header pointer in r0
    ldr r0, [r2]
    pop {r4-r7}                         @ return to caller
    bx lr

    @ Not the same, so check the next entry.
5:	ldr r2, [r2]                        @ Move back through the link field to the previous word
    b 1b                                @ .. and loop.

6:	// Not found.
    eor r0, r0                          @ Return zero to indicate not found.
    pop {r4-r7}
    bx lr

    .global __tcfa
__tcfa:
    add r0, #4                          @ r0 = address of the name field   
    ldrb r1, [r0], #1                   @ r1 = flags+length field of current entry
    and r1, #CB_LENGTH                  @ r1 = length of name (remove fields)
    add r0, r1                          @ r0 = address of the code field
    add r0, #3                          @ The codeword is 4-byte aligned.
    and r0, #~3
    blx lr                              @ return to caller

@
@   Input source state
@
    .data
    .balign 4
    .global input_source
input_source:
    .word terminal_input_buffer
    .word TERMINAL_INPUT_BUFFER_SIZE
