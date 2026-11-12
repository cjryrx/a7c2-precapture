.syntax unified
.thumb
.cpu cortex-a9
.section .text
.global raw_pressure_owner
.type raw_pressure_owner,%function
raw_pressure_owner:
 push {r4-r8,lr}
 mov r4,r0
 bl native_prune
 ldr r0,[r4,#0xc]
 cmp r0,#2
 blo done
 ldr r0,[r4,#8]
 ldr r0,[r0,#8]
 cmp r0,#0
 beq done
 ldr r0,[r0]
 movw r1,#0x5ec4
 ldr r0,[r0,r1]
 movw r1,#0x504
 movt r1,#5
 movs r5,#1
 cmp r0,r1
 beq weight_known
 adds r1,#1
 movs r5,#2
 cmp r0,r1
 beq weight_known
 adds r1,#0x69
 movs r5,#4
 cmp r0,r1
 bne done
weight_known:
 lsls r5,r5,#1
 movw r0,#0xf380
 movt r0,#0x1a3
 ldr r1,[r0,#0x1c]
 ldr r2,[r0,#0x20]
 subs r1,r1,r2
 ldr r2,[r0,#0x24]
 cmp r2,#0
 beq done
 cmp r1,r2
 bhi pressure
 subs r2,r2,r1
 cmp r2,r5
 bhs done
pressure:
 mov r0,r4
 movs r1,#1
 bl native_discard
 done:
 pop {r4-r8,pc}
.size raw_pressure_owner,.-raw_pressure_owner
