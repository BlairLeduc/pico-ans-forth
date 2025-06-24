//
//  ANS Forth for the Clockwork PicoCalc
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#pragma once

// These functions must be implemented to support the terminal interface
void __init();

// Terminal Input
bool __key_available();
int __key();

// Terminal Output
bool __emit_available();
void __emit(char ch);

