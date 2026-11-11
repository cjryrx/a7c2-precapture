ENTRY(bridge_setting)
native_send = 0x35358b8;
native_model_lock = 0x2e06cc0;
native_model_unlock = 0x2e068cc;
native_time_getter = 0x2867cfc;
native_trigger_getter = 0x2867d24;
SECTIONS { . = 0x51a6d00; .text : { *(.text*) } /DISCARD/ : { *(.note*) *(.comment) } }
