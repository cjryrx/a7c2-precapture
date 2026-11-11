device_state_getter = 0x006e4ffb;
original_capture_done_resume = 0x00b15ea5;
original_capture_job_resume = 0x00b15eb3;
original_allocate_resume = 0x00b098a1;
ENTRY(cp_capture_done_token)
SECTIONS { . = 0x00c2f990; .text : { *(.text*) } /DISCARD/ : { *(.note*) *(.comment) *(.ARM.attributes) } }
