native_emit = 0x00ae3ccb;
native_bypass_stop = 0x00458ed7;
native_normal_stop = 0x00458e85;
native_stop_finish = 0x00458ee7;
ENTRY(pair_mark)
SECTIONS { . = 0x00c2fda0; .text : { *(.text*) } /DISCARD/ : { *(.note*) *(.comment) *(.ARM.attributes) } }
