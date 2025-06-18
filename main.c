//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#include "pico/stdlib.h"
#include "hardware.h"

//
// The entry point for the Forth interpreter
//

int main()
{
    terminal_init();
    forth_start();
}