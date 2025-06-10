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

    .global _dspfetch
_dspfetch:
    mov r0, r8
    pushd r0
    NEXT

    .global _comma
_comma:
    popd r0
    bl _comma
    NEXT

    .global __comma
__comma:
    movw r1, :lower16:var_DP            @ load the address of DP
    movt r1, :upper16:var_DP
    ldr r2, [r1]                        @ get the address of HERE
    str r0, [r2], #4                    @ store the data at HERE, then increment HERE
    str r2, [r1]                        @ update HERE in HERE's storage
    bx lr                               @ return to caller

    .global _rbrac
_rbrac:
    eor r0, r0                          @ clear r0
    movw r0, :lower16:var_STATE         @ load the address of STATE
    movt r0, :upper16:var_STATE
    str r0, [r1]                        @ set STATE to 0
    NEXT

    .global _lbrac
_lbrac:
    mov r0, #1
    movw r0, :lower16:var_STATE         @ load the address of STATE
    movt r0, :upper16:var_STATE
    str r0, [r1]                        @ set STATE to 1.
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

    .global _allot
_allot:
    popd r0                             @ Get the number of bytes to allot
    movw r1, :lower16:var_DP            @ Load the address of DP
    movt r1, :upper16:var_DP
    ldr r2, [r1]                        @ Get the current value of DP
    add r2, r0                          @ Add the number of bytes to allot
    str r2, [r1]                        @ Update DP with the new value
    NEXT

    .global _unused
_unused:
    movw r0, :lower16:var_DP            @ Load the address of DP
    movt r0, :upper16:var_DP
    movw r1, :lower16:data_space_bottom @ Load the address of the bottom of data space
    movt r1, :upper16:data_space_bottom
    ldr r2, [r0]                        @ Get the current value of DP
    subs r2, r1, r2                     @ Subtract the bottom of data space from DP
    pushd r2                            @ Push the result onto the data stack
    NEXT
