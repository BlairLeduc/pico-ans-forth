//
//  ANS Forth for the Clockwork PicoCalc
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#pragma once

#define KBD_SDA             6
#define KBD_SCL             7

#define KBD_BAUDRATE       10000        // if dual i2c, then the speed of keyboard i2c should be 10khz
#define KBD_ADDR            0x1F

#define KBD_REG_VER         0x01        // fw version
#define KBD_REG_CFG         0x02        // config
#define KBD_REG_INT         0x03        // interrupt status
#define KBD_REG_KEY         0x04        // key status
#define KBD_REG_BKL         0x05        // backlight
#define KBD_REG_DEB         0x06        // debounce cfg
#define KBD_REG_FRQ         0x07        // poll freq cfg
#define KBD_REG_RST         0x08        // reset
#define KBD_REG_FIF         0x09        // fifo
#define KBD_REG_BK2         0x0A        // keyboard backlight
#define KBD_REG_BAT         0x0b        // battery

#define KEY_MOD_ALT         0xA1
#define KEY_MOD_SHL         0xA2
#define KEY_MOD_SHR         0xA3
#define KEY_MOD_SYM         0xA4
#define KEY_MOD_CTRL        0xA5

#define KEY_STATE_IDLE      0
#define KEY_STATE_PRESSED   1
#define KEY_STATE_HOLD      2
#define KEY_STATE_RELEASED  3

#define KEY_ESC             0xB1
#define KEY_UP              0xB5
#define KEY_DOWN            0xB6
#define KEY_LEFT            0xB4
#define KEY_RIGHT           0xB7

#define KEY_BREAK           0xd0
#define KEY_INSERT          0xD1
#define KEY_HOME            0xD2
#define KEY_DEL             0xD4
#define KEY_END             0xD5
#define KEY_PAGE_UP         0xd6
#define KEY_PAGE_DOWN       0xd7

#define KEY_CAPS_LOCK       0xC1

#define KEY_F1              0x81
#define KEY_F2              0x82
#define KEY_F3              0x83
#define KEY_F4              0x84
#define KEY_F5              0x85
#define KEY_F6              0x86
#define KEY_F7              0x87
#define KEY_F8              0x88
#define KEY_F9              0x89
#define KEY_F10             0x90

#define KBD_BUFFER_SIZE     32

void keyboard_init();
bool keyboard_key_available();
int keyboard_get_key();

int read_battery();
