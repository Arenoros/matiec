#pragma once

#include <cstddef>
#include <cstdio>

/* A counter to track the order by which each token is processed.
 * NOTE: This counter is not exactly linear (i.e., it does not get incremented by 1 for each token).
 *       i.e.. it may get incremented by more than one between two consecutive tokens.
 *       This is due to the fact that the counter gets incremented every 'user action' in flex,
 *       however not every user action will result in a token being passed to bison.
 *       Nevertheless this is still OK, as we are only interested in the relative
 *       ordering of tokens...
 */

struct tracking_t {
    int eof;
    int lineNumber;
    int currentChar;
    int lineLength;
    int currentTokenStart;
    tracking_t() {
        eof = 0;
        lineNumber = 1;
        currentChar = 0;
        lineLength = 0;
        currentTokenStart = 0;
    }
};
struct include_stack_t {
    struct yy_buffer_state* buffer_state;
    tracking_t* env;
    const char* filename;
};

static const char* INCLUDE_DIRECTORIES[] = {
    ".",
    "/lib",
    "/usr/lib",
    "/usr/lib/iec",
    NULL /* must end with NULL!! */
};