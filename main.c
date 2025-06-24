//
//  ANS Forth for the Clockwork PicoCalc
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#include "pico/stdlib.h"
#include "hardware/clocks.h"
#include "terminal.h"

extern void forth_start(); // Implemented in assembly


//
// The entry point for the Forth interpreter
//

int main()
{
    __init();
    forth_start();
}