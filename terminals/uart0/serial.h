//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#pragma once  

// UART defines
#define UART_BAUDRATE       115200
#define UART_DATABITS       8
#define UART_STOPBITS       1
#define UART_PARITY         UART_PARITY_NONE

#define UART_TX             0
#define UART_RX             1

#define UART_BUFFER_SIZE    256

void serial_init();
bool serial_key_available();
int serial_get_key();
bool serial_emit_available();
void serial_emit(char ch);
