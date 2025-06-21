@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Exception wordset.
@

    .include "forth.inc"

    .text

    .global _catch
    .thumb_func
_catch:
    popd r0
    pushr r5                            @ save instruction pointer after CATCH   
    pushr r7                            @ save floating point stack pointer
    mov r1, #-1                         @ mark the exception frame with -1
    pushr r1                            @ push 0 to mark exception frame
    ldr r1, =catch_return
    pushr r1                            @ push the return address
    ldr r0, [r0]                        @ get the address of the code field
    orr r0, #1                          @ set the thumb bit
    blx r0                              @ execute
_catch_finish:
    popr r0                             @ remove the exception frame
    popr r0
    popr r0
    popr r0
    eor r0, r0
    pushd r0                            @ push 0 to state no throw occurred    
    NEXT
catch_return:
    .word _catch_finish

    .global _throw
    .thumb_func
_throw:
    popd r0
    bl __throw
    NEXT

    .global __throw
    .thumb_func
__throw:
    cmp r0, #0
    bne 1f  
    bx lr                               @ No exception, return to caller                    
    
1:  push {r4-r7, lr}

    @ Find the top-mode exception frame
    movw r1, :lower16:return_stack_top
    movt r1, :upper16:return_stack_top
2:  cmp r6, r1
    bge 3f                              @ if the return stack is empty, no exception frame
    popr r2
    cmp r2, #-1                         @ the exception frame starts with a 0 value   
    bne 2b

    @ We have an exception frame, so we can return to the CATCH
    popr r7                             @ load floating point stack pointer
    popr r5                             @ load instruction pointer after CATCH
    pushd r0   
    pop {r4-r7, pc}

3:  @ No exception frame, abort
    cmp r0, #-1
    beq 5f                              @ if r0 is -1, abort, no message
    cmp r0, #-2
    bne 4f                              @ if r0 is not -2, display the error message   
    @ if r0 is -2, abort with message  
    popd r1                             @ pop the message length                           
    popd r0                             @ pop the message address
    bl __type
    pop {r4-r7, lr}
    b _quit                             @ ABORT

4:  bl __type_error                     @ deplay the error message
5:  pop {r4-r7, lr}
    b _quit                             @ ABORT
