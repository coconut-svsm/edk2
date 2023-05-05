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

