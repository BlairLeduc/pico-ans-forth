@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (arithmatic)
@   See 4.1 THE TEXT INTERPRETER (FPH, p119)
@

    .include "forth.S"

    .text

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
@   | LOCATE | LINK   | 6 | D | O | U | B | L | E | 0 | DOCOL  | DUP    | +      | EXIT   |
@   +--------+--------+---+---+---+---+---+---+---+---+-|------+--------+--------+--------+
@                                                       |
@                                                       r0
@
@   r5 points to the instruction after the instruction that called (DOCOL). There is where we
@   will return to when we EXIT from the word being executed.
@
@   A copy of NEXT for easy reference, this is the main interpreter loop.
@
@   NEXT:
@       ldr r0, [r5], #4                @ r5 points to the next instruction
@       ldr r1, [r0]                    @ get the interpreter address stored in the execution token
@       orr r1, #1                      @ set the thumb bit (make sure we stay in thumb mode)
@       bx r1                          @ branch to the interpreter/hand-crafted code
@
@   NEXT is called by the previous word's EXIT, which brings us to _docol.

@   Process the execution tokens in the word pointed to by r0. 
    .global _docol
    .thumb_func
_docol:
    pushr r5                            @ push the return instruction pointer on to the return stack
    add r5, r0, #4                      @ set r5 to point to the first execution token in this word
    NEXT                                @ call the interpreter or hand-crafted code of the execution token in r5.

@   Return to the interpreter that called DOCOL.
    .global _exit
    .thumb_func
_exit:
    popr r5                             @ pop return instruction pointer from the return stack
    cmp r5, #-1                         @ check if we have a return instruction pointer
    beq 1f                              @ if not, branch to error handling
    NEXT                                @ call the interpreter or hand-crafted code of the execution token in r5.
1:  ldr r0, =ERR_RETURN_STACK_IMBALANCE @ set error code for exit on exception frame
    bl __type_error                     @ emit the error message
    b _quit                             @ return to the terminal

@
@   (DOES>) executes a list of execution tokens.
@
@   Defining word:
@
@   : MSG   CREATE DOES> COUNT TYPE ;
@                                                         update the code field (from create) to point to the defining word
@   +--------+---------+---+---+---+---+--------+--------+-|------+---------+--------+--------+--------+--------+
@   | LOCATE | LINK    | 3 | M | S | G | DOCOL  | CREATE | DOES>  | ldr/bx  | addr   | COUNT  | TYPE   | EXIT   |
@   +--------+---------+---+---+---+---+--------+--------+--------+-^-------+-|------+--------+--------+--------+
@                                                                   |        address of (DOES>)
@   MSG (CR) 2 C, 0D C, 0A C,                               +-------+
@                                                value      |
@   +--------+---------+---+---+---+---+---+---+---+---+----|---+----+----+----+----+
@   | LOCATE | LINK    | 4 | ( | C | R | ) | 0 | 0 | 0 | a-addr | 02 | 0D | 0A | 00 |
@   +--------+---------+---+---+---+---+---+---+---+---+----|---+----+----+----+----+
@                                                          was (CREATE)
@
@   (DOES>) pushes the address of the data field area on the stack, and and then executes
@   the words that followed DOES> in the defining word.
@   After DOES> updates the code field, it will EXIT.
@  

    @   r0 = address of the defined word, r0 + 4 = address of the data field
    @   r1 = address of DOES> in the defining word, r1 + 8 = first word after DOES>
    .global _paren_does
    .thumb_func
_paren_does:
    pushr r5                            @ push the return instruction pointer on to the return stack
    add r2, r0, #4                      @ r5 = pointer to the data field area
    pushd r2                            @ push the data field area on to the data stack
    add r5, r1, #8                      @ skip over the code that got us here
    and r5, #~3                         @ align r5 to a 4-byte boundary
    NEXT


    .global _paren_create
    .thumb_func
_paren_create:
    add r1, r0, #4                    @ move to the data field
    pushd r1
    NEXT

    .global _paren_constant
    .thumb_func
_paren_constant:
    add r1, r0, #4
    ldr r1, [r1]
    pushd r1                            @ push the constant value on to the data stack
    NEXT


    .global _literal
    .thumb_func
_literal:
    @ LITERAL pushes a literal number onto the stack.
    @ r5 points to the next command, but in this case it points to the next
    @ literal 32 bit integer.  Get that literal into r0 and increment r5.
    ldr r0, =var_STATE
    ldr r0, [r0]                        @ load the current state (compiling or interpreting)
    cmp r0, #0                          @ is STATE 0? (interpreting)
    beq 1f                              @ if so, branch to push the literal number on the stack

    @ Compiling a literal number - append the word to the current dictionary definition.
    ldr r0, =LITERAL                    @ load the address of the LITERAL word
    bl __comma                          @ append the code field address to the dictionary
    popd r0
    bl __comma                          @ append the literal number to the dictionary
    NEXT

1:  ldr r0, [r5], #4
    pushd r0                            @ push the literal number on to the stack
    NEXT


    .global _two_literal
    .thumb_func
_two_literal:
    @ TWO_LITERAL pushes a literal 64 bit integer onto the stack.
    @ r5 points to the next command, but in this case it points to the next
    @ literal 64 bit integer. Get that literal into r0 and increment r5.
    ldr r0, =var_STATE
    ldr r0, [r0]                        @ load the current state (compiling or interpreting)
    cmp r0, #0                          @ is STATE 0? (interpreting)
    beq 1f                              @ if so, branch to push the literal number on the stack

    @ Compiling a literal number - append the word to the current dictionary definition.
    ldr r0, =TWO_LITERAL                   @ load the address of the 2LITERAL word
    bl __comma                          @ append the code field address to the dictionary
    popd r0
    bl __comma                          @ append the literal number to the dictionary
    popd r0
    bl __comma                          @ append the literal number to the dictionary
    NEXT

1:  ldr r0, [r5, #4]
    pushd r0                            @ push the literal number on to the stack
    ldr r0, [r5], #8                    @ get the second part of the 64 bit integer
    pushd r0                            @ push the second part on to the stack
    NEXT

    .global _s_literal
    .thumb_func
_s_literal:
    ldr r0, =var_STATE
    ldr r0, [r0]                        @ load the current state (compiling or interpreting)
    cmp r0, #0                          @ is STATE 0? (interpreting)
    beq 1f                              @ if so, branch to push the literal number on the stack

    @ Compiling a literal string - append the word to the current dictionary definition.
    ldr r0, =S_LITERAL                  @ load the address of the SLITERAL word
    bl __comma                          @ append the xt to the data fields
    popd r0
    push {r0}
    bl __comma                          @ append the string length to the data fields 
    pop {r1}                            @ length
    popd r0                             @ source address
    ldr r2, =var_DP
    ldr r2, [r2]                        @ get the current DP value
    push {r1-r2}
    bl __move                           @ move the string from the parse area to the data fields
    pop {r1-r2}                         @ restore the string length
    add r2, r1
    add r2, #3
    and r2, #~3                         @ align the length to 4 bytes
    ldr r3, =var_DP
    str r2, [r3]                        @ update DP
    NEXT

1:  ldr r0, [r5], #4                    @ r0 = length of the string
    pushd r5
    pushd r0                            @ push the address of the string and its length
    add r5, r0
    add r5, #3                          @ increment r5 to point to the next command
    and r5, #~3
    NEXT


    .global _evaluate
    .thumb_func
_evaluate:
    NEXT

    .global _interpret
    .thumb_func
_interpret:
    bl __interpret
    NEXT

    .global __interpret
    .thumb_func
__interpret:
    push {r4-r7, lr}                    @ save registers
    mov r0, #0x20                       @ delimiter
    bl __word                           @ returns r0 = pointer to counted-string, r1 = length of the word
    cmp r1, #0                          @ is it a zero-length word?
    bne 1f                              @ no, look for the word in the dictionary   
    mov r0, #0                          @ return false
    pop {r4-r7, pc}

1:  @ find word in the dictionary
    bl __find                           @ returns r0 = pointer to header or search string
    cmp r1, #0                          @         r1 = 0 if not found, 1 if immediate, -1 if not immediate
    beq 2f                              @ not found? maybe it is a number

    @ word was found in the dictionary
    cmp r1, #1
    beq 5f                              @ is precedence flag set? execute the word (interpret)
    b 4f                                @ else, interpret or compile it based on STATE

2:  @ not in the dictionary (not a word) so assume it's a number
    mov r4, r0                          @ save address of the word (counted string)
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
    ldr r0, =LITERAL
    bl __comma
    mov r0, r7                          @ LITERAL is followed by the number.
    bl __comma
    mov r0, #-1                         @ return true  
    pop {r4-r7, pc}

4:  @ Have word, are we compiling or executing?
    ldr r2, =var_STATE
    ldr r2, [r2]
    cmp r2, #0                          @ is STATE 0? (interpreting)
    bne 6f                              @ jump if compiling

    @ Interpreting a word - execute it.
5:  pop {r4-r7, lr}
    push {lr}
    pushr r5
    ldr r5, =interpret_done_xt
    ldr r1, [r0]
    orr r1, #1                          @ set the thumb bit   
    bx r1                              @ execute the code field
interpret_done:
    mov r0, #-1                         @ return true
    pop {pc}

6:  @ compiling a word - append the word to the current dictionary definition.
    bl __comma                          @ append the code field address to the dictionary  
    mov r0, #-1                         @ return true
    pop {r4-r7, pc}                     @ pop the parameters off the stack and return

    @ oot a word in the dictionary and not a number, so emit an error and abort
interpret_error:
    mov r0, r4
    ldrb r1, [r0], #1
    bl __type
    ldr r0, =__word_not_found_error
    bl __type_cstr

    pop {r4-r7, lr}
    b _quit

    .balign 4
interpret_done_xt:
    .word interpret_done_vector         @ address to return to after executing the word
interpret_done_vector:
    .word interpret_done                @ address to return to after executing the word


    .global _execute
    .thumb_func
_execute:
    popd r0                             @ get xt into r0
    ldr r1, [r0]
    orr r1, #1                          @ set the thumb bit   
    bx r1     

    @   6.1.0070    ' ( “<spaces>name” -- xt ) “tick”
    @
    @   Skip leading space delimiters. Parse name delimited by a space. Find name and return xt, the
    @   execution token for name. An ambiguous condition exists if name is not found.
    @   When interpreting, ' xyz EXECUTE is equivalent to xyz.
    
    .global _tick
    .thumb_func
_tick:
    bl __tick
    pushd r0                            @ push found execution token
    NEXT

    .global __tick
    .thumb_func
__tick:
    push {r4-r5, lr}
    mov r0, #0x20                       @ space delimiter
    bl __word                           @ get next word
    mov r4, r0                          @ save word address
    mov r5, r1                          @ save word length
    bl __find                           @ find in dictionary
    cmp r1, #0
    beq __word_not_found                @ if not found, branch to error handling
    pop {r4-r5, pc}                     @ return


    .global _bracket_defined
    .thumb_func
_bracket_defined:
    bl __bracket_defined
    pushd r0                            @ push execution token
    NEXT

    .global __bracket_defined
    .thumb_func
__bracket_defined:
    push {lr}
    mov r0, #0x20                       @ space delimiter
    bl __word                           @ get next word
    bl __find                           @ find in dictionary
    cmp r1, #0                          @ found?
    ite eq
    moveq r0, #0                        @ if not found, return false
    movne r0, #-1                       @ if found, return true
    pop {pc}


    .global _bracket_undefined
    .thumb_func
_bracket_undefined:
    bl __bracket_undefined
    pushd r0                            @ push execution token
    NEXT

    .global __bracket_undefined
    .thumb_func
__bracket_undefined:
    push {lr}
    mov r0, #0x20                       @ space delimiter
    bl __word                           @ get next word
    bl __find                           @ find in dictionary
    cmp r1, #0                          @ found?
    ite eq
    moveq r0, #-1                       @ if not found, return true
    movne r0, #0                        @ if found, return false
    pop {pc}

    .global __word_not_found
    .thumb_func
__word_not_found:
    pop {r4-r5, lr}
    mov r0, r4                          @ restore word address
    add r0, #1                          @ skip length byte
    mov r1, r5                          @ restore length
    bl __type                           @ print the word
    ldr r0, =__word_not_found_error     @ load error message
    bl __type_cstr                      @ print it
    b _quit                             @ abort

    .balign 4
__word_not_found_error:
    .asciz " ?\015\012"
    .balign 4

    
    @   15.6.2.2532 [IF] “bracket-if”
    @
    @   If flag is true, do nothing. Otherwise, skipping leading spaces, parse and discard space-
    @   delimited words from the parse area, including nested occurrences of [IF] ... [THEN]
    @   and [IF] ... [ELSE] ... [THEN], until either the word [ELSE] or the word
    @   [THEN] has been parsed and discarded. If the parse area becomes exhausted, it is refilled as
    @   with REFILL. [IF] is an immediate word.
    @
    @   An ambiguous condition exists if [IF] is POSTPONEd, or if the end of the input buffer is
    @   reached and cannot be refilled before the terminating [ELSE] or [THEN] is parsed.

    .global _bracket_if
    .thumb_func
_bracket_if:
    popd r0
    bl __bracket_if
    NEXT

    .global __bracket_if
    .thumb_func
__bracket_if:

    push {r4, lr}
    eor r4, r4                          @ r4 = nested level counter
    cmp r0, #0
    bne 6f                              @ if flag is true, do nothing and return

1:  mov r0, #0x20                       @ space delimiter
    mov r1, #1
    bl __parse                          @ skip initial delimiters
    cmp r1, #0
    beq 5f                              @ if no word, branch to refill

    @ Is it [IF]?
    ldr r2, =word_if
    mov r3, #word_if_len
    bl __compare_word                   @ compare the word with [IF]
    cmp r2, #0                          @ if match, r2 = -1
    bne 3f                              @ if match, branch to handle [IF]

    @ Is it [ELSE] or [THEN]?
    cmp r4, #0                          @ check if we are in a nested [IF]
    bgt 2f                              @ if we are in a nested [IF], ignore the else
    ldr r2, =word_else
    mov r3, #word_else_len
    bl __compare_word                   @ compare the word with [ELSE]
    cmp r2, #0                          @ if match, r2 = -1
    bne 6f                              @ if match, branch to handle [ELSE]
    
2:  ldr r2, =word_then
    mov r3, #word_then_len
    bl __compare_word                   @ compare the word with [THEN]
    cmp r2, #0                          @ if match, r2 = -1
    bne 4f                              @ if match, branch to handle [THEN]
    @ Not [ELSE] or [THEN], so continue parsing words
    b 1b

3:  @ We have a nested [IF], increment the nested level counter
    add r4, #1                          @ increment nested level counter
    b 1b

4:  @ We have [THEN], decrement the nested level counter
    subs r4, #1                         @ decrement nested level counter
    bmi 6f                              @ if so, branch to return
    b 1b

5:  bl __refill
    cmp r1, #0                          
    bne 1b                              @ if refilled, continue parsing words  

6:  pop {r4, pc}



    @ 15.6.2.2531 [ELSE] “bracket-else”
    @
    @   Skipping leading spaces, parse and discard space-delimited words from the parse area,
    @   including nested occurrences of [IF] ... [THEN] and [IF] ... [ELSE] ...
    @   [THEN], until the word [THEN] has been parsed and discarded. If the parse area becomes
    @   exhausted, it is refilled as with REFILL. [ELSE] is an immediate word.

    .global _bracket_else
    .thumb_func
_bracket_else:
    bl __bracket_else
    NEXT

    .global __bracket_else
    .thumb_func
__bracket_else:
    push {r4, lr}
    eor r4, r4                          @ r4 = nested level counter

1:  mov r0, #0x20                       @ space delimiter
    mov r1, #1
    bl __parse                          @ skip initial delimiters
    cmp r1, #0
    beq 5f                              @ if no word, branch to refill

    @ Is it [IF]?
    ldr r2, =word_if
    mov r3, #word_if_len
    bl __compare_word                   @ compare the word with [IF]
    cmp r2, #0                          @ if match, r2 = -1
    bne 3f                              @ if match, branch to handle [IF]

    @ Is it [THEN]?
2:  ldr r2, =word_then
    mov r3, #word_then_len
    bl __compare_word                   @ compare the word with [THEN]
    cmp r2, #0                          @ if match, r2 = -1
    bne 4f                              @ if match, branch to handle [THEN]
    @ Not [THEN], so continue parsing words
    b 1b

3:  @ We have a nested [IF], increment the nested level counter
    add r4, #1                          @ increment nested level counter
    b 1b

4:  @ We have [THEN], decrement the nested level counter
    subs r4, #1                         @ decrement nested level counter
    bmi 6f                              @ if so, branch to return
    b 1b

5:  bl __refill
    cmp r1, #0                          
    bne 1b                              @ if refilled, continue parsing words  

6:  pop {r4, pc}


    @   Perform a case-insensitive comparison of a word with a search string
    @
    @   Paramters:
    @       r0 - address of the word to compare
    @       r1 - length of the word to compare
    @       r2 - address of the search string
    @       r3 - length of the search string
    @   Output:
    @       r0 - address of the word to compare
    @       r1 - length of the word to compare
    @       r2 - -1 for match, 0 for no match
    .global __compare_word
    .thumb_func
__compare_word:
    push {r4-r7, lr}
    mov r6, r0                          @ r4 = address of the word to compare
    mov r7, r1                          @ r5 = length of the word to compare
    @ check lengths match
    cmp r1, r3                          @ compare lengths
    bne 4f                              @ if different, no match
    
    @ compare characters
1:  ldrb r4, [r0], #1                   @ load char from first string
    ldrb r5, [r2], #1                   @ load char from second string
    
    @ convert first char to uppercase if lowercase
    cmp r4, #'a'
    blt 2f
    cmp r4, #'z'
    bgt 2f
    sub r4, #32                         @ convert to uppercase
    
    @ convert second char to uppercase if lowercase
2:  cmp r5, #'a'
    blt 3f
    cmp r5, #'z'
    bgt 3f
    sub r5, #32                         @ convert to uppercase
    
3:  cmp r4, r5                          @ compare chars
    bne 4f                              @ if different, no match
    subs r1, #1                         @ decrement length
    bne 1b                              @ if not zero, continue comparing
    
    @ match found
    mov r0, r6                          @ restore address of the word
    mov r1, r7                          @ restore length of the word
    mov r2, #-1                         @ return -1 for match
    pop {r4-r7, pc}
    
4:  @ no match
    mov r0, r6                          @ restore address of the word
    mov r1, r7                          @ restore length of the word
    mov r2, #0                          @ return 0 for no match
    pop {r4-r7, pc}


    .balign 4
    .equ word_if_len, 4
word_if:
    .ascii "[IF]"

    .balign 4
    .equ word_else_len, 6
word_else:
    .ascii "[ELSE]"
    
    .balign 4
    .equ word_then_len, 6
word_then:
    .ascii "[THEN]"


    @   6.1.1550    FIND ( c-addr — c-addr 0 | xt 1 | xt -1 )
    @
    @   Find the definition named in the counted string at c-addr. If the definition is not found, return
    @   c-addr and zero. If the definition is found, return its execution token xt. If the definition is
    @   immediate, also return one (1), otherwise also return minus-one (-1). For a given string, the
    @   values returned by FIND while compiling may differ from those returned while not compiling.
    .global _find
    .thumb_func
_find:
    popd r0                            @ address of the search string
    bl __find
    pushd r0                           @ address of dictionary entry
    pushd r1                           @ 0 = not found, 1 = immediate, -1 = otherwise
    NEXT

    @   Parameters:
    @       r0 - address of the search string (counted string)
    @   Output:
    @       r0 - execution token xt of the word in the dictionary (or address of the search string if not found)
    @       r1 - 0 if not found, 1 if immediate, -1 if not immediate

    .global __find
    .thumb_func
__find:
    push {r4-r7}

    ldr r2, =var_LATEST
    ldr r2, [r2]                        @ load the address of the latest word in the dictionary
 1: mov r7, r2
    cmp r7, #0                          @ end of dictionary?
    beq 6f
    ldrb r1, [r0]                       @ length of the search string
    add r7, #4                          @ address of the current word's name
    ldrb r3, [r7], #1                   @ flags + length field of current entry
    and r3, #CB_SMUDGE|CB_LENGTH        @ name length + smudge flag
    cmp r3, r1                          @ length is the same? (smudge flag set will corrupt the comparison)
    bne 5f                              @ no, so skip to next entry.   

    @ same length, compare the names
    add r6, r0, #1                      @ move past length byte
2:  ldrb r4, [r6], #1                   @ load char from the search string
    ldrb r5, [r7], #1                   @ load char from the current entry name

    @ convert search character to uppecase if it's lowercase
    cmp r4, #'a'
    blt 3f
    cmp r4, #'z'
    bgt 3f
    sub r4, #32                         @ convert to uppercase by subtracting 32

    @ convert entry name character to uppercase if it's lowercase
3:  cmp r5, #'a'
    blt 4f
    cmp r5, #'z'
    bgt 4f
    sub r5, #32                         @ convert to uppercase by subtracting 32

    @ comapre the uppercase characters
4:  cmp r4, r5
    bne 5f                              @ not the same, so skip to next entry
    subs r1, #1
    bne 2b                              @ if not zero, continue comparing characters    
    
    @ the search string matches the current entry
    ldrb r1, [r2, #4]
    ands r1, #CB_PRECEDENCE             @ is precedence flag set?
    ite ne
    movne r1, #1                        @ if not 0 (precendence), return 1
    moveq r1, #-1                       @ otherwise, return -1
    add r2, #8
    add r2, r3
    and r0, r2, #~3
    pop {r4-r7}                         @ return to caller
    bx lr

    @ not the same, so check the next entry
5:  ldr r2, [r2]                        @ move to the previous word
    b 1b

6:  @ Not found.
    eor r1, r1                          @ c-addr in r0, and zero int r1 to indicate not found
    pop {r4-r7}
    bx lr

    
    .global __find_entry
    .thumb_func
__find_entry:
    push {r4-r7}

    ldr r2, =var_LATEST
    ldr r2, [r2]                        @ load the address of the latest word in the dictionary
 1: mov r7, r2
    cmp r7, #0                          @ end of dictionary?
    beq 5f
    ldrb r1, [r0]                       @ length of the search string
    add r7, #4                          @ address of the current word's name
    ldrb r3, [r7], #1                   @ flags + length field of current entry
    and r3, #CB_SMUDGE|CB_LENGTH        @ name length + smudge flag
    cmp r3, r1                          @ length is the same? (smudge flag set will corrupt the comparison)
    bne 6f                              @ no, so skip to next entry.   

    @ same length, compare the names
    add r6, r0, #1                      @ move past length byte
2:  ldrb r4, [r6], #1                   @ load char from the search string
    ldrb r5, [r7], #1                   @ load char from the current entry name

    @ convert search character to uppecase if it's lowercase
    cmp r4, #'a'
    blt 3f
    cmp r4, #'z'
    bgt 3f
    sub r4, #32                         @ convert to uppercase by subtracting 32

    @ convert entry name character to uppercase if it's lowercase
3:  cmp r5, #'a'
    blt 4f
    cmp r5, #'z'
    bgt 4f
    sub r5, #32                         @ convert to uppercase by subtracting 32

    @ comapre the uppercase characters
4:  cmp r4, r5
    bne 6f                              @ not the same, so skip to next entry
    subs r1, #1
    bne 2b                              @ if not zero, continue comparing characters    
    
    @ the search string matches the current entry
5:  mov r0, r2
    pop {r4-r7}                         @ return to caller
    bx lr

    @ not the same, so check the next entry
6:  ldr r2, [r2]                        @ move to the previous word
    b 1b


    .global __to_cfa
    .thumb_func
__to_cfa:
    add r0, #4                          @ r0 = address of the name field   
    ldrb r1, [r0], #1                   @ r1 = flags+length field of current entry
    and r1, #CB_LENGTH                  @ r1 = length of name (remove fields)
    add r0, r1                          @ r0 = address of the code field
    add r0, #3                          @ The codeword is 4-byte aligned.
    and r0, #~3
    bx lr                               @ return to caller

@
@   Input source state
@
    .data
    .balign 4
    .global input_source
input_source:
    .word terminal_input_buffer
    .word TERMINAL_INPUT_BUFFER_SIZE
