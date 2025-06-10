@
@   Leduc Forth - a simple FORTH compiler/interpreter for the PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (constants)
@

    .include "forth.inc"

    @   CB_PRECEDENCE                   The IMMEDIATE flag's actual value.
    defconst "CB_PRECEDENCE",_CB_PRECEDENCE,CB_PRECEDENCE

    @   CB_SMUDGE                       The HIDDEN flag's actual value.
    defconst "CB_SMUDGE",_CB_SMUDGE,CB_SMUDGE

    @   CB_LENGTH                         The length mask in the flags/len byte.
    defconst "CB_LENGTH",_CB_LENGTH,CB_LENGTH