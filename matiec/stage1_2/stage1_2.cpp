/*
 *  matiec - a compiler for the programming languages defined in IEC 61131-3
 *
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
 * This file contains the code that calls the stage 1 (lexical anayser)
 * and stage 2 (syntax parser) during the first pass.
 */

#include <string.h>
#include <stdlib.h>

/* file with declaration of absyntax classes... */
#include "absyntax/absyntax.h"

#include "main.h"
#include "stage1_2.h"
#include "iec_bison.tab.h"
#include "stage1_2_priv.h"
#include "create_enumtype_conversion_functions.h"

/************************/
/* Utility Functions... */
/************************/

/*
 * Join two strings together. Allocate space with malloc(3).
 */
char* strdup2(const char* a, const char* b) {
    std::string tmp(a);
    tmp += b;
    char* res = (char*)malloc(tmp.size() + 1);
    if (!res) {
        ERROR_MSG("Out of memory. Bailing out!\n");
    }
    if (strcpy_s(res, tmp.size() + 1, tmp.c_str())) {
        ERROR_MSG("strcpy_s failed. Bailing out!\n");
    }
    return res;
}

/*
 * Join three strings together. Allocate space with malloc(3).
 */
char* strdup3(const char* a, const char* b, const char* c) {
    std::string tmp(a);
    tmp += b;
    tmp += c;
    char* res = (char*)malloc(tmp.size() + 1);
    if (!res) {
        ERROR_MSG("Out of memory. Bailing out!\n");
    }
    if (strcpy_s(res, tmp.size() + 1, tmp.c_str())) {
        ERROR_MSG("strcpy_s failed. Bailing out!\n");
    }
    return res;
}

char* creat_strcopy(const char* str) {
    size_t len = strlen(str);
    char* cpy = (char*)malloc(len + 1);
    if (!cpy) {
        ERROR_MSG("Out of memory. Bailing out!\n");
    }
    if (strcpy_s(cpy, len + 1, str)) {
        ERROR_MSG("strcpy_s failed. Bailing out!\n");
    }
    cpy[len] = '\0';
    return cpy;
}

void yyerror(YYLTYPE* locp, yyscan_t scanner, parser_t* parser, const char* msg) {}
void include_file(const char* include_filename) {}

/***********************************************************************/
