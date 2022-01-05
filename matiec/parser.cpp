#include "parser.h"

#include "stage1_2/iec_bison.tab.h"

void unput_char(const char c, yyscan_t yyscanner);

parser_t::parser_t()
    : goto_body_state__(0), goto_sfc_qualifier_state__(0), goto_sfc_priority_state__(0), goto_task_init_state__(0),
      pop_state__(0) {
    tree_root = new library_c();
    current_tracking = new tracking_t;
    preparse_state__ = false;
    runtime_options.allow_void_datatype = false; /* disable: allow declaration of functions returning VOID  */
    runtime_options.allow_missing_var_in =
        false; /* disable: allow definition and invocation of POUs with no input, output and in_out parameters! */
    runtime_options.disable_implicit_en_eno = false; /* disable: do not generate EN and ENO parameters */
    runtime_options.pre_parsing = false; /* disable: allow use of forward references (run pre-parsing phase before the
                                            definitive parsing phase that builds the AST) */
    runtime_options.safe_extensions = false;      /* disable: allow use of SAFExxx datatypes */
    runtime_options.full_token_loc = false;       /* disable: error messages specify full token location */
    runtime_options.conversion_functions = false; /* disable: create a conversion function for derived datatype */
    runtime_options.nested_comments = false;      /* disable: Allow the use of nested comments. */
    runtime_options.ref_standard_extensions =
        false; /* disable: Allow the use of REFerences (keywords REF_TO, REF, DREF, ^, NULL). */
    runtime_options.ref_nonstand_extensions = false;  /* disable: Allow the use of non-standard extensions to REF_TO
                                                          datatypes: REF_TO ANY, and REF_TO in struct elements! */
    runtime_options.nonliteral_in_array_size = false; /* disable: Allow the use of constant non-literals when specifying
                                                         size of arrays (ARRAY [1..max] OF INT) */
    runtime_options.includedir = NULL; /* Include directory, where included files will be searched for... */

    /* Default values for the command line options... */
    runtime_options.relaxed_datatype_model = false; /* by default use the strict datatype equivalence model */
}

void parser_t::print_include_stack() {
    if (!include_stack.empty())
        fprintf(stderr, "in file ");
    for (auto& inc: include_stack)
        fprintf(stderr, "included from file %s:%d\n", inc.filename, inc.env->lineNumber);
}

void parser_t::UpdateTracking(const char* text) {
    const char *newline, *token = text;
    while ((newline = strchr(token, '\n')) != NULL) {
        token = newline + 1;
        current_tracking->lineNumber++;
        current_tracking->currentChar = 1;
    }
    current_tracking->currentChar += strlen(token);
}

int parser_t::get_identifier_token(const char* identifier_str) {
    //  std::cout << "get_identifier_token(" << identifier_str << "): \n";
    variable_name_symtable_t ::iterator iter1;
    library_element_symtable_t::iterator iter2;

    if ((iter1 = variable_name_symtable.find(identifier_str)) != variable_name_symtable.end())
        return iter1->second;

    if ((iter2 = library_element_symtable.find(identifier_str)) != library_element_symtable.end())
        return iter2->second;

    return identifier_token;
}

int parser_t::get_direct_variable_token(const char* direct_variable_str) {
    direct_variable_symtable_t::iterator iter;

    if ((iter = direct_variable_symtable.find(direct_variable_str)) != direct_variable_symtable.end())
        return iter->second;

    return direct_variable_token;
}

void parser_t::unput_bodystate_buffer(yyscan_t scanner) {
    if (bodystate_buffer.empty())
        ERROR;
    // printf("<<<unput_bodystate_buffer>>>\n%s\n", bodystate_buffer);

    for (size_t i = bodystate_buffer.size(); i > 0; i--)
        unput_char(bodystate_buffer[i - 1], scanner);

    bodystate_buffer.clear();
    bodystate_is_whitespace = true;
    *current_tracking = bodystate_init_tracking;
}

void parser_t::append_bodystate_buffer(const char* text, int is_whitespace) {
    // printf("<<<append_bodystate_buffer>>> %d <%s><%s>\n", bodystate_buffer, text, (NULL !=
    // bodystate_buffer)? bodystate_buffer:"NULL");

    // make backup of tracking if we are starting off a new body_state_buffer
    if (bodystate_buffer.empty())
        bodystate_init_tracking = *current_tracking;
    // set bodystate_is_whitespace flag if we are starting a new buffer
    if (bodystate_buffer.empty())
        bodystate_is_whitespace = true;
    // set bodystate_is_whitespace flag to FALSE if we are adding non white space to buffer
    if (!is_whitespace)
        bodystate_is_whitespace = 0;

    bodystate_buffer += text;
}

int parser_t::isempty_bodystate_buffer() {
    if (bodystate_buffer.empty())
        return 1;
    if (bodystate_is_whitespace)
        return 1;
    return 0;
}

void parser_t::print_err_msg(int first_line,
                             int first_column,
                             const char* first_filename,
                             long first_order,
                             int last_line,
                             int last_column,
                             const char* last_filename,
                             long last_order,
                             const char* additional_error_msg) {
    const char* unknown_file = "<unknown_file>";
    if (first_filename == NULL)
        first_filename = unknown_file;
    if (last_filename == NULL)
        last_filename = unknown_file;

    if (runtime_options.full_token_loc) {
        if (first_filename == last_filename)
            fprintf(stderr,
                    "%s:%d-%d..%d-%d: error: %s\n",
                    first_filename,
                    first_line,
                    first_column,
                    last_line,
                    last_column,
                    additional_error_msg);
        else
            fprintf(stderr,
                    "%s:%d-%d..%s:%d-%d: error: %s\n",
                    first_filename,
                    first_line,
                    first_column,
                    last_filename,
                    last_line,
                    last_column,
                    additional_error_msg);
    } else {
        fprintf(stderr, "%s:%d: error: %s\n", first_filename, first_line, additional_error_msg);
    }
    // fprintf(stderr, "error %d: %s\n", yynerrs /* a global variable */, additional_error_msg);
    // print_include_stack();
}
