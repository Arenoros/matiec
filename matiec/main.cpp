/*
 *  matiec - a compiler for the programming languages defined in IEC 61131-3
 *  Copyright (C) 2003-2011  Mario de Sousa (msousa@fe.up.pt)
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
 ****************************************************************
 ****************************************************************
 ****************************************************************
 *********                                              *********
 *********                                              *********
 *********   O V E R A L L    A R C H I T E C T U R E   *********
 *********                                              *********
 *********                                              *********
 ****************************************************************
 ****************************************************************
 ****************************************************************

 The compiler works in 4(+1) stages:
 Stage 1   - Lexical analyser      - implemented with flex (iec.flex)
 Stage 2   - Syntax parser         - implemented with bison (iec.y)
 Stage 3   - Semantics analyser    - not yet implemented
 Stage 4   - Code generator        - implemented in C++
 Stage 4+1 - Binary code generator - gcc, javac, etc...


 Data structures passed between stages, in global variables:
 1->2   : tokens (int), and token values (char *)
 2->1   : symbol tables (defined in symtable.hh)
 2->3   : abstract syntax tree (tree of C++ classes, in absyntax.hh file)
 3->4   : Same as 2->3
 4->4+1 : file with program in c, java, etc...


 The compiler works in several passes:
 Pass 1: executes stages 1 and 2 simultaneously
 Pass 2: executes stage 3
 Pass 3: executes stage 4
 Pass 4: executes stage 4+1
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <iostream>

#include "absyntax/absyntax.h"
#include "absyntax_utils/absyntax_utils.h"
#include "stage1_2/stage1_2.h"
#include "stage3/stage3.h"
#include "stage4/stage4.h"
#include "main.h"


#ifndef HGVERSION
#    define HGVERSION ""
#endif

void error_exit(const char* file_name, int line_no, const char* errmsg, ...) {
    va_list argptr;
    va_start(argptr, errmsg); /* second argument is last fixed pamater of error_exit() */

    fprintf(stderr, "\nInternal compiler error in file %s at line %d", file_name, line_no);
    if (errmsg != NULL) {
        fprintf(stderr, ": ");
        vfprintf(stderr, errmsg, argptr);
    } else {
        fprintf(stderr, ".");
    }
    fprintf(stderr, "\n");
    va_end(argptr);

    exit(EXIT_FAILURE);
}

static void printusage(const char* cmd) {
    printf(
        "\nsyntax: %s [<options>] [-O <output_options>] [-I <include_directory>] [-T <target_directory>] "
        "<input_file>\n",
        cmd);
    printf(" -h : show this help message\n");
    printf(" -v : print version number\n");
    printf(" -f : display full token location on error messages\n");
    printf(" -p : allow use of forward references                (a non-standard extension?)\n");
    printf(" -l : use a relaxed datatype equivalence model       (a non-standard extension?)\n");
    printf(
        " -s : allow use of safe datatypes (SAFEBOOL, etc.)   (defined in PLCOpen Safety)\n");  // PLCopen TC5 "Safety
                                                                                                // Software Technical
                                                                                                // Specification - Part
                                                                                                // 1" v1.0
    printf(" -n : allow use of nested comments                   (an IEC 61131-3 v3 feature)\n");
    printf(" -r : allow use of references (REF_TO, REF, ^, NULL) (an IEC 61131-3 v3 feature)\n");
    printf(" -R : allow use of REF_TO ANY datatypes              (a non-standard extension!)\n");
    printf("        as well as REF_TO in ARRAYs and STRUCTs      (a non-standard extension!)\n");
    printf(" -a : allow use of non-literals in array size limits (a non-standard extension!)\n");
    printf(" -i : allow POUs with no in out and inout parameters (a non-standard extension!)\n");
    printf(" -b : allow functions returning VOID                 (a non-standard extension!)\n");
    printf(" -e : disable generation of implicit EN and ENO parameters.\n");
    printf(" -c : create conversion functions for enumerated data types\n");
    printf(" -O : options for output (code generation) stage. Available options for %s are...\n", cmd);
    // runtime_options.allow_missing_var_in =
    //     false; /* disable: allow definition and invocation of POUs with no input, output and in_out parameters! */
    stage4_print_options();
    printf("\n");
}

int main(int argc, char** argv) {
    yyscan_t scanner;
    yylex_init(&scanner);
    FILE* fin = nullptr;
    auto err = fopen_s(&fin, "test1.txt", "r");
    if (err) {
        char errmsg[255] = {0};
        strerror_s(errmsg, 254, err);
        std::cerr << errmsg << std::endl;
        return 1;
    }
    yyset_in(fin, scanner);

    /***************************/
    /*   Run the compiler...   */
    /***************************/
    /* 1st Pass */
    parser_t parser;
    int rv = yyparse(scanner, &parser);
    if (rv < 0)
        return EXIT_FAILURE;

    /* 2nd Pass */
    /* basically loads some symbol tables to speed up look ups later on */
    absyntax_utils_init(parser.tree_root);
    /* moved to bison, although it could perfectly well still be here instead of in bison code. */
    // add_en_eno_param_decl_c::add_to(tree_root);

    /* Do semantic verification of code */
    if (stage3(&parser) < 0)
        return EXIT_FAILURE;

    /* 3rd Pass */
    if (stage4(parser.ordered_root, "./") < 0)
        return EXIT_FAILURE;

    /* 4th Pass */
    /* Call gcc, g++, or whatever... */
    /* Currently implemented in the Makefile! */

    return 0;
}
