//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#pragma once

// These functions must be implemented to support the terminal interface
void terminal_init();

// Terminal Input
bool __key_available();
int __key();

// Terminal Output
bool __emit_available();
void __emit(char ch);


// External references (implemented in assembly)
extern void __type_error(int error_code);
extern void forth_start();
extern void _quit();
