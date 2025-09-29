//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
// This file has been adjusted for ProfileRecorder, originally of the Swift.org open source project
// swift-format-ignore-file

//===--- dwarf.h - Definitions of DWARF structures for import into Swift --===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Definitions of DWARF structures for import into Swift code
//
// The types here are taken from the DWARF 5 specification, from
// <https://dwarfstd.org>
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_DWARF_H
#define SWIFT_DWARF_H

#include <inttypes.h>

#ifdef __cplusplus
namespace SWIPRswift {
namespace SWIPRruntime {
#endif

#pragma pack(push, 1)

/* .. Useful macros ......................................................... */

#define internal_SWIPR_DWARF_EXTENSIBLE_ENUM __attribute__((enum_extensibility(open)))
#define internal_SWIPR_DWARF_ENUM(t,n) \
  enum internal_SWIPR_DWARF_EXTENSIBLE_ENUM n: t
#define internal_SWIPR_DWARF_BYTECODE \
  internal_SWIPR_DWARF_EXTENSIBLE_ENUM : SWIPR_Dwarf_Byte

/* .. Data Representation ................................................... */

// Common sizes (these don't change between 32-bit and 64-bit)
typedef uint8_t  SWIPR_Dwarf_Byte;
typedef uint16_t SWIPR_Dwarf_Half;
typedef uint32_t SWIPR_Dwarf_Word;
typedef uint64_t SWIPR_Dwarf_Xword;
typedef int8_t   SWIPR_Dwarf_Sbyte;
typedef int32_t  SWIPR_Dwarf_Sword;
typedef int64_t  SWIPR_Dwarf_Sxword;

// 32-bit sizes
typedef uint32_t SWIPR_Dwarf32_Offset;
typedef uint32_t SWIPR_Dwarf32_Size;
typedef uint32_t SWIPR_Dwarf32_Length; // 0xfffffff0 and above are reserved

// 64-bit sizes
typedef uint64_t SWIPR_Dwarf64_Offset;
typedef uint64_t SWIPR_Dwarf64_Size;
typedef struct {
  uint32_t magic;  // 0xffffffff means we're using 64-bit
  uint64_t length;
} SWIPR_Dwarf64_Length;

/* .. Unit Types ............................................................ */

// Table 7.2
typedef internal_SWIPR_DWARF_ENUM(SWIPR_Dwarf_Byte, SWIPR_Dwarf_UnitType) {
  internal_SWIPR_DW_UT_unknown       = 0x00,
  internal_SWIPR_DW_UT_compile       = 0x01,
  internal_SWIPR_DW_UT_type          = 0x02,
  internal_SWIPR_DW_UT_partial       = 0x03,
  internal_SWIPR_DW_UT_skeleton      = 0x04,
  internal_SWIPR_DW_UT_split_compile = 0x05,
  internal_SWIPR_DW_UT_split_type    = 0x06,
  internal_SWIPR_DW_UT_lo_user       = 0x80,
  internal_SWIPR_DW_UT_hi_user       = 0xff
} SWIPR_Dwarf_UnitType;

/* .. Tags .................................................................. */

// Table 7.3
typedef internal_SWIPR_DWARF_ENUM(SWIPR_Dwarf_Xword, SWIPR_Dwarf_Tag) {
  internal_SWIPR_DW_TAG_array_type               = 0x01,
  internal_SWIPR_DW_TAG_class_type               = 0x02,
  internal_SWIPR_DW_TAG_entry_point              = 0x03,
  internal_SWIPR_DW_TAG_enumeration_type         = 0x04,
  internal_SWIPR_DW_TAG_formal_parmeter          = 0x05,
  // Reserved                     = 0x06,
  // Reserved                     = 0x07,
  internal_SWIPR_DW_TAG_imported_declaration     = 0x08,
  // Reserved                     = 0x09,
  internal_SWIPR_DW_TAG_label                    = 0x0a,
  internal_SWIPR_DW_TAG_lexical_block            = 0x0b,
  // Reserved                     = 0x0c,
  internal_SWIPR_DW_TAG_member                   = 0x0d,
  // Reserved                     = 0x0e,
  internal_SWIPR_DW_TAG_pointer_type             = 0x0f,
  internal_SWIPR_DW_TAG_reference_type           = 0x10,
  internal_SWIPR_DW_TAG_compile_unit             = 0x11,
  internal_SWIPR_DW_TAG_string_type              = 0x12,
  internal_SWIPR_DW_TAG_structure_type           = 0x13,
  // Reserved                     = 0x14,
  internal_SWIPR_DW_TAG_subroutine_type          = 0x15,
  internal_SWIPR_DW_TAG_typedef                  = 0x16,
  internal_SWIPR_DW_TAG_union_type               = 0x17,
  internal_SWIPR_DW_TAG_unspecified_parameters   = 0x18,
  internal_SWIPR_DW_TAG_variant                  = 0x19,
  internal_SWIPR_DW_TAG_common_block             = 0x1a,
  internal_SWIPR_DW_TAG_common_inclusion         = 0x1b,
  internal_SWIPR_DW_TAG_inheritance              = 0x1c,
  internal_SWIPR_DW_TAG_inlined_subroutine       = 0x1d,
  internal_SWIPR_DW_TAG_module                   = 0x1e,
  internal_SWIPR_DW_TAG_ptr_to_member_type       = 0x1f,
  internal_SWIPR_DW_TAG_set_type                 = 0x20,
  internal_SWIPR_DW_TAG_subrange_type            = 0x21,
  internal_SWIPR_DW_TAG_with_stmt                = 0x22,
  internal_SWIPR_DW_TAG_access_declaration       = 0x23,
  internal_SWIPR_DW_TAG_base_type                = 0x24,
  internal_SWIPR_DW_TAG_catch_block              = 0x25,
  internal_SWIPR_DW_TAG_const_type               = 0x26,
  internal_SWIPR_DW_TAG_constant                 = 0x27,
  internal_SWIPR_DW_TAG_enumerator               = 0x28,
  internal_SWIPR_DW_TAG_file_type                = 0x29,
  internal_SWIPR_DW_TAG_friend                   = 0x2a,
  internal_SWIPR_DW_TAG_namelist                 = 0x2b,
  internal_SWIPR_DW_TAG_namelist_item            = 0x2c,
  internal_SWIPR_DW_TAG_packed_type              = 0x2d,
  internal_SWIPR_DW_TAG_subprogram               = 0x2e,
  internal_SWIPR_DW_TAG_template_type_parameter  = 0x2f,
  internal_SWIPR_DW_TAG_template_value_parameter = 0x30,
  internal_SWIPR_DW_TAG_thrown_type              = 0x31,
  internal_SWIPR_DW_TAG_try_block                = 0x32,
  internal_SWIPR_DW_TAG_variant_part             = 0x33,
  internal_SWIPR_DW_TAG_variable                 = 0x34,
  internal_SWIPR_DW_TAG_volatile_type            = 0x35,
  internal_SWIPR_DW_TAG_dwarf_procedure          = 0x36,
  internal_SWIPR_DW_TAG_restrict_type            = 0x37,
  internal_SWIPR_DW_TAG_interface_type           = 0x38,
  internal_SWIPR_DW_TAG_namespace                = 0x39,
  internal_SWIPR_DW_TAG_imported_module          = 0x3a,
  internal_SWIPR_DW_TAG_unspecified_type         = 0x3b,
  internal_SWIPR_DW_TAG_partial_unit             = 0x3c,
  internal_SWIPR_DW_TAG_imported_unit            = 0x3d,
  // Reserved                     = 0x3e,
  internal_SWIPR_DW_TAG_condition                = 0x3f,
  internal_SWIPR_DW_TAG_shared_type              = 0x40,
  internal_SWIPR_DW_TAG_type_unit                = 0x41,
  internal_SWIPR_DW_TAG_rvalue_reference_type    = 0x42,
  internal_SWIPR_DW_TAG_template_alias           = 0x43,
  internal_SWIPR_DW_TAG_coarray_type             = 0x44,
  internal_SWIPR_DW_TAG_generic_subrange         = 0x45,
  internal_SWIPR_DW_TAG_dynamic_type             = 0x46,
  internal_SWIPR_DW_TAG_atomic_type              = 0x47,
  internal_SWIPR_DW_TAG_call_site                = 0x48,
  internal_SWIPR_DW_TAG_call_site_parameter      = 0x49,
  internal_SWIPR_DW_TAG_skeleton_unit            = 0x4a,
  internal_SWIPR_DW_TAG_immutable_type           = 0x4b,
  internal_SWIPR_DW_TAG_lo_user                  = 0x4080,
  internal_SWIPR_DW_TAG_hi_user                  = 0xffff,
} SWIPR_Dwarf_Tag;

/* .. Child Determination Encodings ......................................... */

typedef internal_SWIPR_DWARF_ENUM(SWIPR_Dwarf_Byte, SWIPR_Dwarf_ChildDetermination) {
  internal_SWIPR_DW_CHILDREN_no = 0x00,
  internal_SWIPR_DW_CHILDREN_yes = 0x01,
} SWIPR_Dwarf_ChildDetermination;

/* .. Attribute Encodings ................................................... */

// Table 7.5
typedef enum internal_SWIPR_DWARF_EXTENSIBLE_ENUM SWIPR_Dwarf_Attribute {
  internal_SWIPR_DW_AT_sibling                 = 0x01, // reference
  internal_SWIPR_DW_AT_location                = 0x02, // exprloc, loclist
  internal_SWIPR_DW_AT_name                    = 0x03, // string
  // Reserved                   = 0x04, // not applicable
  // Reserved                   = 0x05, // not applicable
  // Reserved                   = 0x06, // not applicable
  // Reserved                   = 0x07, // not applicable
  // Reserved                   = 0x08, // not applicable
  internal_SWIPR_DW_AT_ordering                = 0x09, // constant
  // Reserved                   = 0x0a, // not applicable
  internal_SWIPR_DW_AT_byte_size               = 0x0b, // constant, exprloc, reference
  // Reserved                   = 0x0c2, // constant, exprloc, reference
  internal_SWIPR_DW_AT_bit_size                = 0x0d, // constant, exprloc, reference
  // Reserved                   = 0x0e, // not applicable
  // Reserved                   = 0x0f, // not applicable
  internal_SWIPR_DW_AT_stmt_list               = 0x10, // lineptr
  internal_SWIPR_DW_AT_low_pc                  = 0x11, // address
  internal_SWIPR_DW_AT_high_pc                 = 0x12, // address, constant
  internal_SWIPR_DW_AT_language                = 0x13, // constant
  // Reserved                   = 0x14, // not applicable
  internal_SWIPR_DW_AT_discr                   = 0x15, // reference
  internal_SWIPR_DW_AT_discr_value             = 0x16, // constant
  internal_SWIPR_DW_AT_visibility              = 0x17, // constant
  internal_SWIPR_DW_AT_import                  = 0x18, // reference
  internal_SWIPR_DW_AT_string_length           = 0x19, // exprloc, loclist, reference
  internal_SWIPR_DW_AT_common_reference        = 0x1a, // reference
  internal_SWIPR_DW_AT_comp_dir                = 0x1b, // string
  internal_SWIPR_DW_AT_const_value             = 0x1c, // block, constant, string
  internal_SWIPR_DW_AT_containing_type         = 0x1d, // reference
  internal_SWIPR_DW_AT_default_value           = 0x1e, // constant, reference, flag
  // Reserved                   = 0x1f, // not applicable
  internal_SWIPR_DW_AT_inline                  = 0x20, // constant
  internal_SWIPR_DW_AT_is_optional             = 0x21, // flag
  internal_SWIPR_DW_AT_lower_bound             = 0x22, // constant, exprloc, reference
  // Reserved                   = 0x23, // not applicable
  // Reserved                   = 0x24, // not applicable
  internal_SWIPR_DW_AT_producer                = 0x25, // string
  // Reserved                   = 0x26, // not applicable
  internal_SWIPR_DW_AT_prototyped              = 0x27, // flag
  // Reserved                   = 0x28, // not applicable
  // Reserved                   = 0x29, // not applicable
  internal_SWIPR_DW_AT_return_addr             = 0x2a, // exprloc, loclist
  // Reserved                   = 0x2b, // not applicable
  internal_SWIPR_DW_AT_start_scope             = 0x2c, // constant, rnglist
  // Reserved                   = 0x2d, // not applicable
  internal_SWIPR_DW_AT_bit_stride              = 0x2e, // constant, exprloc, reference
  internal_SWIPR_DW_AT_upper_bound             = 0x2f, // constant, exprloc, reference
  // Reserved                   = 0x30, // not applicable
  internal_SWIPR_DW_AT_abstract_origin         = 0x31, // reference
  internal_SWIPR_DW_AT_accessibility           = 0x32, // constant
  internal_SWIPR_DW_AT_address_class           = 0x33, // constant
  internal_SWIPR_DW_AT_artificial              = 0x34, // flag
  internal_SWIPR_DW_AT_base_types              = 0x35, // reference
  internal_SWIPR_DW_AT_calling_convention      = 0x36, // constant
  internal_SWIPR_DW_AT_count                   = 0x37, // constant, exprloc, reference
  internal_SWIPR_DW_AT_data_member_location    = 0x38, // constant, exprloc, loclist
  internal_SWIPR_DW_AT_decl_column             = 0x39, // constant
  internal_SWIPR_DW_AT_decl_file               = 0x3a, // constant
  internal_SWIPR_DW_AT_decl_line               = 0x3b, // constant
  internal_SWIPR_DW_AT_declaration             = 0x3c, // flag
  internal_SWIPR_DW_AT_discr_list              = 0x3d, // block
  internal_SWIPR_DW_AT_encoding                = 0x3e, // constant
  internal_SWIPR_DW_AT_external                = 0x3f, // flag
  internal_SWIPR_DW_AT_frame_base              = 0x40, // exprloc, loclist
  internal_SWIPR_DW_AT_friend                  = 0x41, // reference
  internal_SWIPR_DW_AT_identifier_case         = 0x42, // constant
  // Reserved                   = 0x43, // macptr
  internal_SWIPR_DW_AT_namelist_item           = 0x44, // reference
  internal_SWIPR_DW_AT_priority                = 0x45, // reference
  internal_SWIPR_DW_AT_segment                 = 0x46, // exprloc, loclist
  internal_SWIPR_DW_AT_specification           = 0x47, // reference
  internal_SWIPR_DW_AT_static_link             = 0x48, // exprloc, loclist
  internal_SWIPR_DW_AT_type                    = 0x49, // reference
  internal_SWIPR_DW_AT_use_location            = 0x4a, // exprloc, loclist
  internal_SWIPR_DW_AT_variable_parameter      = 0x4b, // flag
  internal_SWIPR_DW_AT_virtuality              = 0x4c, // constant
  internal_SWIPR_DW_AT_vtable_elem_location    = 0x4d, // exprloc, loclist
  internal_SWIPR_DW_AT_allocated               = 0x4e, // constant, exprloc, reference
  internal_SWIPR_DW_AT_associated              = 0x4f, // constant, exprloc, reference
  internal_SWIPR_DW_AT_data_location           = 0x50, // exprloc
  internal_SWIPR_DW_AT_byte_stride             = 0x51, // constant, exprloc, reference
  internal_SWIPR_DW_AT_entry_pc                = 0x52, // address, constant
  internal_SWIPR_DW_AT_use_UTF8                = 0x53, // flag
  internal_SWIPR_DW_AT_extension               = 0x54, // reference
  internal_SWIPR_DW_AT_ranges                  = 0x55, // rnglist
  internal_SWIPR_DW_AT_trampoline              = 0x56, // address, flag, reference, string
  internal_SWIPR_DW_AT_call_column             = 0x57, // constant
  internal_SWIPR_DW_AT_call_file               = 0x58, // constant
  internal_SWIPR_DW_AT_call_line               = 0x59, // constant
  internal_SWIPR_DW_AT_description             = 0x5a, // string
  internal_SWIPR_DW_AT_binary_scale            = 0x5b, // constant
  internal_SWIPR_DW_AT_decimal_scale           = 0x5c, // constant
  internal_SWIPR_DW_AT_small                   = 0x5d, // reference
  internal_SWIPR_DW_AT_decimal_sign            = 0x5e, // constant
  internal_SWIPR_DW_AT_digit_count             = 0x5f, // constant
  internal_SWIPR_DW_AT_picture_string          = 0x60, // string
  internal_SWIPR_DW_AT_mutable                 = 0x61, // flag
  internal_SWIPR_DW_AT_threads_scaled          = 0x62, // flag
  internal_SWIPR_DW_AT_explicit                = 0x63, // flag
  internal_SWIPR_DW_AT_object_pointer          = 0x64, // reference
  internal_SWIPR_DW_AT_endianity               = 0x65, // constant
  internal_SWIPR_DW_AT_elemental               = 0x66, // flag
  internal_SWIPR_DW_AT_pure                    = 0x67, // flag
  internal_SWIPR_DW_AT_recursive               = 0x68, // flag
  internal_SWIPR_DW_AT_signature               = 0x69, // reference
  internal_SWIPR_DW_AT_main_subprogram         = 0x6a, // flag
  internal_SWIPR_DW_AT_data_bit_offset         = 0x6b, // constant
  internal_SWIPR_DW_AT_const_expr              = 0x6c, // flag
  internal_SWIPR_DW_AT_enum_class              = 0x6d, // flag
  internal_SWIPR_DW_AT_linkage_name            = 0x6e, // string
  internal_SWIPR_DW_AT_string_length_bit_size  = 0x6f, // constant
  internal_SWIPR_DW_AT_string_length_byte_size = 0x70, // constant
  internal_SWIPR_DW_AT_rank                    = 0x71, // constant, exprloc
  internal_SWIPR_DW_AT_str_offsets_base        = 0x72, // stroffsetsptr
  internal_SWIPR_DW_AT_addr_base               = 0x73, // addrptr
  internal_SWIPR_DW_AT_rnglists_base           = 0x74, // rnglistsptr
  // Reserved                   = 0x75, // Unused
  internal_SWIPR_DW_AT_dwo_name                = 0x76, // string
  internal_SWIPR_DW_AT_reference               = 0x77, // flag
  internal_SWIPR_DW_AT_rvalue_reference        = 0x78, // flag
  internal_SWIPR_DW_AT_macros                  = 0x79, // macptr
  internal_SWIPR_DW_AT_call_all_calls          = 0x7a, // flag
  internal_SWIPR_DW_AT_call_all_source_calls   = 0x7b, // flag
  internal_SWIPR_DW_AT_call_all_tail_calls     = 0x7c, // flag
  internal_SWIPR_DW_AT_call_return_pc          = 0x7d, // address
  internal_SWIPR_DW_AT_call_value              = 0x7e, // exprloc
  internal_SWIPR_DW_AT_call_origin             = 0x7f, // exprloc
  internal_SWIPR_DW_AT_call_parameter          = 0x80, // reference
  internal_SWIPR_DW_AT_call_pc                 = 0x81, // address
  internal_SWIPR_DW_AT_call_tail_call          = 0x82, // flag
  internal_SWIPR_DW_AT_call_target             = 0x83, // exprloc
  internal_SWIPR_DW_AT_call_target_clobbered   = 0x84, // exprloc
  internal_SWIPR_DW_AT_call_data_location      = 0x85, // exprloc
  internal_SWIPR_DW_AT_call_data_value         = 0x86, // exprloc
  internal_SWIPR_DW_AT_noreturn                = 0x87, // flag
  internal_SWIPR_DW_AT_alignment               = 0x88, // constant
  internal_SWIPR_DW_AT_export_symbols          = 0x89, // flag
  internal_SWIPR_DW_AT_deleted                 = 0x8a, // flag
  internal_SWIPR_DW_AT_defaulted               = 0x8b, // constant
  internal_SWIPR_DW_AT_loclists_base           = 0x8c, // loclistsptr
  internal_SWIPR_DW_AT_lo_user                 = 0x2000, // —
  internal_SWIPR_DW_AT_hi_user                 = 0x3fff, // —
} SWIPR_Dwarf_Attribute;

/* .. Form Encodings ........................................................ */

// Table 7.6
typedef internal_SWIPR_DWARF_ENUM(SWIPR_Dwarf_Byte, SWIPR_Dwarf_Form) {
  internal_SWIPR_DW_FORM_addr           = 0x01,
  // Reserved            = 0x02,
  internal_SWIPR_DW_FORM_block2         = 0x03,
  internal_SWIPR_DW_FORM_block4         = 0x04,
  internal_SWIPR_DW_FORM_data2          = 0x05,
  internal_SWIPR_DW_FORM_data4          = 0x06,
  internal_SWIPR_DW_FORM_data8          = 0x07,
  internal_SWIPR_DW_FORM_string         = 0x08,
  internal_SWIPR_DW_FORM_block          = 0x09,
  internal_SWIPR_DW_FORM_block1         = 0x0a,
  internal_SWIPR_DW_FORM_data1          = 0x0b,
  internal_SWIPR_DW_FORM_flag           = 0x0c,
  internal_SWIPR_DW_FORM_sdata          = 0x0d,
  internal_SWIPR_DW_FORM_strp           = 0x0e,
  internal_SWIPR_DW_FORM_udata          = 0x0f,
  internal_SWIPR_DW_FORM_ref_addr       = 0x10,
  internal_SWIPR_DW_FORM_ref1           = 0x11,
  internal_SWIPR_DW_FORM_ref2           = 0x12,
  internal_SWIPR_DW_FORM_ref4           = 0x13,
  internal_SWIPR_DW_FORM_ref8           = 0x14,
  internal_SWIPR_DW_FORM_ref_udata      = 0x15,
  internal_SWIPR_DW_FORM_indirect       = 0x16,
  internal_SWIPR_DW_FORM_sec_offset     = 0x17,
  internal_SWIPR_DW_FORM_exprloc        = 0x18,
  internal_SWIPR_DW_FORM_flag_present   = 0x19,
  internal_SWIPR_DW_FORM_strx           = 0x1a,
  internal_SWIPR_DW_FORM_addrx          = 0x1b,
  internal_SWIPR_DW_FORM_ref_sup4       = 0x1c,
  internal_SWIPR_DW_FORM_strp_sup       = 0x1d,
  internal_SWIPR_DW_FORM_data16         = 0x1e,
  internal_SWIPR_DW_FORM_line_strp      = 0x1f,
  internal_SWIPR_DW_FORM_ref_sig8       = 0x20,
  internal_SWIPR_DW_FORM_implicit_const = 0x21,
  internal_SWIPR_DW_FORM_loclistx       = 0x22,
  internal_SWIPR_DW_FORM_rnglistx       = 0x23,
  internal_SWIPR_DW_FORM_ref_sup8       = 0x24,
  internal_SWIPR_DW_FORM_strx1          = 0x25,
  internal_SWIPR_DW_FORM_strx2          = 0x26,
  internal_SWIPR_DW_FORM_strx3          = 0x27,
  internal_SWIPR_DW_FORM_strx4          = 0x28,
  internal_SWIPR_DW_FORM_addrx1         = 0x29,
  internal_SWIPR_DW_FORM_addrx2         = 0x2a,
  internal_SWIPR_DW_FORM_addrx3         = 0x2b,
  internal_SWIPR_DW_FORM_addrx4         = 0x2c,
} SWIPR_Dwarf_Form;

/* .. DWARF Expressions ..................................................... */

// Table 7.9
enum internal_SWIPR_DWARF_BYTECODE {
  // Reserved               = 0x01,
  // Reserved               = 0x02,
  internal_SWIPR_DW_OP_addr                = 0x03,
  // Reserved               = 0x04,
  // Reserved               = 0x05,
  internal_SWIPR_DW_OP_deref               = 0x06,
  // Reserved               = 0x07,
  internal_SWIPR_DW_OP_const1u             = 0x08,
  internal_SWIPR_DW_OP_const1s             = 0x09,
  internal_SWIPR_DW_OP_const2u             = 0x0a,
  internal_SWIPR_DW_OP_const2s             = 0x0b,
  internal_SWIPR_DW_OP_const4u             = 0x0c,
  internal_SWIPR_DW_OP_const4s             = 0x0d,
  internal_SWIPR_DW_OP_const8u             = 0x0e,
  internal_SWIPR_DW_OP_const8s             = 0x0f,
  internal_SWIPR_DW_OP_constu              = 0x10,
  internal_SWIPR_DW_OP_consts              = 0x11,
  internal_SWIPR_DW_OP_dup                 = 0x12,
  internal_SWIPR_DW_OP_drop                = 0x13,
  internal_SWIPR_DW_OP_over                = 0x14,
  internal_SWIPR_DW_OP_pick                = 0x15,
  internal_SWIPR_DW_OP_swap                = 0x16,
  internal_SWIPR_DW_OP_rot                 = 0x17,
  internal_SWIPR_DW_OP_xderef              = 0x18,
  internal_SWIPR_DW_OP_abs                 = 0x19,
  internal_SWIPR_DW_OP_and                 = 0x1a,
  internal_SWIPR_DW_OP_div                 = 0x1b,
  internal_SWIPR_DW_OP_minus               = 0x1c,
  internal_SWIPR_DW_OP_mod                 = 0x1d,
  internal_SWIPR_DW_OP_mul                 = 0x1e,
  internal_SWIPR_DW_OP_neg                 = 0x1f,
  internal_SWIPR_DW_OP_not                 = 0x20,
  internal_SWIPR_DW_OP_or                  = 0x21,
  internal_SWIPR_DW_OP_plus                = 0x22,
  internal_SWIPR_DW_OP_plus_uconst         = 0x23,
  internal_SWIPR_DW_OP_shl                 = 0x24,
  internal_SWIPR_DW_OP_shr                 = 0x25,
  internal_SWIPR_DW_OP_shra                = 0x26,
  internal_SWIPR_DW_OP_xor                 = 0x27,
  internal_SWIPR_DW_OP_bra                 = 0x28,
  internal_SWIPR_DW_OP_eq                  = 0x29,
  internal_SWIPR_DW_OP_ge                  = 0x2a,
  internal_SWIPR_DW_OP_gt                  = 0x2b,
  internal_SWIPR_DW_OP_le                  = 0x2c,
  internal_SWIPR_DW_OP_lt                  = 0x2d,
  internal_SWIPR_DW_OP_ne                  = 0x2e,
  internal_SWIPR_DW_OP_skip                = 0x2f,

  internal_SWIPR_DW_OP_lit0                = 0x30,
  internal_SWIPR_DW_OP_lit1                = 0x31,
  internal_SWIPR_DW_OP_lit2                = 0x32,
  internal_SWIPR_DW_OP_lit3                = 0x33,
  internal_SWIPR_DW_OP_lit4                = 0x34,
  internal_SWIPR_DW_OP_lit5                = 0x35,
  internal_SWIPR_DW_OP_lit6                = 0x36,
  internal_SWIPR_DW_OP_lit7                = 0x37,
  internal_SWIPR_DW_OP_lit8                = 0x38,
  internal_SWIPR_DW_OP_lit9                = 0x39,
  internal_SWIPR_DW_OP_lit10               = 0x3a,
  internal_SWIPR_DW_OP_lit11               = 0x3b,
  internal_SWIPR_DW_OP_lit12               = 0x3c,
  internal_SWIPR_DW_OP_lit13               = 0x3d,
  internal_SWIPR_DW_OP_lit14               = 0x3e,
  internal_SWIPR_DW_OP_lit15               = 0x3f,
  internal_SWIPR_DW_OP_lit16               = 0x40,
  internal_SWIPR_DW_OP_lit17               = 0x41,
  internal_SWIPR_DW_OP_lit18               = 0x42,
  internal_SWIPR_DW_OP_lit19               = 0x43,
  internal_SWIPR_DW_OP_lit20               = 0x44,
  internal_SWIPR_DW_OP_lit21               = 0x45,
  internal_SWIPR_DW_OP_lit22               = 0x46,
  internal_SWIPR_DW_OP_lit23               = 0x47,
  internal_SWIPR_DW_OP_lit24               = 0x48,
  internal_SWIPR_DW_OP_lit25               = 0x49,
  internal_SWIPR_DW_OP_lit26               = 0x4a,
  internal_SWIPR_DW_OP_lit27               = 0x4b,
  internal_SWIPR_DW_OP_lit28               = 0x4c,
  internal_SWIPR_DW_OP_lit29               = 0x4d,
  internal_SWIPR_DW_OP_lit30               = 0x4e,
  internal_SWIPR_DW_OP_lit31               = 0x4f,

  internal_SWIPR_DW_OP_reg0                = 0x50,
  internal_SWIPR_DW_OP_reg1                = 0x51,
  internal_SWIPR_DW_OP_reg2                = 0x52,
  internal_SWIPR_DW_OP_reg3                = 0x53,
  internal_SWIPR_DW_OP_reg4                = 0x54,
  internal_SWIPR_DW_OP_reg5                = 0x55,
  internal_SWIPR_DW_OP_reg6                = 0x56,
  internal_SWIPR_DW_OP_reg7                = 0x57,
  internal_SWIPR_DW_OP_reg8                = 0x58,
  internal_SWIPR_DW_OP_reg9                = 0x59,
  internal_SWIPR_DW_OP_reg10               = 0x5a,
  internal_SWIPR_DW_OP_reg11               = 0x5b,
  internal_SWIPR_DW_OP_reg12               = 0x5c,
  internal_SWIPR_DW_OP_reg13               = 0x5d,
  internal_SWIPR_DW_OP_reg14               = 0x5e,
  internal_SWIPR_DW_OP_reg15               = 0x5f,
  internal_SWIPR_DW_OP_reg16               = 0x60,
  internal_SWIPR_DW_OP_reg17               = 0x61,
  internal_SWIPR_DW_OP_reg18               = 0x62,
  internal_SWIPR_DW_OP_reg19               = 0x63,
  internal_SWIPR_DW_OP_reg20               = 0x64,
  internal_SWIPR_DW_OP_reg21               = 0x65,
  internal_SWIPR_DW_OP_reg22               = 0x66,
  internal_SWIPR_DW_OP_reg23               = 0x67,
  internal_SWIPR_DW_OP_reg24               = 0x68,
  internal_SWIPR_DW_OP_reg25               = 0x69,
  internal_SWIPR_DW_OP_reg26               = 0x6a,
  internal_SWIPR_DW_OP_reg27               = 0x6b,
  internal_SWIPR_DW_OP_reg28               = 0x6c,
  internal_SWIPR_DW_OP_reg29               = 0x6d,
  internal_SWIPR_DW_OP_reg30               = 0x6e,
  internal_SWIPR_DW_OP_reg31               = 0x6f,

  internal_SWIPR_DW_OP_breg0               = 0x70,
  internal_SWIPR_DW_OP_breg1               = 0x71,
  internal_SWIPR_DW_OP_breg2               = 0x72,
  internal_SWIPR_DW_OP_breg3               = 0x73,
  internal_SWIPR_DW_OP_breg4               = 0x74,
  internal_SWIPR_DW_OP_breg5               = 0x75,
  internal_SWIPR_DW_OP_breg6               = 0x76,
  internal_SWIPR_DW_OP_breg7               = 0x77,
  internal_SWIPR_DW_OP_breg8               = 0x78,
  internal_SWIPR_DW_OP_breg9               = 0x79,
  internal_SWIPR_DW_OP_breg10              = 0x7a,
  internal_SWIPR_DW_OP_breg11              = 0x7b,
  internal_SWIPR_DW_OP_breg12              = 0x7c,
  internal_SWIPR_DW_OP_breg13              = 0x7d,
  internal_SWIPR_DW_OP_breg14              = 0x7e,
  internal_SWIPR_DW_OP_breg15              = 0x7f,
  internal_SWIPR_DW_OP_breg16              = 0x80,
  internal_SWIPR_DW_OP_breg17              = 0x81,
  internal_SWIPR_DW_OP_breg18              = 0x82,
  internal_SWIPR_DW_OP_breg19              = 0x83,
  internal_SWIPR_DW_OP_breg20              = 0x84,
  internal_SWIPR_DW_OP_breg21              = 0x85,
  internal_SWIPR_DW_OP_breg22              = 0x86,
  internal_SWIPR_DW_OP_breg23              = 0x87,
  internal_SWIPR_DW_OP_breg24              = 0x88,
  internal_SWIPR_DW_OP_breg25              = 0x89,
  internal_SWIPR_DW_OP_breg26              = 0x8a,
  internal_SWIPR_DW_OP_breg27              = 0x8b,
  internal_SWIPR_DW_OP_breg28              = 0x8c,
  internal_SWIPR_DW_OP_breg29              = 0x8d,
  internal_SWIPR_DW_OP_breg30              = 0x8e,
  internal_SWIPR_DW_OP_breg31              = 0x8f,

  internal_SWIPR_DW_OP_regx                = 0x90,
  internal_SWIPR_DW_OP_fbreg               = 0x91,
  internal_SWIPR_DW_OP_bregx               = 0x92,

  internal_SWIPR_DW_OP_piece               = 0x93,
  internal_SWIPR_DW_OP_deref_size          = 0x94,
  internal_SWIPR_DW_OP_xderef_size         = 0x95,
  internal_SWIPR_DW_OP_nop                 = 0x96,
  internal_SWIPR_DW_OP_push_object_address = 0x97,
  internal_SWIPR_DW_OP_call2               = 0x98,
  internal_SWIPR_DW_OP_call4               = 0x99,
  internal_SWIPR_DW_OP_call_ref            = 0x9a,
  internal_SWIPR_DW_OP_form_tls_address    = 0x9b,
  internal_SWIPR_DW_OP_call_frame_cfa      = 0x9c,
  internal_SWIPR_DW_OP_bit_piece           = 0x9d,
  internal_SWIPR_DW_OP_implicit_value      = 0x9e,
  internal_SWIPR_DW_OP_stack_value         = 0x9f,
  internal_SWIPR_DW_OP_implicit_pointer    = 0xa0,
  internal_SWIPR_DW_OP_addrx               = 0xa1,
  internal_SWIPR_DW_OP_constx              = 0xa2,
  internal_SWIPR_DW_OP_entry_value         = 0xa3,
  internal_SWIPR_DW_OP_const_type          = 0xa4,
  internal_SWIPR_DW_OP_regval_type         = 0xa5,
  internal_SWIPR_DW_OP_deref_type          = 0xa6,
  internal_SWIPR_DW_OP_xderef_type         = 0xa7,
  internal_SWIPR_DW_OP_convert             = 0xa8,
  internal_SWIPR_DW_OP_reinterpret         = 0xa9,
  internal_SWIPR_DW_OP_lo_user             = 0xe0,
  internal_SWIPR_DW_OP_hi_user             = 0xff,
};

/* .. Line Number Information ............................................... */

// Table 7.25
typedef internal_SWIPR_DWARF_ENUM(SWIPR_Dwarf_Byte, SWIPR_Dwarf_LNS_Opcode) {
  internal_SWIPR_DW_LNS_extended           = 0x00,
  internal_SWIPR_DW_LNS_copy               = 0x01,
  internal_SWIPR_DW_LNS_advance_pc         = 0x02,
  internal_SWIPR_DW_LNS_advance_line       = 0x03,
  internal_SWIPR_DW_LNS_set_file           = 0x04,
  internal_SWIPR_DW_LNS_set_column         = 0x05,
  internal_SWIPR_DW_LNS_negate_stmt        = 0x06,
  internal_SWIPR_DW_LNS_set_basic_block    = 0x07,
  internal_SWIPR_DW_LNS_const_add_pc       = 0x08,
  internal_SWIPR_DW_LNS_fixed_advance_pc   = 0x09,
  internal_SWIPR_DW_LNS_set_prologue_end   = 0x0a,
  internal_SWIPR_DW_LNS_set_epilogue_begin = 0x0b,
  internal_SWIPR_DW_LNS_set_isa            = 0x0c,
} SWIPR_Dwarf_LNS_Opcode;

// Table 7.26
typedef internal_SWIPR_DWARF_ENUM(SWIPR_Dwarf_Byte, SWIPR_Dwarf_LNE_Opcode) {
  internal_SWIPR_DW_LNE_end_sequence      = 0x01,
  internal_SWIPR_DW_LNE_set_address       = 0x02,
  internal_SWIPR_DW_LNE_define_file       = 0x03,
  internal_SWIPR_DW_LNE_set_discriminator = 0x04,
  internal_SWIPR_DW_LNE_lo_user           = 0x80,
  internal_SWIPR_DW_LNE_hi_user           = 0xff,
} SWIPR_Dwarf_LNE_Opcode;

// Table 7.27
typedef internal_SWIPR_DWARF_ENUM(SWIPR_Dwarf_Half, SWIPR_Dwarf_Lhdr_Format) {
  internal_SWIPR_DW_LNCT_path            = 0x0001,
  internal_SWIPR_DW_LNCT_directory_index = 0x0002,
  internal_SWIPR_DW_LNCT_timestamp       = 0x0003,
  internal_SWIPR_DW_LNCT_size            = 0x0004,
  internal_SWIPR_DW_LNCT_MD5             = 0x0005,
  internal_SWIPR_DW_LNCT_lo_user         = 0x2000,
  internal_SWIPR_DW_LNCT_hi_user         = 0x3fff,
} SWIPR_Dwarf_Lhdr_Format;

// 6.2.4 The Line Number Program Header
typedef struct {
  SWIPR_Dwarf32_Length length;
  SWIPR_Dwarf_Half version;
  SWIPR_Dwarf_Byte address_size;
  SWIPR_Dwarf_Byte segment_selector_size;
  SWIPR_Dwarf32_Size header_length;
  SWIPR_Dwarf_Byte minimum_instruction_length;
  SWIPR_Dwarf_Byte maximum_operations_per_instruction;
  SWIPR_Dwarf_Byte default_is_stmt;
  SWIPR_Dwarf_Sbyte line_base;
  SWIPR_Dwarf_Byte line_range;
  SWIPR_Dwarf_Byte opcode_base;

  // Variable length fields:
  // SWIPR_Dwarf_Byte standard_opcode_lengths[];
  // SWIPR_Dwarf_Byte directory_entry_format_count;
  // SWIPR_Dwarf_ULEB128 directory_entry_format[];
  // SWIPR_Dwarf_ULEB128 directories_count;
  // encoded directories[];
  // SWIPR_Dwarf_Byte file_name_entry_format_count;
  // SWIPR_Dwarf_ULEB128 file_name_entry_format;
  // SWIPR_Dwarf_ULEB128 file_names_count;
  // encoded file_names[];
} DWARF32_Lhdr;

typedef struct {
  SWIPR_Dwarf64_Length length;
  SWIPR_Dwarf_Half version;
  SWIPR_Dwarf_Byte address_size;
  SWIPR_Dwarf_Byte segment_selector_size;
  SWIPR_Dwarf64_Size header_length;
  SWIPR_Dwarf_Byte minimum_instruction_length;
  SWIPR_Dwarf_Byte maximum_operations_per_instruction;
  SWIPR_Dwarf_Byte default_is_stmt;
  SWIPR_Dwarf_Sbyte line_base;
  SWIPR_Dwarf_Byte line_range;
  SWIPR_Dwarf_Byte opcode_base;

  // Variable length fields:
  // SWIPR_Dwarf_Byte standard_opcode_lengths[];
  // SWIPR_Dwarf_Byte directory_entry_format_count;
  // SWIPR_Dwarf_ULEB128 directory_entry_format[];
  // SWIPR_Dwarf_ULEB128 directories_count;
  // encoded directories[];
  // SWIPR_Dwarf_Byte file_name_entry_format_count;
  // SWIPR_Dwarf_ULEB128 file_name_entry_format;
  // SWIPR_Dwarf_ULEB128 file_names_count;
  // encoded file_names[];
} DWARF64_Lhdr;

/* .. Call frame instruction encodings ...................................... */

// Table 7.29
enum internal_SWIPR_DWARF_BYTECODE {
  internal_SWIPR_DW_CFA_advance_loc        = 0x40,
  internal_SWIPR_DW_CFA_offset             = 0x80,
  internal_SWIPR_DW_CFA_restore            = 0xc0,
  internal_SWIPR_DW_CFA_nop                = 0x00,
  internal_SWIPR_DW_CFA_set_loc            = 0x01,
  internal_SWIPR_DW_CFA_advance_loc1       = 0x02,
  internal_SWIPR_DW_CFA_advance_loc2       = 0x03,
  internal_SWIPR_DW_CFA_advance_loc4       = 0x04,
  internal_SWIPR_DW_CFA_offset_extended    = 0x05,
  internal_SWIPR_DW_CFA_restore_extended   = 0x06,
  internal_SWIPR_DW_CFA_undefined          = 0x07,
  internal_SWIPR_DW_CFA_same_value         = 0x08,
  internal_SWIPR_DW_CFA_register           = 0x09,
  internal_SWIPR_DW_CFA_remember_state     = 0x0a,
  internal_SWIPR_DW_CFA_restore_state      = 0x0b,
  internal_SWIPR_DW_CFA_def_cfa            = 0x0c,
  internal_SWIPR_DW_CFA_def_cfa_register   = 0x0d,
  internal_SWIPR_DW_CFA_def_cfa_offset     = 0x0e,
  internal_SWIPR_DW_CFA_def_cfa_expression = 0x0f,
  internal_SWIPR_DW_CFA_expression         = 0x10,
  internal_SWIPR_DW_CFA_offset_extended_sf = 0x11,
  internal_SWIPR_DW_CFA_def_cfa_sf         = 0x12,
  internal_SWIPR_DW_CFA_def_cfa_offset_sf  = 0x13,
  internal_SWIPR_DW_CFA_val_offset         = 0x14,
  internal_SWIPR_DW_CFA_val_offset_sf      = 0x15,
  internal_SWIPR_DW_CFA_val_expression     = 0x16,
  internal_SWIPR_DW_CFA_lo_user            = 0x1c,
  internal_SWIPR_DW_CFA_hi_user            = 0x3f
};

/* .. Range list encodings .................................................. */

// Table 7.30
typedef internal_SWIPR_DWARF_ENUM(SWIPR_Dwarf_Byte, SWIPR_Dwarf_RLE_Entry) {
  internal_SWIPR_DW_RLE_end_of_list   = 0x00,
  internal_SWIPR_DW_RLE_base_addressx = 0x01,
  internal_SWIPR_DW_RLE_startx_endx   = 0x02,
  internal_SWIPR_DW_RLE_startx_length = 0x03,
  internal_SWIPR_DW_RLE_offset_pair   = 0x04,
  internal_SWIPR_DW_RLE_base_address  = 0x05,
  internal_SWIPR_DW_RLE_start_end     = 0x06,
  internal_SWIPR_DW_RLE_start_length  = 0x07
} SWIPR_Dwarf_RLE_Entry;

/* .. Common Information Entry .............................................. */

// Table 4.5: Common Information Entry (CIE)
typedef struct {
  SWIPR_Dwarf32_Length length;
  SWIPR_Dwarf32_Offset CIE_id;
  SWIPR_Dwarf_Byte     version;

  // Followed by variable length fields as follows:
  //
  // SWIPR_Dwarf_Byte augmentation[]; // NUL terminated string
  // SWIPR_Dwarf_Byte address_size;
  // SWIPR_Dwarf_Byte segment_selector_size;
  // SWIPR_Dwarf_ULEB128 code_alignment_factor;
  // SWIPR_Dwarf_SLEB128 data_alignment_factor;
  // SWIPR_Dwarf_ULEB128 return_address_register;
  // SWIPR_Dwarf_Byte initial_instructions[];
  // SWIPR_Dwarf_Byte padding[]
} SWIPR_Dwarf32_CIEHdr;

typedef struct {
  SWIPR_Dwarf64_Length length;
  SWIPR_Dwarf64_Offset CIE_id;
  SWIPR_Dwarf_Byte     version;

  // Followed by variable length fields as follows:
  //
  // SWIPR_Dwarf_Byte augmentation[]; // NUL terminated string
  // SWIPR_Dwarf_Byte address_size;
  // SWIPR_Dwarf_Byte segment_selector_size;
  // SWIPR_Dwarf_ULEB128 code_alignment_factor;
  // SWIPR_Dwarf_SLEB128 data_alignment_factor;
  // SWIPR_Dwarf_ULEB128 return_address_register;
  // SWIPR_Dwarf_Byte initial_instructions[];
  // SWIPR_Dwarf_Byte padding[]
} SWIPR_Dwarf64_CIEHdr;

/* .. Frame Descriptor Entry ................................................ */

// Table 4.7: Frame Descriptor Entry (FDE)
typedef struct {
  SWIPR_Dwarf32_Length length;
  SWIPR_Dwarf32_Offset CIE_pointer;   // Offset into the section that points at CIE

  // Followed by variable fields as follows:
  //
  // SWIPR_Dwarf_FarAddr initial_location; // May include segment selector and address
  // SWIPR_Dwarf_Addr    address_range;    // Number of bytes of instructions
  // SWIPR_Dwarf_Byte    instructions[];
  // SWIPR_Dwarf_Byte    padding[];
} SWIPR_Dwarf32_FDEHdr;

#pragma pack(pop)

#ifdef __cplusplus
} // namespace SWIPRruntime
} // namespace SWIPRswift
#endif

#endif // SWIFT_DWARF_H
