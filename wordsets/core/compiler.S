@
@   Leduc Forth - a simple FORTH compiler/interpreter for the PicoCalc
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
@   |   4    |   4    | 1 | 1 | 1 | .. | 1 | 1 | 1 | 1 |     4      |   4    | ...  |   4    | bytes (aligned)*
@   +--------+--------+---+---+---+-..-+---+---+---+---+------------+--------+-...--+--------+
@   | LOCATE | Link   | b | c | c | .. | c | c | 0 | 0 | a-addr     | x      | ...  | x      |
@   +-^------+-^------+-^-+---+---+-..-+---+---+---+---+------------+--------+-...--+--------+
@     |        |        |                      |  pad  | <- to align code field*
@     |        |       control bits/name length
@     |        |
@     |       Link to the previous defined word (points to the link field of the previous word)
@     |
@    Locates the source code of the word (Link - 4 bytes)
@
@   * Allignment is to a 4 byte boundary



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

    .section .text

    @   6.1.0150 , ( x -- ) “comma”
    @
    @   Reserve one cell of data space and store x in the cell. If the data-space pointer is aligned when
    @   ","" begins execution, it will remain aligned when "," finishes execution. An ambiguous condition
    @   exists if the data-space pointer is not aligned prior to execution of ",".

    .global _comma
_comma:
    popd r0
    bl _comma
    NEXT

    .global __comma
__comma:
    movw r1, :lower16:var_DP            @ load the address of the DP variable
    movt r1, :upper16:var_DP
    ldr r2, [r1]
    str r0, [r2], #4                    @ store the data
    str r2, [r1]                        @ update DP
    bx lr


    @   6.1.2540 ] ( -- ) “right-bracket”
    @
    @   Enter compilation state.

    .global _rbrac
_rbrac:
    mov r0, #1
    movw r0, :lower16:var_STATE         @ load the address of STATE
    movt r0, :upper16:var_STATE
    str r0, [r1]                        @ set STATE to 1
    NEXT


    @   6.1.2500 [ “left-bracket”
    @
    @   Compilation:
    @       Perform the execution semantics given below.
    @   Execution: ( -- )
    @       Enter interpretation state. [ is an immediate word.

    .global _lbrac
_lbrac:
    eor r0, r0                          @ clear r0
    movw r0, :lower16:var_STATE         @ load the address of STATE
    movt r0, :upper16:var_STATE
    str r0, [r1]                        @ set STATE to 0 (interpretation state)
    NEXT


    @   6.1.2510 ['] "bracket-tick"
    @
    @   Compilation: ( “<spaces>name” -- )
    @       Skip leading space delimiters. Parse name delimited by a space. Find name. Append the run-
    @       time semantics given below to the current definition.
    @       An ambiguous condition exists if name is not found.
    @   Run-time: ( -- xt )
    @       Place name’s execution token xt on the stack. The execution token returned by the compiled
    @       phrase "['] X " is the same value returned by "' X " outside of compilation state.

    .global _bracket_tick
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
_branch:
    ldr r0, [r5]                        @ Get the address of the next word and skip it.
    add r5, r0                          @ Add the offset to the instruction pointer.
    NEXT

    .global _zbranch
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
_create:
    push {r4-r5}
    ldr r4, =var_DP
    ldr r5, [r4]                        @ get the current value of DP
    eor r0, r0
    str r0, [r5], #4                    @ store the locate field (0)
    ldr r0, =var_LATEST
    ldr r1, [r0]                        @ get the address of LATEST
    str r1, [r5]                        @ store the link field (address of the previous word)
    str r5, [r0]                        @ update LATEST to point to the new word
    add r5, #4                          @ move to the name field
    str r5, [r4]                        @ update DP
    mov r0, #0x20                       @ ASCII ' '
    bl __word                           @ parse the name
    add r5, r1
    add r5, #4
    and r5, #~3                         @ align the DP to a 4-byte boundary
    str r5, [r4]                        @ update DP
    ldr r0, =_parameterField
    str r0, [r5], #4
    pushd r5                            @ push the address of the parameter field onto the data stack
    pop {r4-r5}
    NEXT

    .global _parameterField
_parameterField:
    pushd r5
    NEXT


    @   6.2.2395    UNUSED ( -- u )
    @
    @   u is the amount of space remaining in the region addressed by HERE , in address units.

    .global _unused
_unused:
    movw r0, :lower16:var_DP
    movt r0, :upper16:var_DP
    movw r1, :lower16:data_space_top
    movt r1, :upper16:data_space_top
    ldr r2, [r0]                        @ Get the current value of DP
    subs r2, r1, r2                     @ Subtract the bottom of data space from DP
    pushd r2                            @ Push the result onto the data stack
    NEXT
