ENTRY(raw_pressure_owner)
SECTIONS { . = 0xC2FC00; .text : { *(.text*) } /DISCARD/ : { *(.ARM.exidx*) *(.ARM.attributes*) *(.comment*) } }
native_prune = 0x47A2FD;
native_discard = 0x47A419;
