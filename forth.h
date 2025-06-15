//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#ifndef FORTH_H
#define FORTH_H

void on_uart_rx();
void on_hardware_fault();

void check_for_user_interrupt();

int __key_available();
int __key();

bool __emit_available();
void __emit(char ch);
void __type(const char *str, int len);
void __type_cstr(const char *str);
int __accept(char *buffer, int len);
void __type_error(int error_code);

void hardware_init();

// Assembly functions
void forth_start();
void _quit();

#endif // FORTH_H