@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Facility wordset.
@

    .include "forth.inc"

    .text

    .global _keyq
    .thumb_func
_keyq:
    bl __key_available
    pushd r0
    NEXT


    @ Temporary, ekey returns char, so do nothing and say conversion is successful
    .global _key_to_char
    .thumb_func
_key_to_char:
    mov r0, #-1
    pushd r0
    NEXT


    .global _at_xy
    .thumb_func
_at_xy:
    mov r0, #0x1B                       @ ASCII escape character
    bl __emit
    mov r0, #0x5B                       @ ASCII '['
    bl __emit
    popd r0
    bl __u_dot                          @ convert y to string and print
    mov r0, #0x3B                       @ ASCII ';'
    bl __emit
    popd r0
    bl __u_dot                          @ convert x to string and print
    mov r0, #0x48                       @ ASCII 'H'
    bl __emit
    NEXT


    .global _page
    .thumb_func
_page:
    ldr r0, =vt100_clear
    bl __type_cstr
    NEXT

vt100_clear:
    .ascii "\033[2J\033[H"
    .balign 4


    .global _battery
    .thumb_func
_battery:
    bl read_battery
    pushd r0
    NEXT
