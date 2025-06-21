//
//  ANS Forth for the Pico 2
//  Copyright Blair Leduc.
//  See LICENSE for details.
//

#pragma once

#include "font.h"

//
// PicoCalc LCD display definitions
//

#define LCD_SCL         (10)            // serial clock (SCL)
#define LCD_SDI         (11)            // serial data in (SDI)
#define LCD_SDO         (12)            // serial data out (SDO)
#define LCD_CSX         (13)            // chip select (CSX)
#define LCD_DCX         (14)            // data/command (D/CX)
#define LCD_RST         (15)            // reset (RESET)

#define LCD_BAUDRATE    (75000000)      // 75 MHz SPI clock speed

#define LCD_CMD_NOP     (0x00)          // no operation
#define LCD_CMD_SWRESET (0x01)          // software reset
#define LCD_CMD_SLPIN   (0x10)          // sleep in
#define LCD_CMD_SLPOUT  (0x11)          // sleep out
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
#define LCD_CMD_PWR1    (0xC0)          // power control 1
#define LCD_CMD_PWR2    (0xC1)          // power control 2
#define LCD_CMD_VCMPCTL (0xC5)          // VCOM control
#define LCD_CMD_PGC     (0xE0)          // positive gamma control
#define LCD_CMD_NGC     (0xE1)          // negative gamma control
#define LCD_CMD_E9      (0xE9)          // adjust control 
#define LCD_CMD_F7      (0xF7)          // adjust control 3

#define WIDTH           (320)
#define HEIGHT          (320)
#define MEM_HEIGHT      (480) 

#define RGB(r,g,b)      ((uint16_t)(((r) >> 3) << 11 | ((g) >> 2) << 5 | (b >> 3)))
#define UPPER8(x)       ((x) >> 8)      // upper byte of a 16-bit value
#define LOWER8(x)       ((x) & 0xFF)    // lower byte of a 16-bit value

//
// PicoCalc display definitions
//

// Processing ANSI escape sequences is a small state machine
#define STATE_NORMAL    0
#define STATE_ESCAPE    1
#define STATE_CONTROL   2

#define DEFAULT_FOREGROUND          8   // white phosphor
#define DEFAULT_BACKGROUND          0   // black
#define CURSOR_COLOR                8   // white phosphor
#define COLUMNS     (WIDTH/GLYPH_WIDTH) // number of glyphs that fit in a line
#define ROWS        (HEIGHT/GLYPH_HEIGHT) // number of lines that fit in a page
#define MAX_COL     (COLUMNS - 1)       // maximum column index (0-based)
#define MAX_ROW     (ROWS - 1)          // maximum row index (0-based)


void display_init();
bool display_emit_available();
void display_emit(char c);