;------------------------------------------------------------------------------
; @file
; Populates hypervisor metadata for the SVSM module and creates a launch
; vector at a known location for the SVSM module to subsequently launch OVMF.
;
; Copyright (c) 2022-2023 SUSE LLC
; SPDX-License-Identifier: MIT OR Apache-2.0
; Author: Roy Hopkins <rhopkins@suse.de>
;
;------------------------------------------------------------------------------

BITS 16

;
; When configured to launch an SVSM module, the OVMF metadata should be positioned
; exactly 4K below this module. Create a launch vector for the SVSM to start
; OVMF at 4K below the actual reset vector.
;
TIMES 16 DB 0
jmp     LaunchOvmf
ALIGN   16

;
; These structures are always immediately followed by the 32 byte VTF structures
; and code. Ensure this entire structure takes the remainder of the 4K from the
; end of VTF
;
TIMES (0x1000 - 0x20 - (SvsmMetadataEnd - SvsmMetadataStart)) DB 0

SvsmMetadataStart:

ALIGN 16

SvsmSevMetadataGuid:

SvsmDescriptorSev:
  DB 'A','S','E','V'                                            ; Signature
  DD SvsmSevGuidedStructureEnd - SvsmDescriptorSev              ; Length
  DD SVSM_SEV_METADATA_VERSION                                  ; Version
  DD (SvsmSevGuidedStructureEnd - SvsmDescriptorSev - 16) / 12  ; Number of sections

; Region need to be pre-validated by the hypervisor
SvsmPreValidate1:
  DD  SVSM_SEC_MEM_BASE
  DD  SVSM_SEC_MEM_SIZE
  DD  SVSM_SECTION_TYPE_SNP_SEC_MEM

; SEV-SNP Secrets page
SvsmSevSnpSecrets:
  DD  SVSM_SECRETS_BASE
  DD  SVSM_SECRETS_SIZE
  DD  SVSM_SECTION_TYPE_SNP_SECRETS

; CPUID values
SvsmCpuidSec:
  DD  SVSM_CPUID_BASE
  DD  SVSM_CPUID_SIZE
  DD  SVSM_SECTION_TYPE_CPUID

SvsmSevGuidedStructureEnd:

ALIGN     16
;
; Padding to ensure first guid starts at 0xffffffd0
;
TIMES (15 - ((svsmGuidedStructureEnd - svsmGuidedStructureStart + 15) % 16)) DB 0

; GUIDed structure.  To traverse this you should first verify the
; presence of the table footer guid
; (96b582de-1fb2-45f7-baea-a366c55a082d) at 0xffffffd0.  If that
; is found, the two bytes at 0xffffffce are the entire table length.
;
; The table is composed of structures with the form:
;
; Data (arbitrary bytes identified by guid)
; length from start of data to end of guid (2 bytes)
; guid (16 bytes)
;
; so work back from the footer using the length to traverse until you
; either find the guid you're looking for or run off the beginning of
; the table.
;
svsmGuidedStructureStart:

;
; SEV metadata descriptor
;
; Provide the start offset of the metadata blob within the OVMF binary.

; GUID : dc886566-984a-4798-A75e-5585a7bf67cc
;
SvsmSevMetadataOffsetStart:
  DD      (fourGigabytes - SvsmSevMetadataGuid)
  DW      SvsmSevMetadataOffsetEnd - SvsmSevMetadataOffsetStart
  DB      0x66, 0x65, 0x88, 0xdc, 0x4a, 0x98, 0x98, 0x47
  DB      0xA7, 0x5e, 0x55, 0x85, 0xa7, 0xbf, 0x67, 0xcc
SvsmSevMetadataOffsetEnd:

; SEV Secret block
;
; This describes the guest ram area where the hypervisor should
; inject the secret.  The data format is:
;
; base physical address (32 bit word)
; table length (32 bit word)
;
; GUID (SEV secret block): 4c2eb361-7d9b-4cc3-8081-127c90d3d294
;
svsmSevSecretBlockStart:
    DD      SVSM_SECRETS_BASE
    DD      SVSM_SECRETS_SIZE
    DW      svsmSevSecretBlockEnd - svsmSevSecretBlockStart
    DB      0x61, 0xB3, 0x2E, 0x4C, 0x9B, 0x7D, 0xC3, 0x4C
    DB      0x80, 0x81, 0x12, 0x7C, 0x90, 0xD3, 0xD2, 0x94
svsmSevSecretBlockEnd:

;
; SEV-ES Processor Reset support
;
; sevEsResetBlock:
;   For the initial boot of an AP under SEV-ES, the "reset" RIP must be
;   programmed to the RAM area defined by SEV_ES_AP_RESET_IP. The data
;   format is:
;
;   IP value [0:15]
;   CS segment base [31:16]
;
;   GUID (SEV-ES reset block): 00f771de-1a7e-4fcb-890e-68c77e2fb44e
;
;   A hypervisor reads the CS segement base and IP value. The CS segment base
;   value represents the high order 16-bits of the CS segment base, so the
;   hypervisor must left shift the value of the CS segement base by 16 bits to
;   form the full CS segment base for the CS segment register. It would then
;   program the EIP register with the IP value as read.
;

svsmSevEsResetBlockStart:
    DD      SEV_ES_AP_RESET_IP
    DW      svsmSevEsResetBlockEnd - svsmSevEsResetBlockStart
    DB      0xDE, 0x71, 0xF7, 0x00, 0x7E, 0x1A, 0xCB, 0x4F
    DB      0x89, 0x0E, 0x68, 0xC7, 0x7E, 0x2F, 0xB4, 0x4E
svsmSevEsResetBlockEnd:

;
; SEV-SNP SVSM Info
;
; SVM Info:
;   Information about the location of any SVSM region within the firmware.
;   The SVSM region is optional but if present, provides the entry point for
;   the AP in 32-bit protected mode. The hypervisor will detect the presence
;   of the SVSM region and will configure the entry point of the guest
;   accordingly. The structure format is:
;
;   Launch offset of entry point of SVSM from start of firmware (32-bit word)
;
;   GUID (SVSM Info): a789a612-0597-4c4b-a49f-cbb1fe9d1ddd
;
;   A hypervisor reads the CS segement base and IP value. The CS segment base
;   value represents the high order 16-bits of the CS segment base, so the
;   hypervisor must left shift the value of the CS segement base by 16 bits to
;   form the full CS segment base for the CS segment register. It would then
;   program the EIP register with the IP value as read.
;

svsmSevSnpSvsmInfoStart:
    DD      SVSM_OFFSET
    DW      svsmSevSnpSvsmInfoEnd - svsmSevSnpSvsmInfoStart
    DB      0x12, 0xA6, 0x89, 0xA7, 0x97, 0x05, 0x4B, 0x4C
    DB      0xA4, 0x9F, 0xCB, 0xB1, 0xFE, 0x9D, 0x1D, 0xDD
svsmSevSnpSvsmInfoEnd:

;
; Table footer:
;
; length of whole table (16 bit word)
; GUID (table footer): 96b582de-1fb2-45f7-baea-a366c55a082d
;
    DW      svsmGuidedStructureEnd - svsmGuidedStructureStart
    DB      0xDE, 0x82, 0xB5, 0x96, 0xB2, 0x1F, 0xF7, 0x45
    DB      0xBA, 0xEA, 0xA3, 0x66, 0xC5, 0x5A, 0x08, 0x2D

svsmGuidedStructureEnd:

SvsmMetadataEnd: