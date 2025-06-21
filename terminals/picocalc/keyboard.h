//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#pragma once

#define I2C_KBD_MOD         i2c1
#define I2C_KBD_SDA         6
#define I2C_KBD_SCL         7

#define I2C_KBD_SPEED       10000       // if dual i2c, then the speed of keyboard i2c should be 10khz
#define I2C_KBD_ADDR        0x1F

#define REG_ID_VER          0x01        // fw version
#define REG_ID_CFG          0x02        // config
#define REG_ID_INT          0x03        // interrupt status
#define REG_ID_KEY          0x04        // key status
#define REG_ID_BKL          0x05        // backlight
#define REG_ID_DEB          0x06        // debounce cfg
#define REG_ID_FRQ          0x07        // poll freq cfg
#define REG_ID_RST          0x08        // reset
#define REG_ID_FIF          0x09        // fifo
#define REG_ID_BK2          0x0A        // keyboard backlight
#define REG_ID_BAT          0x0b        // battery
#define REG_ID_C64_MTX      0x0c        // read c64 matrix
#define REG_ID_C64_JS       0x0d        // joystick io bits

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

#define BUFFER_SIZE         32

void keyboard_init();
bool keyboard_key_available();
int keyboard_get_key();
int read_battery();
