@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (compiler)
@

    .include "forth.inc"

@
@   Dictionary definition structure
@
@   |                  header                          | code field | data fields            |
@   |   4    |   4    | 1 | 1 | 1 | .. | 1 | 1 | 1 | 1 |     4      |   4    | ...  |   4    | bytes (aligned) †
@   +--------+--------+---+---+---+-..-+---+---+---+---+------------+--------+-...--+--------+
@   | LOCATE | Link   | b | c | c | .. | c | c | 0 | 0 | a-addr     | x      | ...  | x      |
@   +-^------+-^------+-^-+---+---+-..-+---+---+---+---+------------+--------+-...--+--------+
@     |        |        |                      |  pad  | <- to align code field †
@     |        |       control bits/name length
@     |        |
@     |       Link to the previous defined word (points to the link field of the previous word)
@     |
@    Locates the source code of the word
@
@   † Allignment is to a 4-byte boundary



@
@   MARK: Branching
@
@   It turns out that all you need in order to define looping constructs, IF-statements, etc.
@   are two primitives.
@
@   BRANCH is an unconditional branch. 0BRANCH is a conditional branch (it only branches if the
@   top of stack is zero).
@
@   The diagram below shows how BRANCH works in some imaginary compiled word.  When BRANCH executes,
@   r5 starts by pointing to the offset field (compare to LIT above):
@
@   +---------------------+-------+---- - - ---+------------+------------+---- - - - ----+------------+
@   | (Dictionary header) | DOCOL |            | BRANCH     | offset     | (skipped)     | word       |
@   +---------------------+-------+---- - - ---+------------+-----|------+---- - - - ----+------------+
@                                                              ^  |                       ^
@                                                              |  |                       |
@                                                              |  +-----------------------+
@                                                             r5 added to offset
@
@   The offset is added to r5 to make the new r5, and the result is that when NEXT runs, execution
@   continues at the branch target.  Negative offsets work as expected.
@
@   0BRANCH is the same except the branch happens conditionally.
@
@   Now standard FORTH words such as IF, THEN, ELSE, WHILE, REPEAT, etc. can be implemented entirely
@   in FORTH.  They are IMMEDIATE words which append various combinations of BRANCH or 0BRANCH
@   into the word currently being compiled.
@
@   As an example, code written like this:
@
@       condition-code IF true-part THEN rest-code
@
@   compiles to:
@
@       condition-code 0BRANCH OFFSET true-part rest-code
@                                 |             ^
@                                 |             |
@                                 +-------------+

    .text

    @   6.1.0150    , ( x -- )                          “comma”
    @
    @   Reserve one cell of data space and store x in the cell. If the data-space pointer is aligned when
    @   "," begins execution, it will remain aligned when "," finishes execution. An ambiguous condition
    @   exists if the data-space pointer is not aligned prior to execution of ",".

    .global _comma
    .thumb_func
_comma:
    popd r0
    bl __comma
    NEXT

    .global __comma
    .thumb_func
__comma:
    movw r1, :lower16:var_DP            @ load the address of the DP variable
    movt r1, :upper16:var_DP
    ldr r2, [r1]
    str r0, [r2], #4                    @ store the data
    str r2, [r1]                        @ update DP
    bx lr


    @   6.1.2540    ] ( -- )                            “right-bracket”
    @
    @   Enter compilation state.

    .global _rbrac
    .thumb_func
_rbrac:
    mov r0, #1
    movw r0, :lower16:var_STATE         @ load the address of STATE
    movt r0, :upper16:var_STATE
    str r0, [r1]                        @ set STATE to 1
    NEXT


    @   6.1.2500 [                                      “left-bracket”
    @
    @   Compilation:
    @       Perform the execution semantics given below.
    @   Execution: ( -- )
    @       Enter interpretation state. [ is an immediate word.

    .global _lbrac
    .thumb_func
_lbrac:
    eor r0, r0                          @ clear r0
    movw r0, :lower16:var_STATE         @ load the address of STATE
    movt r0, :upper16:var_STATE
    str r0, [r1]                        @ set STATE to 0 (interpretation state)
    NEXT


    @   6.1.2510 [']                                    "bracket-tick"
    @
    @   Compilation: ( “<spaces>name” -- )
    @       Skip leading space delimiters. Parse name delimited by a space. Find name. Append the run-
    @       time semantics given below to the current definition.
    @       An ambiguous condition exists if name is not found.
    @   Run-time: ( -- xt )
    @       Place name’s execution token xt on the stack. The execution token returned by the compiled
    @       phrase "['] X " is the same value returned by "' X " outside of compilation state.

    .global _bracket_tick
    .thumb_func
_bracket_tick:
    @ Compilation
    bl __tick
    movw r1, :lower16:var_DP            @ load the address of the DP variable
    movt r1, :upper16:var_DP
    ldr r2, [r1]
    @ Run-time
    ldr r3, =LIT
    str r3, [r2], #4                    @ store LIT
    str r0, [r2], #4                    @ store the execution token xt
    str r2, [r1]                        @ update DP
    NEXT


    .global _branch
    .thumb_func
_branch:
    ldr r0, [r5]                        @ Get the address of the next word and skip it.
    add r5, r0                          @ Add the offset to the instruction pointer.
    NEXT

    .global _zbranch
    .thumb_func
_zbranch:
    popd r0
    cmp r0, #0                          @ top of stack is zero?
    beq _branch                         @ if so, jump back to the branch function above
    ldr r0, [r5], #4
    NEXT

    @   6.1.0710    ALLOT ( n -- )
    @
    @   If n is greater than zero, reserve n address units of data space. If n is less than zero, release |n|
    @   address units of data space. If n is zero, leave the data-space pointer unchanged.
    @
    @   If the data-space pointer is aligned and n is a multiple of the size of a cell when ALLOT begins
    @   execution, it will remain aligned when ALLOT finishes execution.
    @
    @   If the data-space pointer is character aligned and n is a multiple of the size of a character when
    @   ALLOT begins execution, it will remain character aligned when ALLOT finishes execution.

    .global _allot
    .thumb_func
_allot:
    popd r0                             @ get the number of bytes to allot
    movw r1, :lower16:var_DP
    movt r1, :upper16:var_DP
    ldr r2, [r1]                        @ get the current value of the DP
    mov r3, r2
    and r3, #3                          @ flag if the DP needs to be aligned to a 4-byte boundary
    add r2, r0                          @ add the number of bytes to the DP
    cmp r3, #0
    beq 1f                              @ should the DP be aligned? skip the alignment adjustment
    add r2, #3
    and r2, #~3                         @ align the DP to the next 4-byte boundary
1:  str r2, [r1]                        @ update DP with the new value
    NEXT


    @   6.1.1000 CREATE ( “<spaces>name” -- )
    @
    @   Skip leading space delimiters. Parse name delimited by a space. Create a definition for name
    @   with the execution semantics defined below. If the data-space pointer is not aligned, reserve
    @   enough data space to align it. The new data-space pointer defines name’s data field. CREATE
    @   does not allocate data space in name’s data field.
    @
    @   name Execution: ( -- a-addr )
    @       a-addr is the address of name’s data field. The execution semantics of name may be extended
    @       by using DOES>.

    .global _create
    .thumb_func
_create:
    bl __create
    pushd r0
    NEXT

    .global __create
    .thumb_func
__create:
    push {r4-r7, lr}

    ldr r4, =var_DP
    ldr r5, [r4]                        @ get the current value of DP
    eor r0, r0
    str r0, [r5], #4                    @ store the locate field (0)
    ldr r6, =var_LATEST
    ldr r7, [r6]                        @ get the address of LATEST
    str r7, [r5]                        @ store the link field (address of the previous word)
    mov r7, r5                          @ save the update to LATEST
    add r5, #4                          @ move to the name field
    str r5, [r4]                        @ update DP
    mov r0, #0x20                       @ ASCII ' '
    bl __word                           @ parse the name
    add r5, r1
    add r5, #4
    and r5, #~3                         @ align the DP to a 4-byte boundary
    ldr r2, =_paren_create
    str r2, [r5], #4
    str r5, [r4]
    mov r0, r7
    add r0, #4
    bl __find_entry
    cmp r0, #0                          @ check if the word was found, if not, exit
    beq 1f                              @ if not found, exit
    mov r0, #0x0D
    bl __emit
    mov r0, #0x0A
    bl __emit
    mov r0, r7
    ldrb r1, [r0, #4]!                  @ get the length/flags byte
    and r1, #CB_LENGTH                  @ get the length of the name
    add r0, #1
    bl __type
    ldr r0, =msg_not_unique
    ldr r1, =msg_not_unique_len
    bl __type
1:  str r7, [r6]                        @ update LATEST to point to the new word
    mov r0, r5                          @ set r0 to the address of the parameter field 
    pop {r4-r7, pc}

    .equ msg_not_unique_len, 15
msg_not_unique:
    .ascii " isn't unique. "
    .balign 4

    .global _does
    .thumb_func
_does:
    ldr r2, =var_DP
    ldr r2, [r2]                        @ get the current DP value
    ldr r3, =_dodoes
    str r3, [r2], #4                    @ store SLITERAL
    ldr r3, =PAREN_DOES
    str r3, [r2], #4                    @ store the (DOES>) address
    ldr r3, =var_DP
    str r2, [r3]                        @ update DP
    NEXT


    @   6.2.2395    UNUSED ( -- u )
    @
    @   u is the amount of space remaining in the region addressed by HERE , in address units.

    .global _unused
    .thumb_func
_unused:
    movw r0, :lower16:var_DP
    movt r0, :upper16:var_DP
    movw r1, :lower16:data_space_top
    movt r1, :upper16:data_space_top
    ldr r2, [r0]                        @ Get the current value of DP
    subs r2, r1, r2                     @ Subtract the bottom of data space from DP
    pushd r2                            @ Push the result onto the data stack
    NEXT


    @   6.1.0450    : ( —- ) “colon”
    @
    @   Skip leading space delimiters. Parse name delimited by a space. Create a definition for name,
    @   called a “colon definition”. Enter compilation state and start the current definition, producing
    @   colon-sys. Append the initiation semantics given below to the current definition.
    @
    @   The execution semantics of name will be determined by the words compiled into the body of
    @   the definition. The current definition shall not be findable in the dictionary until it is ended (or
    @   until the execution of DOES> in some systems).

    .global _colon
    .thumb_func
_colon:
    bl __create                         @ Create a new word
    ldr r1, =_docol
    str r1, [r0, #-4]                   @ Store the address of DOCOL in the word's code field
    ldr r1, =var_STATE
    mov r2, #1                          @ Set STATE to compilation state
    str r2, [r1]                        @ Update STATE to compilation state
    ldr r1, =var_LATEST
    ldr r1, [r1]                        @ Get the address of LATEST
    ldrb r0, [r1, #4]                   @ Get the length/flags
    orr r0, #CB_SMUDGE                  @ Set the smudge bit (hidden word)
    strb r0, [r1, #4]                   @ Update the length/flags byte
    NEXT

    @   6.1.0460    ; ( —- ) “semicolon”
    @
    @   Append the run-time semantics below to the current definition. End the current definition,
    @   allow it to be found in the dictionary and enter interpretation state, consuming colon-sys. If the
    @   data-space pointer is not aligned, reserve enough data space to align it.

    .global _semicolon
    .thumb_func
_semicolon:
    ldr r1, =var_DP
    ldr r2, [r1]                        @ Get the current value of DP
    ldr r0, =EXIT
    str r0, [r2], #4                    @ Store EXIT in the word's code field
    add r2, #3
    and r2, #~3                         @ Align DP to the next 4-byte boundary
    str r2, [r1]                        @ Update DP
    ldr r1, =var_LATEST
    ldr r1, [r1]                        @ Get the address of LATEST
    ldrb r0, [r1, #4]                   @ Get the length/flags
    and r0, #~CB_SMUDGE                 @ Remove the smudge bit (hidden word)
    strb r0, [r1, #4]                   @ Update the length/flags byte
    ldr r1, =var_STATE
    mov r0, #0                          @ Set STATE to interpretation state
    str r0, [r1]                        @ Update STATE to interpretation state
    NEXT

    @   6.1.2120    RECURSE
    @
    @   Append the execution semantics of the current definition to the current definition. An
    @   ambiguous condition exists if RECURSE appears in a definition after DOES>.

    .global _recurse
    .thumb_func
_recurse:
    ldr r1, =var_LATEST
    ldr r0, [r1]                        @ Get the address of LATEST
    bl __to_cfa
    ldr r2, =var_DP
    ldr r3, [r2]                        @ Get the current value of DP
    str r0, [r3], #4                    @ Store the address of the current definition in the code field
    str r3, [r2]                        @ Update DP to point to the next word
    NEXT

    @   6.2.0455    :NONAME ( -- xt )
    @
    @   Create a definition with no name. The execution semantics of the definition are given by the
    @   words compiled into the body of the definition. The execution token xt returned by :NONAME is
    @   the same value returned by :NONAME outside of compilation state.

    .global _colon_noname
    .thumb_func
_colon_noname:
    ldr r0, =var_DP
    ldr r1, [r0]                        @ Get the current value of DP
    pushd r1                            @ Push the execution token onto the data stack
    ldr r2, =_docol
    str r2, [r1], #4                    @ Store the address of DOCOL in the word's code field
    str r1, [r0]                        @ Update DP to point to the next word
    ldr r1, =var_STATE
    mov r2, #1                          @ Set STATE to compilation state
    str r2, [r1]                        @ Update STATE to compilation state
    NEXT


