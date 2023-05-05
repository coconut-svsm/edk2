;------------------------------------------------------------------------------
; @file
; 16-bit launch code called directly from either the reset vector or from
; an SVSM module.
;
; Copyright (c) 2022-2023 SUSE LLC
; SPDX-License-Identifier: MIT OR Apache-2.0
; Author: Roy Hopkins <rhopkins@suse.de>
;
;------------------------------------------------------------------------------

BITS    16

ALIGN 16

;
; Pad the image size to 4k when page tables are in VTF0
;
; If the VTF0 image has page tables built in, then we need to make
; sure the end of VTF0 is 4k above where the page tables end.
;
; This is required so the page tables will be 4k aligned when VTF0 is
; located just below 0x100000000 (4GB) in the firmware device.
;
%ifdef ALIGN_TOP_TO_4K_FOR_PAGING
    TIMES (0x1000 - ($ - EndOfPageTables) - 0x20) DB 0
%endif

;
; Launch either the SVSM module or OVMF in real mode, based on
; the current target.
;
LaunchReal16:
%ifdef SVSM_RESET_VECTOR
    jmp     LaunchSvsm
%endif

LaunchOvmf:
    jmp     short EarlyBspInitReal16

%ifdef SVSM_RESET_VECTOR
LaunchSvsm:
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax

    ; Enable protected mode and disable write-through and memory caches
    mov     eax, cr0
    and     eax, ~((1 << 30) | (1 << 29))
    or      al, 1
    mov     cr0, eax

o32 lgdt    [word cs:ADDR16_OF(gdt32_descr)]
    jmp     8:dword ADDR_OF(protected_mode)

BITS    32
protected_mode:
    mov     ax, 16
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     ss, ax
    jmp     8:SVSM_BASE_ADDR

gdt32:
    dq      0
    dq      0x00cf9b000000ffff
    dq      0x00cf93000000ffff
gdt32_end:

gdt32_descr:
    dw      gdt32_end - gdt32 - 1
    dd      ADDR_OF(gdt32)
%endif
