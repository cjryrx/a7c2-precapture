ENTRY(bridge_setting)
native_send = 0x35358b8;
native_model_lock = 0x2e06cc0;
native_model_unlock = 0x2e068cc;
native_time_getter = 0x2867cfc;
native_trigger_getter = 0x2867d24;
native_trigger_menu_setter = 0x2566eb8;
SECTIONS { . = 0x51a6d00; .text : { *(.text*) } /DISCARD/ : { *(.note*) *(.comment) } }

native_mode_getter = 0x27677bc;
native_option_getter = 0x2767864;
native_exit_resume = 0x338db7c;
native_system_error = 0x35aa4b4;
native_abort = 0x165ff50;
