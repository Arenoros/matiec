/*
 *  matiec - a compiler for the programming languages defined in IEC 61131-3
 *
 *  Copyright (C) 2009-2011  Mario de Sousa (msousa@fe.up.pt)
 *  Copyright (C) 2007-2011  Laurent Bessard and Edouard Tisserant
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *
 * This code is made available on the understanding that it will not be
 * used in safety-critical situations without a full and competent review.
 */

/*
 * An IEC 61131-3 compiler.
 *
 * Based on the
 * FINAL DRAFT - IEC 61131-3, 2nd Ed. (2001-12-10)
 *
 */


/*
 * This is the main stage 3a file.
 *
 * In stage 3a some helpful symbol tables are instanciated and populated.
 * These symbol tables wll then be used by stage3b and atage4 code generators.
 */




#ifndef _SEARCH_UTILS_HH
#define _SEARCH_UTILS_HH

// #include <stdio.h>  /* required for NULL */
#include "util/symtable.h"
#include "util/dsymtable.h"
#include "absyntax/absyntax.h"
#include "absyntax/visitor.h"


/* A symbol table with all globally declared functions... */
typedef dsymtable_c<function_declaration_c*> function_symtable_t;
extern function_symtable_t function_symtable;

/* A symbol table with all globally declared functions block types... */
typedef symtable_c<function_block_declaration_c*> function_block_type_symtable_t;
extern function_block_type_symtable_t function_block_type_symtable;

/* A symbol table with all globally declared program types... */
typedef symtable_c<program_declaration_c*> program_type_symtable_t;
extern program_type_symtable_t program_type_symtable;

/* A symbol table with all user declared type definitions... */
/* Note that function block types and program types have their
 * own symbol tables, so do not get placed in this symbol table!
 *
 * The symbol_c * associated to the value will point to the data type declaration.
 */
typedef symtable_c<symbol_c*> type_symtable_t;
extern type_symtable_t type_symtable;


/* returns 0 if the names are equal!! Case is ignored. */
int compare_identifiers(symbol_c *ident1, symbol_c *ident2);

struct symtable_t {
    /* A symbol table with all globally declared functions... */
    dsymtable_c<function_declaration_c*> functions;

    /* A symbol table with all globally declared functions block types... */
    symtable_c<function_block_declaration_c*> function_blocks;

    /* A symbol table with all globally declared program types... */
    symtable_c<program_declaration_c*> programe;

    /* A symbol table with all user declared type definitions... */
    /* Note that function block types and program types have their
     * own symbol tables, so do not get placed in this symbol table!
     *
     * The symbol_c * associated to the value will point to the data type declaration.
     */
    symtable_c<symbol_c*> types;
};


/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
/***********************************************************************/

#include "spec_init_separator.h"
#include "array_dimension_iterator.h"
#include "case_element_iterator.h"
#include "function_param_iterator.h"
#include "function_call_iterator.h"
#include "function_call_param_iterator.h"
#include "type_initial_value.h"
#include "search_fb_instance_decl.h"
#include "search_fb_typedecl.h"
#include "search_base_type.h"
#include "search_var_instance_decl.h"
#include "decompose_var_instance_name.h"
#include "search_varfb_instance_type.h"
#include "add_en_eno_param_decl.h"
#include "get_sizeof_datatype.h"
#include "search_il_label.h"
#include "get_var_name.h"
#include "get_datatype_info.h"
#include "debug_ast.h"

/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
/***********************************************************************/




void absyntax_utils_init(symbol_c *tree_root);


#endif /* _SEARCH_UTILS_HH */
