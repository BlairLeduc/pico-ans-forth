//
//  ANS Forth for the Clockwork PicoCalc
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#pragma once

#include "font.h"

// Raspberry Pi Pico board GPIO pins
#define LCD_SCL         (10)            // serial clock (SCL)
#define LCD_SDI         (11)            // serial data in (SDI)
#define LCD_SDO         (12)            // serial data out (SDO)
#define LCD_CSX         (13)            // chip select (CSX)
#define LCD_DCX         (14)            // data/command (D/CX)
#define LCD_RST         (15)            // reset (RESET)


// LCD interface definitions
// According to the ST7789P datasheet, the maximum SPI clock speed is 62.5 MHz.
// However, the controller can handle 75 MHz in practice.
#define LCD_BAUDRATE    (75000000)      // 75 MHz SPI clock speed


// LCD command definitions
#define LCD_CMD_NOP     (0x00)          // no operation
#define LCD_CMD_SWRESET (0x01)          // software reset
#define LCD_CMD_SLPIN   (0x10)          // sleep in
#define LCD_CMD_SLPOUT  (0x11)          // sleep out
#define LCD_CMD_INVOFF  (0x20)          // display inversion off
#define LCD_CMD_INVON   (0x21)          // display inversion on
#define LCD_CMD_DISPOFF (0x28)          // display off
#define LCD_CMD_DISPON  (0x29)          // display on
#define LCD_CMD_CASET   (0x2A)          // column address set
#define LCD_CMD_RASET   (0x2B)          // row address set
#define LCD_CMD_RAMWR   (0x2C)          // memory write
#define LCD_CMD_RAMRD   (0x2E)          // memory read
#define LCD_CMD_VSCRDEF (0x33)          // vertical scroll definition
#define LCD_CMD_MADCTL  (0x36)          // memory access control
#define LCD_CMD_VSCSAD  (0x37)          // vertical scroll start address of RAM
#define LCD_CMD_COLMOD  (0x3A)          // pixel format set
#define LCD_CMD_IFMODE  (0xB0)          // interface mode control
#define LCD_CMD_FRMCTR1 (0xB1)          // frame rate control (in normal mode)
#define LCD_CMD_FRMCTR2 (0xB2)          // frame rate control (in idle mode)
#define LCD_CMD_FRMCTR3 (0xB3)          // frame rate control (in partial mode)
#define LCD_CMD_DIC     (0xB4)          // display inversion control
#define LCD_CMD_DFC     (0xB6)          // display function control
#define LCD_CMD_EMS     (0xB7)          // entry mode set
#define LCD_CMD_MODESEL (0xB9)          // mode set
#define LCD_CMD_PWR1    (0xC0)          // power control 1
#define LCD_CMD_PWR2    (0xC1)          // power control 2
#define LCD_CMD_PWR3    (0xC2)          // power control 3
#define LCD_CMD_VCMPCTL (0xC5)          // VCOM control
#define LCD_CMD_PGC     (0xE0)          // positive gamma control
#define LCD_CMD_NGC     (0xE1)          // negative gamma control
#define LCD_CMD_DOCA    (0xE8)          // driver output control
#define LCD_CMD_E9      (0xE9)          // Manufacturer command
#define LCD_CMD_F0      (0xF0)          // Manufacturer command
#define LCD_CMD_F7      (0xF7)          // Manufacturer command


// Processing ANSI escape sequences is a small state machine. These
// are the states.
#define STATE_NORMAL    (0)             // normal state
#define STATE_ESCAPE    (1)             // escape character received
#define STATE_CS        (2)             // control sequence introducer (CSI) received


// Display parameters
#define WIDTH           (320)           // pixels across the LCD
#define HEIGHT          (320)           // pixels down the LCD
#define FRAME_HEIGHT    (480)           // frame memory height in pixels
#define COLUMNS         (WIDTH>>3)      // number of glyphs that fit in a line
#define ROWS            (HEIGHT/GLYPH_HEIGHT) // number of lines that fit on the LCD
#define MAX_COL         (COLUMNS - 1)   // maximum column index (0-based)
#define MAX_ROW         (ROWS - 1)      // maximum row index (0-based)


// Handy macros
#define RGB(r,g,b)      ((uint16_t)(((r) >> 3) << 11 | ((g) >> 2) << 5 | ((b) >> 3)))
#define UPPER8(x)       ((x) >> 8)      // upper byte of a 16-bit value
#define LOWER8(x)       ((x) & 0xFF)    // lower byte of a 16-bit value


// Defaults
#define FOREGROUND      RGB(216, 240, 255)  // white phosphor
#define BACKGROUND      RGB(0, 0, 0)        // black 
#define BRIGHT          RGB(255, 255, 255)  // white


// Function prototypes
void display_init();
bool display_emit_available();
void display_emit(char c);