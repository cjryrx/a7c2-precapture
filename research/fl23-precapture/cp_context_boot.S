.syntax unified
.arm
.cpu cortex-a9
.text
.global cp_context_boot
.type cp_context_boot,%function
cp_context_boot:
 push {r4,lr}
 bl native_clear
 /* No calls after this unaligned 4-byte push. Preserve clear's r0-r3/ip,
    flags and caller r4, as well as SP. Publish ready last. */
 push {r0}
 movw r4,#0x6000
 movt r4,#0x1b8
 movw r0,#0x4231
 movt r0,#0x4350
 str r0,[r4]
 mov r0,#16
 str r0,[r4,#0x1c]
 str r0,[r4,#0x34]
 mov r0,#100
 str r0,[r4,#0x20]
 str r0,[r4,#0x38]
 mov r0,#1
 str r0,[r4,#4]
 pop {r0}
 pop {r4,pc}
.size cp_context_boot,.-cp_context_boot
