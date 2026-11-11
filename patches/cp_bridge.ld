original_frame_dispatch = 0x00479fc9;
original_busy_reject = 0x004b57b1;
ENTRY(cp_shooting)
original_entry_resume = 0x004b51d9;
original_event_exit = 0x004b54ab;
original_time_idle = 0x00b11d4d;
original_time_nonidle = 0x00b11d37;
SECTIONS { . = 0x00c2f480; .text : { *(.text*) } /DISCARD/ : { *(.note*) *(.comment) *(.ARM.attributes) } }