native_prepare = 0x00B1AEA7;
native_record_notify = 0x00497491;
native_lowres_alias = 0x00B177CB;
native_timeshift_queue = 0x00B15D99;
native_record_class = 0x00B15EFD;
ENTRY(cp_prequeue_prepare)
SECTIONS { . = 0x00c2f940; .text : { *(.text*) } /DISCARD/ : { *(.note*) *(.comment) *(.ARM.attributes) } }
