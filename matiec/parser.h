#pragma once

#include "traking.h"
#include "util/symtable.h"
#include "absyntax_utils/absyntax_utils.h"

#define MAX_LINE_LENGTH 1024
typedef void* yyscan_t;

struct parser_t {
    typedef symtable_c<int> library_element_symtable_t;
    typedef symtable_c<int> variable_name_symtable_t;
    typedef symtable_c<int> direct_variable_symtable_t;
    symtable_t context;
    symbol_c* tree_root;
    symbol_c* ordered_root;
    tracking_t* current_tracking;
    tracking_t previous_tracking;
    runtime_options_t runtime_options;
    std::vector<include_stack_t> include_stack;

    /* The buffer used by the body_state state */
    tracking_t bodystate_init_tracking;
    std::string bodystate_buffer;
    bool bodystate_is_whitespace = 1;

    int include_stack_ptr = 0;
    long int current_order = 0;

    /* A global flag used to tell the parser if overloaded funtions should be allowed.
     * The IEC 61131-3 standard allows overloaded funtions in the standard library,
     * but disallows them in user code...
     */
    bool allow_function_overloading;

    /* A flag to tell the compiler whether to allow the declaration
     * of extensible function (i.e. functions that may have a variable number of
     * input parameters, such as AND(word#33, word#44, word#55, word#66).
     * This is an extension to the standard syntax.
     * See comments below for details why we support this!
     */
    bool allow_extensible_function_parameters;

    /* A global flag used to tell the parser whether to allow use of DREF and '^' operators (defined in IEC 61131-3 v3)
     */
    bool allow_ref_dereferencing;

    /* A global flag used to tell the parser whether to allow use of REF_TO ANY datatypes (non-standard extension to IEC
     * 61131-3 v3) */
    bool allow_ref_to_any;

    /* A global flag used to tell the parser whether to allow use of REF_TO as a struct or array element (non-standard
     * extension) */
    bool allow_ref_to_in_derived_datatypes;

    /*************************/
    /* Tracking Functions... */
    /*************************/
    parser_t();
    void define_global_vars();
    list_c* root() const {
        return (list_c*)tree_root;
    }
    /* print the include file stack to stderr... */
    void print_include_stack(void);

    void FreeTracking(tracking_t* tracking) {
        include_stack.pop_back();
        delete tracking;
    }
    int lineNumber() {
        return current_tracking->lineNumber;
    }
    int currentChar() {
        return current_tracking->currentChar;
    }
    void backup_tracking() {
        previous_tracking = *current_tracking;
    }
    void restore_tracking() {
        *current_tracking = previous_tracking;
    }
    void update_cur_tocken() {
        current_tracking->currentTokenStart = current_tracking->currentChar;
    }
    void UpdateTracking(const char* text);

    /******************************************************/
    /* whether we are suporting safe extensions           */
    /* as defined in PLCopen - Technical Committee 5      */
    /* Safety Software Technical Specification,           */
    /* Part 1: Concepts and Function Blocks,              */
    /* Version 1.0 – Official Release                     */
    /******************************************************/
    bool get_opt_safe_extensions() {
        return runtime_options.safe_extensions;
    }

    /************************************/
    /* whether to allow nested comments */
    /************************************/
    bool get_opt_nested_comments() {
        return runtime_options.nested_comments;
    }

    /**************************************************************************/
    /* whether to allow REF(), DREF(), REF_TO, NULL and ^ operators/keywords  */
    /**************************************************************************/
    bool get_opt_ref_standard_extensions() {
        return runtime_options.ref_standard_extensions;
    }

    /**********************************************************************************************/
    /* whether bison is doing the pre-parsing, where POU bodies and var declarations are ignored! */
    /**********************************************************************************************/
    bool preparse_state__;

    void set_preparse_state(void) {
        preparse_state__ = true;
    }
    void rst_preparse_state(void) {
        preparse_state__ = false;
    }
    bool get_preparse_state(void) {
        return preparse_state__;
    }  // returns true if bison is in preparse state

    /****************************************************/
    /* Controlling the entry to the body_state in flex. */
    /****************************************************/
    int goto_body_state__;

    void cmd_goto_body_state(void) {
        goto_body_state__ = 1;
    }
    int get_goto_body_state(void) {
        return goto_body_state__;
    }
    void rst_goto_body_state(void) {
        goto_body_state__ = 0;
    }

    /*************************************************************/
    /* Controlling the entry to the sfc_qualifier_state in flex. */
    /*************************************************************/
    int goto_sfc_qualifier_state__;

    void cmd_goto_sfc_qualifier_state(void) {
        goto_sfc_qualifier_state__ = 1;
    }
    int get_goto_sfc_qualifier_state(void) {
        return goto_sfc_qualifier_state__;
    }
    void rst_goto_sfc_qualifier_state(void) {
        goto_sfc_qualifier_state__ = 0;
    }

    /*************************************************************/
    /* Controlling the entry to the sfc_priority_state in flex.  */
    /*************************************************************/
    int goto_sfc_priority_state__;

    void cmd_goto_sfc_priority_state(void) {
        goto_sfc_priority_state__ = 1;
    }
    int get_goto_sfc_priority_state(void) {
        return goto_sfc_priority_state__;
    }
    void rst_goto_sfc_priority_state(void) {
        goto_sfc_priority_state__ = 0;
    }

    /*************************************************************/
    /* Controlling the entry to the sfc_qualifier_state in flex. */
    /*************************************************************/
    int goto_task_init_state__;

    void cmd_goto_task_init_state(void) {
        goto_task_init_state__ = 1;
    }
    int get_goto_task_init_state(void) {
        return goto_task_init_state__;
    }
    void rst_goto_task_init_state(void) {
        goto_task_init_state__ = 0;
    }

    /****************************************************************/
    /* Returning to state in flex previously pushed onto the stack. */
    /****************************************************************/
    int pop_state__;

    void cmd_pop_state(void) {
        pop_state__ = 1;
    }
    int get_pop_state(void) {
        return pop_state__;
    }
    void rst_pop_state(void) {
        pop_state__ = 0;
    }
    /* Function only called from within flex!
     *
     * search for a symbol in either of the two symbol tables
     * declared above, and return the token id of the first
     * symbol found.
     * Searches first in the variables, and only if not found
     * does it continue searching in the library elements
     */
    int get_identifier_token(const char* identifier_str);

    /* Function only called from within flex!
     *
     * search for a symbol in direct variables symbol table
     * declared above, and return the token id of the first
     * symbol found.
     */
    int get_direct_variable_token(const char* direct_variable_str);

    /*********************************/
    /* The global symbol tables...   */
    /*********************************/
    /* NOTE: only accessed indirectly by the lexical parser (flex)
     *       through the function get_identifier_token()
     */
    /* A symbol table to store all the library elements */
    /* e.g.: <function_name , function_decl>
     *       <fb_name , fb_decl>
     *       <type_name , type_decl>
     *       <program_name , program_decl>
     *       <configuration_name , configuration_decl>
     */
    /* static */ library_element_symtable_t library_element_symtable;

    /* A symbol table to store the declared variables of
     * the function currently being parsed...
     */
    /* static */ variable_name_symtable_t variable_name_symtable;

    /* A symbol table to store the declared direct variables of
     * the function currently being parsed...
     */
    /* static */ direct_variable_symtable_t direct_variable_symtable;

    void reg_c_var(const char* name);
    void reg_c_func(const char* name);

    void unput_bodystate_buffer(yyscan_t scanner);

    /* append text to bodystate_buffer */
    void append_bodystate_buffer(const char* text, int is_whitespace = 0);

    /* Return true if bodystate_buffer is empty or ony contains whitespace!! */
    int isempty_bodystate_buffer();

    void print_err_msg(int first_line,
                       int first_column,
                       const char* first_filename,
                       long int first_order,
                       int last_line,
                       int last_column,
                       const char* last_filename,
                       long int last_order,
                       const char* additional_error_msg);
};