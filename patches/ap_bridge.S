/* Offline candidate only. Joint CP reply bridge required before use. */
.text
.balign 16
.global bridge_setting
.type bridge_setting,%function
bridge_setting:
 stp x29,x30,[sp,#-64]!
 mov x29,sp
 stp x19,x20,[sp,#16]
 mov x20,x1
 ldr w3,[x0,#4]
 cmp w3,#20
 b.hs setting_invalid
 ldr w4,[x0,#8]
 cmp w4,#3
 b.hs setting_invalid
 stp xzr,xzr,[sp,#32]
 mov w2,#5
 strb w2,[sp,#32]
 mov w2,#0x4172
 strh w2,[sp,#34]
 ldr w2,[x0]
 str w2,[sp,#36]
 add w4,w4,#1
 str w4,[sp,#40]
 adr x2,time_table
 ldr w3,[x2,w3,uxtw #2]
 str w3,[sp,#44]
 mov w0,#1
 movk w0,#0x9003,lsl #16
 add x1,sp,#32
 mov x2,#16
 mov w3,#0
 mov x4,#0
 mov x5,#0
 bl native_send
 str wzr,[x20]
 b setting_return
setting_invalid:
 mov w0,#1
 str w0,[x20]
setting_return:
 ldp x19,x20,[sp,#16]
 ldp x29,x30,[sp],#64
 ret
.size bridge_setting,.-bridge_setting
.balign 16
.global bridge_shooting
.type bridge_shooting,%function
bridge_shooting:
 stp x29,x30,[sp,#-96]!
 mov x29,sp
 stp x19,x20,[sp,#16]
 mov x20,x1
 ldr w2,[x0,#4]
 cmp w2,#2
 b.hs shooting_invalid
 ldr w3,[x0,#8]
 cmp w3,#2
 b.hs shooting_invalid
 orr w2,w2,w3
 cmp w2,#0
 cset w2,eq
 stp xzr,xzr,[sp,#32]
 str xzr,[sp,#48]
 str wzr,[sp,#56]
 str w2,[sp,#40]
 mov w2,#5
 strb w2,[sp,#32]
 mov w2,#0x4173
 strh w2,[sp,#34]
 ldr w2,[x0]
 str w2,[sp,#36]
 str w2,[sp,#64]
 /* Normalize the native trigger model before taking the snapshot lock.
    Native2566EB8 owns its model lock through178F950/178F974.
    Inputs already captured in stack packet; x20 is callee-saved. */
 bl native_trigger_getter
 ldr w0,[x0]
 cmp w0,#3
 b.hs shooting_invalid
 cmp w0,#1
 b.eq shooting_model_snapshot
 mov w1,#1
 bl native_trigger_menu_setter
shooting_model_snapshot:
 /* Same model lock and actual getters as native3120FA8.
    Release model lock BEFORE either transport send/wait. */
 add x0,sp,#80
 bl native_model_lock
 bl native_mode_getter
 cmp w0,#2
 b.ne shooting_force_off
 bl native_option_getter
 cbz w0,shooting_mode_ready
shooting_force_off:
 str wzr,[sp,#40]
shooting_mode_ready:
 bl native_time_getter
 ldr w0,[x0]
 str w0,[sp,#68]
 bl native_trigger_getter
 ldr w0,[x0]
 cmp w0,#1
 b.ne shooting_trigger_raced
 str w0,[sp,#72]
 add x0,sp,#80
 bl native_model_unlock
 add x0,sp,#64
 add x1,sp,#76
 bl bridge_setting
 ldr w0,[sp,#76]
 cbnz w0,shooting_invalid
 mov w0,#1
 movk w0,#0x9003,lsl #16
 add x1,sp,#32
 mov x2,#12
 mov w3,#0x4173
 add x4,sp,#48
 mov x5,#12
 bl native_send
 ldr w0,[sp,#56]
 cmp w0,#0xf,lsl #12
 cset w0,ne
 str w0,[x20]
 b shooting_return
shooting_trigger_raced:
 add x0,sp,#80
 bl native_model_unlock
 b shooting_invalid
shooting_invalid:
 mov w0,#1
 str w0,[x20]
shooting_return:
 ldp x19,x20,[sp,#16]
 ldp x29,x30,[sp],#96
 ret
.size bridge_shooting,.-bridge_shooting
.balign 4
.type time_table,%object
time_table:
 .word 5,10,20,30,40,50,60,70,80,90,100,200,300,400,800,600,700,800,900,1000
.size time_table,.-time_table
.hidden native_trigger_menu_setter,native_send,native_model_lock,native_model_unlock,native_time_getter,native_trigger_getter
.section .note.GNU-stack,"",%progbits

.text
.balign 4
.global bridge_exit_still
.type bridge_exit_still,%function
bridge_exit_still:
 stp x29,x30,[sp,#-64]!
 mov x29,sp
 str x19,[sp,#16]
 mov x19,x0
 ldr w2,[x0,#0x14]
 str w2,[sp,#32]
 mov w2,#1
 str w2,[sp,#36]
 str wzr,[sp,#40]
 add x0,sp,#32
 add x1,sp,#44
 bl bridge_shooting
 ldr w0,[sp,#44]
 cbnz w0,bridge_exit_failed
 mov x0,x19
 ldr x19,[sp,#16]
 ldp x29,x30,[sp],#64
 sub sp,sp,#0x850
 b native_exit_resume
bridge_exit_failed:
 bl native_system_error
 bl native_abort
 brk #0
.size bridge_exit_still,.-bridge_exit_still
.hidden native_mode_getter,native_option_getter,native_exit_resume,native_system_error,native_abort
