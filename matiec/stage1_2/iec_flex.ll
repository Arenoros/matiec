%option noinput noyywrap 8bit nodefault                                 
%option reentrant bison-bridge bison-locations                                  
%option header-file="iec_flex.h"

/* The lexical analyser will never work in interactive mode,
 * i.e., it will only process programs saved to files, and never
 * programs being written inter-actively by the user.
 * This option saves the resulting parser from calling the
 * isatty() function, that seems to be generating some compile
 * errors under some (older?) versions of flex.
 */
%option never-interactive

/* Have the lexical analyser use a 'char *yytext' instead of an
 * array of char 'char yytext[??]' to store the lexical token.
 */
%pointer

/* Have the generated lexical analyser keep track of the
 * line number it is currently analysing.
 * This is used to pass up to the syntax parser
 * the number of the line on which the current
 * token was found. It will enable the syntax parser
 * to generate more informatve error messages...
 */
%option yylineno

/* required for the use of the yy_pop_state(yyscanner) and
 * yy_push_state() functions
 */
%option stack

/* The '%option stack' also requests the inclusion of 
 * the yy_top_state(), however this function is not
 * currently being used. This means that the compiler
 * is complaining about the existance of this function.
 * The following option removes the yy_top_state()
 * function from the resulting c code, so the compiler 
 * no longer complains.
 */
%option noyy_top_state

%{
#define _CRT_SECURE_NO_WARNINGS
   #include <string>
   #include "iec_bison.tab.h"
   
#pragma warning( disable : 4005)

#define YY_USER_ACTION {\
        parser->backup_tracking();					\
        yylloc->first_line   = parser->lineNumber();			\
        yylloc->first_column = parser->currentChar();			\
        yylloc->first_order  = parser->current_order;					\
        \
        parser->UpdateTracking(yytext);							\
        \
        yylloc->last_line    = parser->lineNumber();			\
        yylloc->last_column  = parser->currentChar() - 1;		\
        yylloc->last_order   = parser->current_order;					\
        \
        parser->update_cur_tocken();	\
        parser->current_order++;							\
	}

char* craet_strcopy(const char* str);
%}

/***************************************************/
/* Forward Declaration of functions defined later. */
/***************************************************/

%{

/* return the character back to the input stream. */
void unput_char(const char c, yyscan_t scanner);
/* return all the text in the current token back to the input stream. */
void unput_text(int n, yyscan_t scanner, parser_t* parser);
/* return all the text in the current token back to the input stream, 
 * but first return to the stream an additional character to mark the end of the token. 
 */
void unput_and_mark(const char mark_char, yyscan_t scanner, parser_t* parser);

void include_file(const char *include_filename);

/* The body_state tries to find a ';' before a END_PROGRAM, END_FUNCTION or END_FUNCTION_BLOCK or END_ACTION
 * and ignores ';' inside comments and pragmas. This means that we cannot do this in a signle lex rule.
 * Body_state therefore stores ALL text we consume in every rule, so we can push it back into the buffer
 * once we have decided if we are parsing ST or IL code. The following functions manage that buffer used by
 * the body_state.
 */


%}

/* Bison is in the pre-parsing stage, and we are parsing a POU. Ignore everything up to the end of the POU! */
%x ignore_pou_state
%x get_pou_name_state

/* we are parsing a configuration. */
%s config_state

/* Inside a configuration, we are parsing a task initialisation parameters */
/* This means that PRIORITY, SINGLE and INTERVAL must be handled as
 * tokens, and not as possible identifiers. Note that the above words
 * are not keywords.
 */
%s task_init_state

/* we are looking for the first VAR inside a function's, program's or function block's declaration */
/* This is not exclusive (%x) as we must be able to parse the identifier and data types of a function/FB */
%s header_state

/* we are parsing a function, program or function block sequence of VAR..END_VAR delcarations */
%x vardecl_list_state 
/* a substate of the vardecl_list_state: we are inside a specific VAR .. END_VAR */
%s vardecl_state

/* we will be parsing a function body/action/transition. Whether il/st/sfc remains to be determined */
%x body_state

/* we are parsing il code -> flex must return the EOL tokens!       */
%s il_state

/* we are parsing st code -> flex must not return the EOL tokens!   */
%s st_state

/* we are parsing sfc code -> flex must not return the EOL tokens!  */
%s sfc_state

/* we are parsing sfc code, and expecting an action qualifier.      */
%s sfc_qualifier_state

/* we are parsing sfc code, and expecting the priority token.       */
%s sfc_priority_state

/* we are parsing a TIME# literal. We must not return any {identifier} tokens. */
%x time_literal_state

/* we are parsing a comment. */
%x comment_state


/*******************/
/* File #include's */
/*******************/

/* We extend the IEC 61131-3 standard syntax to allow inclusion
 * of other files, using the IEC 61131-3 pragma directive...
 * The accepted syntax is:
 *  {#include "<filename>"}
 */

/* the "include" states are used for picking up the name of an include file */
%x include_beg
%x include_filename
%x include_end


file_include_pragma_filename	[^\"]*
file_include_pragma_beg		"{#include"{st_whitespace}\"
file_include_pragma_end		\"{st_whitespace}"}"
file_include_pragma			{file_include_pragma_beg}{file_include_pragma_filename}{file_include_pragma_end}


%{
%}

/*****************************/
/* Prelimenary constructs... */
/*****************************/

/* PRAGMAS */
/* ======= */
/* In order to allow the declaration of POU prototypes (Function, FB, Program, ...),
 * especially the prototypes of Functions and FBs defined in the standard
 * (i.e. standard functions and FBs), we extend the IEC 61131-3 standard syntax 
 * with two pragmas to indicate that the code is to be parsed (going through the 
 * lexical, syntactical, and semantic analysers), but no code is to be generated.
 * 
 * The accepted syntax is:
 *  {no_code_generation begin}
 *    ... prototypes ...
 *  {no_code_generation end}
 * 
 * When parsing these prototypes the abstract syntax tree will be populated as usual,
 * allowing the semantic analyser to correctly analyse the semantics of calls to these
 * functions/FBs. However, stage4 will simply ignore all IEC61131-3 code
 * between the above two pragmas.
 */

disable_code_generation_pragma	"{disable code generation}"
enable_code_generation_pragma	"{enable code generation}"


/* Any other pragma... */
pragma ("{"[^}]*"}")|("{{"([^}]|"}"[^}])*"}}")



/* COMMENTS */
/* ======== */

/* In order to allow nested comments, comments are handled by a specific comment_state state */
/* Whenever a "(*" is found, we push the current state onto the stack, and enter a new instance of the comment_state state.
 * Whenever a "*)" is found, we pop a state off the stack
 */

/* comments... */
comment_beg  "(*"
comment_end  "*)"

/* However, bison has a shift/reduce conflict in bison, when parsing formal function/FB
 * invocations with the 'NOT <variable_name> =>' syntax (which needs two look ahead 
 * tokens to be parsed correctly - and bison being LALR(1) only supports one).
 * The current work around requires flex to completely parse the '<variable_name> =>'
 * sequence. This sequence includes whitespace and/or comments between the 
 * <variable_name> and the "=>" token.
 * 
 * This flex rule (sendto_identifier_token) uses the whitespace/comment as trailing context,
 * which means we can not use the comment_state method of specifying/finding and ignoring 
 * comments.
 * 
 * For this reason only, we must also define what a complete comment looks like, so
 * it may be used in this rule. Since the rule uses the whitespace_or_comment
 * construct as trailing context, this definition of comment must not use any
 * trailing context either.
 * 
 * Aditionally, it is not possible to define nested comments in flex without the use of
 * states, so for this particular location, we do NOT support nested comments.
 */
/* NOTE: this seemingly unnecessary complex definition is required
 *       to be able to eat up comments such as:
 *          '(* Testing... ! ***** ******)'
 *       without using the trailing context command in flex (/{context})
 *       since {comment} itself will later be used with
 *       trailing context ({comment}/{context})
 */
not_asterisk				[^*]
not_close_parenthesis_nor_asterisk	[^*)]
asterisk				"*"
comment_text	({not_asterisk})|(({asterisk}+){not_close_parenthesis_nor_asterisk})
comment		"(*"({comment_text}*)({asterisk}+)")"



/* 3.1 Whitespace */
/* ============== */
/*
 * Whitespace is clearly defined (see IEC 61131-3 v2, section 2.1.4)
 * 
 * Whitespace definition includes the newline character.
 * 
 * However, the standard is inconsistent in that in IL the newline character 
 * is considered a token (EOL - end of line). 
 * In our implementation we therefore have two definitions of whitespace
 *   - one for ST, that includes the newline character
 *   - one for IL without the newline character.
 * Additionally, when parsing IL, the newline character is treated as the EOL token.
 * This requires the use of a state machine in the lexical parser that needs at least 
 * some knowledge of the syntax itself.
 *
 * NOTE: Our definition of whitespace will only work in ASCII!
 *
 * NOTE: we cannot use
 *         st_whitespace	[:space:]*
 *       since we use {st_whitespace} as trailing context. In our case
 *       this would not constitute "dangerous trailing context", but the
 *       lexical generator (i.e. flex) does not know this (since it does
 *       not know which characters belong to the set [:space:]), and will
 *       generate a "dangerous trailing context" warning!
 *       We use this alternative just to stop the flex utility from
 *       generating the invalid (in this case) warning...
 */

st_whitespace			[ \f\n\r\t\v]*
il_whitespace			[ \f\r\t\v]*

st_whitespace_or_pragma_or_commentX	({st_whitespace})|({pragma})|({comment})
il_whitespace_or_pragma_or_commentX	({il_whitespace})|({pragma})|({comment})

st_whitespace_or_pragma_or_comment	{st_whitespace_or_pragma_or_commentX}*
il_whitespace_or_pragma_or_comment	{il_whitespace_or_pragma_or_commentX}*



qualified_identifier	{identifier}(\.{identifier})+



/*****************************************/
/* B.1.1 Letters, digits and identifiers */
/*****************************************/
/* NOTE: The following definitions only work if the host computer
 *       is using the ASCII maping. For e.g., with EBCDIC [A-Z]
 *       contains non-alphabetic characters!
 *       The correct way of doing it would be to use
 *       the [:upper:] etc... definitions.
 *
 *       Unfortunately, further on we need all printable
 *       characters (i.e. [:print:]), but excluding '$'.
 *       Flex does not allow sets to be composed by excluding
 *       elements. Sets may only be constructed by adding new
 *       elements, which means that we have to revert to
 *       [\x20\x21\x23\x25\x26\x28-x7E] for the definition
 *       of the printable characters with the required exceptions.
 *       The above also implies the use of ASCII, but now we have
 *       no way to work around it|
 *
 *       The conclusion is that our parser is limited to ASCII
 *       based host computers!!
 */
letter		[A-Za-z]
digit		[0-9]
octal_digit	[0-7]
hex_digit	{digit}|[A-F]
identifier	({letter}|(_({letter}|{digit})))((_?({letter}|{digit}))*)

/*******************/
/* B.1.2 Constants */
/*******************/

/******************************/
/* B.1.2.1   Numeric literals */
/******************************/
integer         {digit}((_?{digit})*)

/* Some helper symbols for parsing TIME literals... */
integer_0_59    (0(_?))*([0-5](_?))?{digit}
integer_0_19    (0(_?))*([0-1](_?))?{digit}
integer_20_23   (0(_?))*2(_?)[0-3]
integer_0_23    {integer_0_19}|{integer_20_23}
integer_0_999   {digit}((_?{digit})?)((_?{digit})?)


binary_integer  2#{bit}((_?{bit})*)
bit		[0-1]
octal_integer   8#{octal_digit}((_?{octal_digit})*)
hex_integer     16#{hex_digit}((_?{hex_digit})*)
exponent        [Ee]([+-]?){integer}
/* The correct definition for real would be:
 * real		{integer}\.{integer}({exponent}?)
 *
 * Unfortunately, the spec also defines fixed_point (B 1.2.3.1) as:
 * fixed_point		{integer}\.{integer}
 *
 * This means that {integer}\.{integer} could be interpreted
 * as either a fixed_point or a real.
 * I have opted to interpret {integer}\.{integer} as a fixed_point.
 * In order to do this, the definition of real has been changed to:
 * real		{integer}\.{integer}{exponent}
 *
 * This means that the syntax parser now needs to define a real to be
 * either a real_token or a fixed_point_token!
 */
real		{integer}\.{integer}{exponent}


/*******************************/
/* B.1.2.2   Character Strings */
/*******************************/
/*
common_character_representation :=
<any printable character except '$', '"' or "'">
|'$$'
|'$L'|'$N'|'$P'|'$R'|'$T'
|'$l'|'$n'|'$p'|'$r'|'$t'

NOTE: 	$ = 0x24
	" = 0x22
	' = 0x27

	printable chars in ASCII: 0x20-0x7E
*/

esc_char_u		$L|$N|$P|$R|$T
esc_char_l		$l|$n|$p|$r|$t
esc_char		$$|{esc_char_u}|{esc_char_l}
double_byte_char	(${hex_digit}{hex_digit}{hex_digit}{hex_digit})
single_byte_char	(${hex_digit}{hex_digit})

/* WARNING:
 * This definition is only valid in ASCII...
 *
 * Flex includes the function print_char() that defines
 * all printable characters portably (i.e. whatever character
 * encoding is currently being used , ASCII, EBCDIC, etc...)
 * Unfortunately, we cannot generate the definition of
 * common_character_representation portably, since flex
 * does not allow definition of sets by subtracting
 * elements in one set from another set.
 * This means we must build up the defintion of
 * common_character_representation using only set addition,
 * which leaves us with the only choice of defining the
 * characters non-portably...
 */
common_character_representation		[\x20\x21\x23\x25\x26\x28-\x7E]|{esc_char}
double_byte_character_representation 	$\"|'|{double_byte_char}|{common_character_representation}
single_byte_character_representation 	$'|\"|{single_byte_char}|{common_character_representation}


double_byte_character_string	\"({double_byte_character_representation}*)\"
single_byte_character_string	'({single_byte_character_representation}*)'


/************************/
/* B 1.2.3.1 - Duration */
/************************/
fixed_point		{integer}\.{integer}


/* NOTE: The IEC 61131-3 v2 standard has an incorrect formal syntax definition of duration,
 *       as its definition does not match the standard's text.
 *       IEC 61131-3 v3 (committee draft) seems to have this fixed, so we use that
 *       definition instead!
 *
 *       duration::= ('T' | 'TIME') '#' ['+'|'-'] interval
 *       interval::= days | hours | minutes | seconds | milliseconds
 *       fixed_point  ::= integer [ '.' integer]
 *       days         ::= fixed_point 'd' | integer 'd' ['_'] [ hours ]
 *       hours        ::= fixed_point 'h' | integer 'h' ['_'] [ minutes ]
 *       minutes      ::= fixed_point 'm' | integer 'm' ['_'] [ seconds ]
 *       seconds      ::= fixed_point 's' | integer 's' ['_'] [ milliseconds ]
 *       milliseconds ::= fixed_point 'ms'
 * 
 * 
 *  The original IEC 61131-3 v2 definition is:
 *       duration ::= ('T' | 'TIME') '#' ['-'] interval
 *       interval ::= days | hours | minutes | seconds | milliseconds
 *       fixed_point  ::= integer [ '.' integer]
 *       days         ::= fixed_point 'd' | integer 'd' ['_'] hours
 *       hours        ::= fixed_point 'h' | integer 'h' ['_'] minutes
 *       minutes      ::= fixed_point 'm' | integer 'm' ['_'] seconds
 *       seconds      ::= fixed_point 's' | integer 's' ['_'] milliseconds
 *       milliseconds ::= fixed_point 'ms'
 */

interval_ms_X		({integer_0_999}(\.{integer})?)ms
interval_s_X		{integer_0_59}s(_?{interval_ms_X})?|({integer_0_59}(\.{integer})?s)
interval_m_X		{integer_0_59}m(_?{interval_s_X})?|({integer_0_59}(\.{integer})?m)
interval_h_X		{integer_0_23}h(_?{interval_m_X})?|({integer_0_23}(\.{integer})?h)

interval_ms		{integer}ms|({fixed_point}ms)
interval_s		{integer}s(_?{interval_ms_X})?|({fixed_point}s)
interval_m		{integer}m(_?{interval_s_X})?|({fixed_point}m)
interval_h		{integer}h(_?{interval_m_X})?|({fixed_point}h)
interval_d		{integer}d(_?{interval_h_X})?|({fixed_point}d)

interval		{interval_ms}|{interval_s}|{interval_m}|{interval_h}|{interval_d}


/* to help provide nice error messages, we also parse an incorrect but plausible interval... */
/* NOTE that this erroneous interval will be parsed outside the time_literal_state, so must not 
 *      be able to parse any other legal lexcial construct (besides a legal interval, but that
 *      is OK as this rule will appear _after_ the rule to parse legal intervals!).
 */
fixed_point_or_integer  {fixed_point}|{integer}
erroneous_interval	({fixed_point_or_integer}d_?)?({fixed_point_or_integer}h_?)?({fixed_point_or_integer}m_?)?({fixed_point_or_integer}s_?)?({fixed_point_or_integer}ms)?

/********************************************/
/* B.1.4.1   Directly Represented Variables */
/********************************************/
/* The correct definition, if the standard were to be followed... */

location_prefix			[IQM]
size_prefix			[XBWDL]
direct_variable_standard	%{location_prefix}({size_prefix}?){integer}((.{integer})*)


/* For the MatPLC, we will accept %<identifier>
 * as a direct variable, this being mapped onto the MatPLC point
 * named <identifier>
 */
/* TODO: we should not restrict it to only the accepted syntax
 * of <identifier> as specified by the standard. MatPLC point names
 * have a more permissive syntax.
 *
 * e.g. "P__234"
 *    Is a valid MatPLC point name, but not a valid <identifier> !!
 *    The same happens with names such as "333", "349+23", etc...
 *    How can we handle these more expressive names in our case?
 *    Remember that some direct variable may remain anonymous, with
 *    declarations such as:
 *    VAR
 *       AT %I3 : BYTE := 255;
 *    END_VAR
 *    in which case we are currently using "%I3" as the variable
 *    name.
 */
/* direct_variable_matplc		%{identifier} */
/* direct_variable			{direct_variable_standard}|{direct_variable_matplc} */
direct_variable			{direct_variable_standard}

/******************************************/
/* B 1.4.3 - Declaration & Initialisation */
/******************************************/
incompl_location	%[IQM]\*

%%
   /* fprintf(stderr, "flex: state %d\n", YY_START); */

	/*****************************************************/
	/*****************************************************/
	/*****************************************************/
	/*****                                           *****/
	/*****                                           *****/
	/*****   F I R S T    T H I N G S    F I R S T   *****/
	/*****                                           *****/
	/*****                                           *****/
	/*****************************************************/
	/*****************************************************/
	/*****************************************************/

	/***********************************************************/
	/* Handle requests sent by bison for flex to change state. */
	/***********************************************************/
	
	if (parser->get_goto_body_state()) {
	  yy_push_state(body_state, yyscanner);
	  parser->rst_goto_body_state();
	}

	if (parser->get_goto_sfc_qualifier_state()) {
	  yy_push_state(sfc_qualifier_state, yyscanner);
	  parser->rst_goto_sfc_qualifier_state();
	}

	if (parser->get_goto_sfc_priority_state()) {
	  yy_push_state(sfc_priority_state, yyscanner);
	  parser->rst_goto_sfc_priority_state();
	}

	if (parser->get_goto_task_init_state()) {
	  yy_push_state(task_init_state, yyscanner);
	  parser->rst_goto_task_init_state();
	}

	if (parser->get_pop_state()) {
	  yy_pop_state(yyscanner);
	  parser->rst_pop_state();
	}

	/***************************/
	/* Handle the pragmas!     */
	/***************************/

	/* We start off by searching for the pragmas we handle in the lexical parser. */
<INITIAL>{file_include_pragma}	unput_text(0, yyscanner, parser); yy_push_state(include_beg, yyscanner);

	/* Pragmas sent to syntax analyser (bison) */
	/* NOTE: In the vardecl_list_state we only process the pragmas between two consecutive VAR .. END_VAR blocks.
	 *       We do not process any pragmas trailing after the last END_VAR. We leave that to the body_state.
	 *       This is because the pragmas are stored in a statement_list or instruction_list (in bison),
	 *       but these lists must start with the special tokens start_IL_body_token/start_ST_body_token.
	 *       This means that these special tokens must be generated (by the body_state) before processing
	 *       the pragme => we cannot process the trailing pragmas in the vardecl_list_state state.
	 */
{disable_code_generation_pragma}				return disable_code_generation_pragma_token;
{enable_code_generation_pragma}					return enable_code_generation_pragma_token;
<vardecl_list_state>{disable_code_generation_pragma}/(VAR)	return disable_code_generation_pragma_token; 
<vardecl_list_state>{enable_code_generation_pragma}/(VAR)	return enable_code_generation_pragma_token;  
<body_state>{disable_code_generation_pragma}			parser->append_bodystate_buffer(yytext); /* in body state we do not process any tokens, we simply store them for later processing! */
<body_state>{enable_code_generation_pragma}			parser->append_bodystate_buffer(yytext); /* in body state we do not process any tokens, we simply store them for later processing! */
	/* Any other pragma we find, we just pass it up to the syntax parser...   */
	/* Note that the <body_state> state is exclusive, so we have to include it here too. */
<body_state>{pragma}					parser->append_bodystate_buffer(yytext); /* in body state we do not process any tokens, we simply store them for later processing! */
{pragma}	{/* return the pragmma without the enclosing '{' and '}' */
		 int cut = yytext[1]=='{'?2:1;
		 yytext[strlen(yytext)-cut] = '\0';
		 yylval->ID=creat_strcopy(yytext+cut);
		 return pragma_token;
		}
<vardecl_list_state>{pragma}/(VAR) {/* return the pragmma without the enclosing '{' and '}' */
		 int cut = yytext[1]=='{'?2:1;
		 yytext[strlen(yytext)-cut] = '\0';
		 yylval->ID=creat_strcopy(yytext+cut);
		 return pragma_token;
		}


	/*********************************/
	/* Handle the file includes!     */
	/*********************************/
<include_beg>{file_include_pragma_beg}	BEGIN(include_filename);

<include_filename>{file_include_pragma_filename}	{
			  /* set the internal state variables of lexical analyser to process a new include file */
			  include_file(yytext);
			  /* switch to whatever state was active before the include file */
			  yy_pop_state(yyscanner);
			  /* now process the new file... */
			}


<<EOF>>			{     /* NOTE: Currently bison is incorrectly using END_OF_INPUT in many rules
			       *       when checking for syntax errors in the input source code.
			       *       This means that in reality flex will be asked to carry on reading the input
			       *       even after it has reached the end of all (including the main) input files.
			       *       In other owrds, we will be called to return more tokens, even after we have
			       *       already returned an END_OF_INPUT token. In this case, we must carry on returning
			       *       more END_OF_INPUT tokens.
			       * 
			       *       However, in the above case we will be asked to carry on reading more tokens 
			       *       from the main input file, after we have reached the end. For this to work
			       *       correctly, we cannot close the main input file!
			       * 
			       *       This is why we WILL be called with include_stack_ptr == 0 multiple times,
			       *       and why we must handle it as a special case
			       *       that leaves the include_stack_ptr unchanged, and returns END_OF_INPUT once again.
			       * 
			       *       As a corollory, flex can never safely close the main input file, and we must ask
			       *       bison to close it!
			       */
			  if (parser->include_stack.size() == 0) {
			    yyterminate();
			  } else {
			    //fclose(yyin);
			    //FreeTracking(current_tracking);
			    //--include_stack_ptr;
			    //yy_delete_buffer(YY_CURRENT_BUFFER, yyscanner);
			    //yy_switch_to_buffer((include_stack[include_stack_ptr]).buffer_state, yyscanner);
			    //current_tracking = include_stack[include_stack_ptr].env;
			    //yy_push_state(include_end, yyscanner);
			  }
			}

<include_end>{file_include_pragma_end}	yy_pop_state(yyscanner);
	/* handle the artificial file includes created by include_string(), which do not end with a '}' */
<include_end>.				unput_text(0, yyscanner, parser); yy_pop_state(yyscanner); 


	/*********************************/
	/* Handle all the state changes! */
	/*********************************/

	/* INITIAL -> header_state */
<INITIAL>{
FUNCTION{st_whitespace} 		if (parser->get_preparse_state()) BEGIN(get_pou_name_state); else {BEGIN(header_state);/* printf("\nChanging to header_state\n"); */} return FUNCTION;
FUNCTION_BLOCK{st_whitespace}		if (parser->get_preparse_state()) BEGIN(get_pou_name_state); else {BEGIN(header_state);/* printf("\nChanging to header_state\n"); */} return FUNCTION_BLOCK;
PROGRAM{st_whitespace}			if (parser->get_preparse_state()) BEGIN(get_pou_name_state); else {BEGIN(header_state);/* printf("\nChanging to header_state\n"); */} return PROGRAM;
CONFIGURATION{st_whitespace}		if (parser->get_preparse_state()) BEGIN(get_pou_name_state); else {BEGIN(config_state);/* printf("\nChanging to config_state\n"); */} return CONFIGURATION;
}

<get_pou_name_state>{
{identifier}			BEGIN(ignore_pou_state); yylval->ID=creat_strcopy(yytext); return identifier_token;
.				BEGIN(ignore_pou_state); unput_text(0, yyscanner, parser);
}

<ignore_pou_state>{
END_FUNCTION			unput_text(0, yyscanner, parser); BEGIN(INITIAL);
END_FUNCTION_BLOCK		unput_text(0, yyscanner, parser); BEGIN(INITIAL);
END_PROGRAM			unput_text(0, yyscanner, parser); BEGIN(INITIAL);
END_CONFIGURATION		unput_text(0, yyscanner, parser); BEGIN(INITIAL);
.|\n				{}/* Ignore text inside POU! (including the '\n' character!)) */
}


	/* header_state -> (vardecl_list_state) */
	/* NOTE: This transition assumes that all POUs with code (Function, FB, and Program) will always contain
	 *       at least one VAR_XXX block.
	 *      How about functions that do not declare variables, and go directly to the body_state???
	 *      - According to Section 2.5.1.3 (Function Declaration), item 2 in the list, a FUNCTION
	 *        must have at least one input argument, so a correct declaration will have at least
	 *        one VAR_INPUT ... VAR_END construct!
	 *      - According to Section 2.5.2.2 (Function Block Declaration), a FUNCTION_BLOCK
	 *        must have at least one input argument, so a correct declaration will have at least
	 *        one VAR_INPUT ... VAR_END construct!
	 *      - According to Section 2.5.3 (Programs), a PROGRAM must have at least one input
	 *        argument, so a correct declaration will have at least one VAR_INPUT ... VAR_END
	 *        construct!
	 *
	 *       All the above means that we needn't worry about PROGRAMs, FUNCTIONs or
	 *       FUNCTION_BLOCKs that do not have at least one VAR_END before the body_state.
	 *       If the code has an error, and no VAR_END before the body, we will simply
	 *       continue in the <vardecl_state> state, until the end of the FUNCTION, FUNCTION_BLOCK
	 *       or PROGAM.
	 * 
	 * WARNING: From 2016-05 (May 2016) onwards, matiec supports a non-standard option in which a Function
	 *          may be declared with no Input, Output or IN_OUT variables. This means that the above 
	 *          assumption is no longer valid.
	 * 
	 * NOTE: Some code being parsed may be erroneous and not contain any VAR END_VAR block.
	 *       To generate error messages that make sense, the flex state machine should not get lost
	 *       in these situations. We therefore consider the possibility of finding 
	 *       END_FUNCTION, END_FUNCTION_BLOCK or END_PROGRAM when inside the header_state.
	 */
<header_state>{
VAR				| /* execute the next rule's action, i.e. fall-through! */
VAR_INPUT			|
VAR_OUTPUT			|
VAR_IN_OUT			|
VAR_EXTERNAL			|
VAR_GLOBAL			|
VAR_TEMP			|
VAR_CONFIG			|
VAR_ACCESS			unput_text(0, yyscanner, parser); BEGIN(vardecl_list_state);

END_FUNCTION			| /* execute the next rule's action, i.e. fall-through! */
END_FUNCTION_BLOCK		| 
END_PROGRAM			unput_text(0, yyscanner, parser); BEGIN(vardecl_list_state); 
				/* Notice that we do NOT go directly to body_state, as that requires a push().
				 * If we were to puch to body_state here, then the corresponding pop() at the
				 *end of body_state would return to header_state.
				 * After this pop() header_state would not return to INITIAL as it should, but
				 * would instead enter an infitie loop push()ing again to body_state
				 */
}


	/* vardecl_list_state -> (vardecl_state | body_state | INITIAL) */
<vardecl_list_state>{
VAR_INPUT			| /* execute the next rule's action, i.e. fall-through! */
VAR_OUTPUT			|
VAR_IN_OUT			|
VAR_EXTERNAL			|
VAR_GLOBAL			|
VAR_TEMP			|
VAR_CONFIG			|
VAR_ACCESS			|
VAR				unput_text(0, yyscanner, parser); yy_push_state(vardecl_state, yyscanner);

END_FUNCTION			unput_text(0, yyscanner, parser); BEGIN(INITIAL);
END_FUNCTION_BLOCK		unput_text(0, yyscanner, parser); BEGIN(INITIAL);
END_PROGRAM			unput_text(0, yyscanner, parser); BEGIN(INITIAL);

				/* NOTE: Handling of whitespace...
				 *   - Must come __before__ the next rule for any single character '.'
				 *   - If the rules were reversed, any whitespace with a single space (' ') 
				 *     would be handled by the '.' rule instead of the {whitespace} rule!
				 */
{st_whitespace}			/* Eat any whitespace */ 

				/* anything else, just change to body_state! */
.				unput_text(0, yyscanner, parser); yy_push_state(body_state, yyscanner); //printf("\nChanging to body_state\n");
}


	/* vardecl_list_state -> pop to $previous_state (vardecl_list_state) */
<vardecl_state>{
END_VAR				yy_pop_state(yyscanner); return END_VAR; /* pop back to vardecl_list_state */
}


	/* body_state -> (il_state | st_state | sfc_state) */
<body_state>{
{st_whitespace}			{/* In body state we do not process any tokens,
				  * we simply store them for later processing!
				  * NOTE: we must return ALL text when in body_state, including
				  * all comments and whitespace, so as not
				  * to lose track of the line_number and column number
				  * used when printing debugging messages.
				  * NOTE: some of the following rules depend on the fact that 
				  * the body state buffer is either empty or only contains white space up to
				  * that point. Since the vardecl_list_state will eat up all
				  * whitespace before entering the body_state, the contents of the bodystate_buffer
				  * will _never_ start with whitespace if the previous state was vardecl_list_state. 
				  * However, it is possible to enter the body_state from other states (e.g. when 
				  * parsing SFC code, that contains transitions or actions in other languages)
				  */
				 parser->append_bodystate_buffer(yytext, 1 /* is whitespace */); 
				}
	/* 'INITIAL_STEP' always used in beginning of SFCs !! */
INITIAL_STEP			{ if (parser->isempty_bodystate_buffer())	{unput_text(0, yyscanner, parser); BEGIN(sfc_state);}
				  else					{parser->append_bodystate_buffer(yytext);}
				}
 
	/* ':=', at the very beginning of a 'body', occurs only in transitions and not Function, FB, or Program bodies! */
:=				{ if (parser->isempty_bodystate_buffer())	{unput_text(0, yyscanner, parser); BEGIN(st_state);} /* We do _not_ return a start_ST_body_token here, as bison does not expect it! */
				  else				 	{parser->append_bodystate_buffer(yytext);}
				}
 
	/* check if ';' occurs before an END_FUNCTION, END_FUNCTION_BLOCK, END_PROGRAM, END_ACTION or END_TRANSITION. (If true => we are parsing ST; If false => parsing IL). */
END_ACTION			| /* execute the next rule's action, i.e. fall-through! */
END_FUNCTION			|
END_FUNCTION_BLOCK		|
END_TRANSITION   		|
END_PROGRAM			{ parser->append_bodystate_buffer(yytext); parser->unput_bodystate_buffer(yyscanner); BEGIN(il_state); /*printf("returning start_IL_body_token\n");*/ return start_IL_body_token;}
.|\n				{ parser->append_bodystate_buffer(yytext);
				  if (strcmp(yytext, ";") == 0)
				    {parser->unput_bodystate_buffer(yyscanner); BEGIN(st_state); /*printf("returning start_ST_body_token\n");*/ return start_ST_body_token;}
				}
	/* The following rules are not really necessary. They just make compilation faster in case the ST Statement List starts with one fot he following... */
RETURN				| /* execute the next rule's action, i.e. fall-through! */
IF				|
CASE				|
FOR				|
WHILE				|
EXIT				|
REPEAT				{ if (parser->isempty_bodystate_buffer())	{unput_text(0, yyscanner, parser); BEGIN(st_state); return start_ST_body_token;}
				  else				 	{parser->append_bodystate_buffer(yytext);}
				}

}	/* end of body_state lexical parser */


	/* (il_state | st_state) -> pop to $previous_state (vardecl_list_state or sfc_state) */
<il_state,st_state>{
END_FUNCTION		yy_pop_state(yyscanner); unput_text(0, yyscanner, parser);
END_FUNCTION_BLOCK	yy_pop_state(yyscanner); unput_text(0, yyscanner, parser);
END_PROGRAM		yy_pop_state(yyscanner); unput_text(0, yyscanner, parser);
END_TRANSITION		yy_pop_state(yyscanner); unput_text(0, yyscanner, parser);
END_ACTION		yy_pop_state(yyscanner); unput_text(0, yyscanner, parser);
}

	/* sfc_state -> pop to $previous_state (vardecl_list_state or sfc_state) */
<sfc_state>{
END_FUNCTION		yy_pop_state(yyscanner); unput_text(0, yyscanner, parser);
END_FUNCTION_BLOCK	yy_pop_state(yyscanner); unput_text(0, yyscanner, parser);
END_PROGRAM		yy_pop_state(yyscanner); unput_text(0, yyscanner, parser);
}

	/* config -> INITIAL */
END_CONFIGURATION	BEGIN(INITIAL); return END_CONFIGURATION;



	/***************************************/
	/* Next is to to remove all whitespace */
	/***************************************/
	/* NOTE: pragmas are handled right at the beginning... */

	/* The whitespace */
<INITIAL,header_state,config_state,vardecl_state,st_state,sfc_state,task_init_state,sfc_qualifier_state>{st_whitespace}	/* Eat any whitespace */
<il_state>{il_whitespace}		/* Eat any whitespace */
 /* NOTE: Due to the need of having the following rule have higher priority,
  *        the following rule was moved to an earlier position in this file.
<body_state>{st_whitespace}		{...}
 */

	/* The comments */
<get_pou_name_state,ignore_pou_state,body_state,vardecl_list_state>{comment_beg}		yy_push_state(comment_state, yyscanner);
{comment_beg}						yy_push_state(comment_state, yyscanner);
<comment_state>{
{comment_beg}						{if (parser->get_opt_nested_comments()) yy_push_state(comment_state, yyscanner);}
{comment_end}						yy_pop_state(yyscanner);
.							/* Ignore text inside comment! */
\n							/* Ignore text inside comment! */
}

	/*****************************************/
	/* B.1.1 Letters, digits and identifiers */
	/*****************************************/
	/* NOTE: 'R1', 'IN', etc... are IL operators, and therefore tokens
	 *       On the other hand, the spec does not define them as keywords,
	 *       which means they may be re-used for variable names, etc...!
	 *       The syntax parser already caters for the possibility of these
	 *       tokens being used for variable names in their declarations.
	 *       When they are declared, they will be added to the variable symbol table!
	 *       Further appearances of these tokens must no longer be parsed
	 *       as R1_tokens etc..., but rather as variable_name_tokens!
	 *
	 *       That is why the first thing we do with identifiers, even before
	 *       checking whether they may be a 'keyword', is to check whether
	 *       they have been previously declared as a variable name,
	 *
	 *       However, we have a dilema! Should we here also check for
	 *       prev_declared_derived_function_name_token?
	 *       If we do, then the 'MOD' default library function (defined in
	 *       the standard) will always be returned as a function name, and
	 *       it will therefore not be possible to use it as an operator as 
	 *       in the following ST expression 'X := Y MOD Z;' !
	 *       If we don't, then even it will not be possible to use 'MOD'
	 *       as a funtion as in 'X := MOD(Y, Z);'
	 *       We solve this by NOT testing for function names here, and
	 *       handling this function and keyword clash in bison!
	 */
	/* NOTE: The following code has been commented out as most users do not want matiec
	 *       to allow the use of 'R1', 'IN' ... IL operators as identifiers, 
	 *       even though a literal reading of the standard allows this.
	 *       We could add this as a commadnd line option, but it is not yet done.
	 *       For now we just comment out the code, but leave it the commented code
	 *       in so we can re-activate quickly (without having to go through old commits
	 *       in the mercurial repository to figure out the missing code!
	 */
 /*
{identifier} 	{int token = parser->get_identifier_token(yytext);
		 // fprintf(stderr, "flex: analysing identifier '%s'...", yytext); 
		 if ((token == prev_declared_variable_name_token) ||
//		     (token == prev_declared_derived_function_name_token) || // DO NOT add this condition!
		     (token == prev_declared_fb_name_token)) {
		 // if (token != identifier_token)
		 // * NOTE: if we replace the above uncommented conditions with
                  *       the simple test of (token != identifier_token), then 
                  *       'MOD' et al must be removed from the 
                  *       library_symbol_table as a default function name!
		  * //
		   yylval->ID=creat_strcopy(yytext);
		   // fprintf(stderr, "returning token %d\n", token); 
		   return token;
		 }
		 // otherwise, leave it for the other lexical parser rules... 
		 // fprintf(stderr, "rejecting\n"); 
		 REJECT;
		}
 */

	/******************************************************/
	/******************************************************/
	/******************************************************/
	/*****                                            *****/
	/*****                                            *****/
	/*****   N O W    D O   T H E   K E Y W O R D S   *****/
	/*****                                            *****/
	/*****                                            *****/
	/******************************************************/
	/******************************************************/
	/******************************************************/


REF	{if (parser->get_opt_ref_standard_extensions()) return REF;        else{REJECT;}}		/* Keyword in IEC 61131-3 v3 */
DREF	{if (parser->get_opt_ref_standard_extensions()) return DREF;       else{REJECT;}}		/* Keyword in IEC 61131-3 v3 */
REF_TO	{if (parser->get_opt_ref_standard_extensions()) return REF_TO;     else{REJECT;}}		/* Keyword in IEC 61131-3 v3 */
NULL	{if (parser->get_opt_ref_standard_extensions()) return NULL_token; else{REJECT;}}		/* Keyword in IEC 61131-3 v3 */

EN	return EN;			/* Keyword */
ENO	return ENO;			/* Keyword */


	/******************************/
	/* B 1.2.1 - Numeric Literals */
	/******************************/
TRUE		return TRUE;		/* Keyword */
BOOL#1  	return boolean_true_literal_token;
BOOL#TRUE	return boolean_true_literal_token;
SAFEBOOL#1	{if (parser->get_opt_safe_extensions()) {return safeboolean_true_literal_token;} else{REJECT;}} /* Keyword (Data Type) */ 
SAFEBOOL#TRUE	{if (parser->get_opt_safe_extensions()) {return safeboolean_true_literal_token;} else{REJECT;}} /* Keyword (Data Type) */

FALSE		return FALSE;		/* Keyword */
BOOL#0  	return boolean_false_literal_token;
BOOL#FALSE  	return boolean_false_literal_token;
SAFEBOOL#0	{if (parser->get_opt_safe_extensions()) {return safeboolean_false_literal_token;} else{REJECT;}} /* Keyword (Data Type) */ 
SAFEBOOL#FALSE	{if (parser->get_opt_safe_extensions()) {return safeboolean_false_literal_token;} else{REJECT;}} /* Keyword (Data Type) */


	/************************/
	/* B 1.2.3.1 - Duration */
	/************************/
t#		return T_SHARP;		/* Delimiter */
T#		return T_SHARP;		/* Delimiter */
TIME		return TIME;		/* Keyword (Data Type) */


	/************************************/
	/* B 1.2.3.2 - Time of day and Date */
	/************************************/
TIME_OF_DAY	return TIME_OF_DAY;	/* Keyword (Data Type) */
TOD		return TIME_OF_DAY;	/* Keyword (Data Type) */
DATE		return DATE;		/* Keyword (Data Type) */
d#		return D_SHARP;		/* Delimiter */
D#		return D_SHARP;		/* Delimiter */
DATE_AND_TIME	return DATE_AND_TIME;	/* Keyword (Data Type) */
DT		return DATE_AND_TIME;	/* Keyword (Data Type) */


	/***********************************/
	/* B 1.3.1 - Elementary Data Types */
	/***********************************/
BOOL		return BOOL;		/* Keyword (Data Type) */

BYTE		return BYTE;		/* Keyword (Data Type) */
WORD		return WORD;		/* Keyword (Data Type) */
DWORD		return DWORD;		/* Keyword (Data Type) */
LWORD		return LWORD;		/* Keyword (Data Type) */

SINT		return SINT;		/* Keyword (Data Type) */
INT		return INT;		/* Keyword (Data Type) */
DINT		return DINT;		/* Keyword (Data Type) */
LINT		return LINT;		/* Keyword (Data Type) */

USINT		return USINT;		/* Keyword (Data Type) */
UINT		return UINT;		/* Keyword (Data Type) */
UDINT		return UDINT;		/* Keyword (Data Type) */
ULINT		return ULINT;		/* Keyword (Data Type) */

REAL		return REAL;		/* Keyword (Data Type) */
LREAL		return LREAL;		/* Keyword (Data Type) */

WSTRING		return WSTRING;		/* Keyword (Data Type) */
STRING		return STRING;		/* Keyword (Data Type) */

TIME		return TIME;		/* Keyword (Data Type) */
DATE		return DATE;		/* Keyword (Data Type) */
DT		return DT;		/* Keyword (Data Type) */
TOD		return TOD;		/* Keyword (Data Type) */
DATE_AND_TIME	return DATE_AND_TIME;	/* Keyword (Data Type) */
TIME_OF_DAY	return TIME_OF_DAY;	/* Keyword (Data Type) */

					/* A non-standard extension! */
VOID		{if (parser->runtime_options.allow_void_datatype) {return VOID;}          else {REJECT;}} 


	/*****************************************************************/
	/* Keywords defined in "Safety Software Technical Specification" */
	/*****************************************************************/
        /* 
         * NOTE: The following keywords are define in 
         *       "Safety Software Technical Specification,
         *        Part 1: Concepts and Function Blocks,  
         *        Version 1.0 – Official Release"
         *        written by PLCopen - Technical Committee 5
         *
         *        We only support these extensions and keywords
         *        if the apropriate command line option is given.
         */
SAFEBOOL	     {if (parser->get_opt_safe_extensions()) {return SAFEBOOL;}          else {REJECT;}} 

SAFEBYTE	     {if (parser->get_opt_safe_extensions()) {return SAFEBYTE;}          else {REJECT;}} 
SAFEWORD	     {if (parser->get_opt_safe_extensions()) {return SAFEWORD;}          else {REJECT;}} 
SAFEDWORD	     {if (parser->get_opt_safe_extensions()) {return SAFEDWORD;}         else{REJECT;}}
SAFELWORD	     {if (parser->get_opt_safe_extensions()) {return SAFELWORD;}         else{REJECT;}}
               
SAFEREAL	     {if (parser->get_opt_safe_extensions()) {return SAFESINT;}          else{REJECT;}}
SAFELREAL    	     {if (parser->get_opt_safe_extensions()) {return SAFELREAL;}         else{REJECT;}}
                  
SAFESINT	     {if (parser->get_opt_safe_extensions()) {return SAFESINT;}          else{REJECT;}}
SAFEINT	             {if (parser->get_opt_safe_extensions()) {return SAFEINT;}           else{REJECT;}}
SAFEDINT	     {if (parser->get_opt_safe_extensions()) {return SAFEDINT;}          else{REJECT;}}
SAFELINT             {if (parser->get_opt_safe_extensions()) {return SAFELINT;}          else{REJECT;}}

SAFEUSINT            {if (parser->get_opt_safe_extensions()) {return SAFEUSINT;}         else{REJECT;}}
SAFEUINT             {if (parser->get_opt_safe_extensions()) {return SAFEUINT;}          else{REJECT;}}
SAFEUDINT            {if (parser->get_opt_safe_extensions()) {return SAFEUDINT;}         else{REJECT;}}
SAFEULINT            {if (parser->get_opt_safe_extensions()) {return SAFEULINT;}         else{REJECT;}}

 /* SAFESTRING and SAFEWSTRING are not yet supported, i.e. checked correctly, in the semantic analyser (stage 3) */
 /*  so it is best not to support them at all... */
 /*
SAFEWSTRING          {if (parser->get_opt_safe_extensions()) {return SAFEWSTRING;}       else{REJECT;}}
SAFESTRING           {if (parser->get_opt_safe_extensions()) {return SAFESTRING;}        else{REJECT;}}
 */

SAFETIME             {if (parser->get_opt_safe_extensions()) {return SAFETIME;}          else{REJECT;}}
SAFEDATE             {if (parser->get_opt_safe_extensions()) {return SAFEDATE;}          else{REJECT;}}
SAFEDT               {if (parser->get_opt_safe_extensions()) {return SAFEDT;}            else{REJECT;}}
SAFETOD              {if (parser->get_opt_safe_extensions()) {return SAFETOD;}           else{REJECT;}}
SAFEDATE_AND_TIME    {if (parser->get_opt_safe_extensions()) {return SAFEDATE_AND_TIME;} else{REJECT;}}
SAFETIME_OF_DAY      {if (parser->get_opt_safe_extensions()) {return SAFETIME_OF_DAY;}   else{REJECT;}}

	/********************************/
	/* B 1.3.2 - Generic data types */
	/********************************/
	/* Strangely, the following symbols do not seem to be required! */
	/* But we include them so they become reserved words, and do not
	 * get passed up to bison as an identifier...
	 */
ANY		return ANY;		/* Keyword (Data Type) */
ANY_DERIVED	return ANY_DERIVED;	/* Keyword (Data Type) */
ANY_ELEMENTARY	return ANY_ELEMENTARY;	/* Keyword (Data Type) */
ANY_MAGNITUDE	return ANY_MAGNITUDE;	/* Keyword (Data Type) */
ANY_NUM		return ANY_NUM;		/* Keyword (Data Type) */
ANY_REAL	return ANY_REAL;	/* Keyword (Data Type) */
ANY_INT		return ANY_INT;		/* Keyword (Data Type) */
ANY_BIT		return ANY_BIT;		/* Keyword (Data Type) */
ANY_STRING	return ANY_STRING;	/* Keyword (Data Type) */
ANY_DATE	return ANY_DATE;	/* Keyword (Data Type) */


	/********************************/
	/* B 1.3.3 - Derived data types */
	/********************************/
":="		return ASSIGN;		/* Delimiter */
".."		return DOTDOT;		/* Delimiter */
TYPE		return TYPE;		/* Keyword */
END_TYPE	return END_TYPE;	/* Keyword */
ARRAY		return ARRAY;		/* Keyword */
OF		return OF;		/* Keyword */
STRUCT		return STRUCT;		/* Keyword */
END_STRUCT	return END_STRUCT;	/* Keyword */


	/*********************/
	/* B 1.4 - Variables */
	/*********************/

	/******************************************/
	/* B 1.4.3 - Declaration & Initialisation */
	/******************************************/
VAR_INPUT	return VAR_INPUT;	/* Keyword */
VAR_OUTPUT	return VAR_OUTPUT;	/* Keyword */
VAR_IN_OUT	return VAR_IN_OUT;	/* Keyword */
VAR_EXTERNAL	return VAR_EXTERNAL;	/* Keyword */
VAR_GLOBAL	return VAR_GLOBAL;	/* Keyword */
END_VAR		return END_VAR;		/* Keyword */
RETAIN		return RETAIN;		/* Keyword */
NON_RETAIN	return NON_RETAIN;	/* Keyword */
R_EDGE		return R_EDGE;		/* Keyword */
F_EDGE		return F_EDGE;		/* Keyword */
AT		return AT;		/* Keyword */


	/***********************/
	/* B 1.5.1 - Functions */
	/***********************/
	/* Note: The following END_FUNCTION rule includes a BEGIN(INITIAL); command.
	 *       This is necessary in case the input program being parsed has syntax errors that force
	 *       flex's main state machine to never change to the il_state or the st_state
	 *       after changing to the body_state.
	 *       Ths BEGIN(INITIAL) command forces the flex state machine to re-synchronise with 
	 *       the input stream even in the presence of buggy code!
	 */
FUNCTION			return FUNCTION;			/* Keyword */
END_FUNCTION	BEGIN(INITIAL);	return END_FUNCTION;			/* Keyword */  /* see Note above */
VAR				return VAR;				/* Keyword */
CONSTANT			return CONSTANT;			/* Keyword */


	/*****************************/
	/* B 1.5.2 - Function Blocks */
	/*****************************/
	/* Note: The following END_FUNCTION_BLOCK rule includes a BEGIN(INITIAL); command.
	 *       This is necessary in case the input program being parsed has syntax errors that force
	 *       flex's main state machine to never change to the il_state or the st_state
	 *       after changing to the body_state.
	 *       Ths BEGIN(INITIAL) command forces the flex state machine to re-synchronise with 
	 *       the input stream even in the presence of buggy code!
	 */
FUNCTION_BLOCK				return FUNCTION_BLOCK;		/* Keyword */
END_FUNCTION_BLOCK	BEGIN(INITIAL);	return END_FUNCTION_BLOCK;	/* Keyword */  /* see Note above */
VAR_TEMP				return VAR_TEMP;		/* Keyword */
VAR					return VAR;			/* Keyword */
NON_RETAIN				return NON_RETAIN;		/* Keyword */
END_VAR					return END_VAR;			/* Keyword */


	/**********************/
	/* B 1.5.3 - Programs */
	/**********************/
	/* Note: The following END_PROGRAM rule includes a BEGIN(INITIAL); command.
	 *       This is necessary in case the input program being parsed has syntax errors that force
	 *       flex's main state machine to never change to the il_state or the st_state
	 *       after changing to the body_state.
	 *       Ths BEGIN(INITIAL) command forces the flex state machine to re-synchronise with 
	 *       the input stream even in the presence of buggy code!
	 */
PROGRAM				return PROGRAM;				/* Keyword */
END_PROGRAM	BEGIN(INITIAL);	return END_PROGRAM;			/* Keyword */  /* see Note above */


	/********************************************/
	/* B 1.6 Sequential Function Chart elements */
	/********************************************/
	/* NOTE: the following identifiers/tokens clash with the R and S IL operators, as well
	.* as other identifiers that may be used as variable names inside IL and ST programs.
	 * They will have to be handled when we include parsing of SFC... For now, simply
	 * ignore them!
	 */
	 
ACTION		return ACTION;			/* Keyword */
END_ACTION	return END_ACTION;		/* Keyword */

TRANSITION	return TRANSITION;		/* Keyword */
END_TRANSITION	return END_TRANSITION;		/* Keyword */
FROM		return FROM;			/* Keyword */
TO		return TO;			/* Keyword */

INITIAL_STEP	return INITIAL_STEP;		/* Keyword */
STEP		return STEP;			/* Keyword */
END_STEP	return END_STEP;		/* Keyword */

	/* PRIORITY is not a keyword, so we only return it when 
	 * it is explicitly required and we are not expecting any identifiers
	 * that could also use the same letter sequence (i.e. an identifier: piority)
	 */
<sfc_priority_state>PRIORITY	return PRIORITY;

<sfc_qualifier_state>{
L		return L;
D		return D;
SD		return SD;
DS		return DS;
SL		return SL;
N		return N;
P		return P;
P0		return P0;
P1		return P1;
R		return R;
S		return S;
}


	/********************************/
	/* B 1.7 Configuration elements */
	/********************************/
	/* Note: The following END_CONFIGURATION rule will never get to be used, as we have
	 *       another identical rule above (closer to the rules handling the transitions
	 *       of the main state machine) that will always execute before this one.
	 * Note: The following END_CONFIGURATION rule includes a BEGIN(INITIAL); command.
	 *       This is nt strictly necessary, but I place it here so it follwos the same
	 *       pattern used in END_FUNCTION, END_PROGRAM, and END_FUNCTION_BLOCK
	 */
CONFIGURATION				return CONFIGURATION;		/* Keyword */
END_CONFIGURATION	BEGIN(INITIAL); return END_CONFIGURATION;	/* Keyword */   /* see 2 Notes above! */
TASK					return TASK;			/* Keyword */
RESOURCE				return RESOURCE;		/* Keyword */
ON					return ON;			/* Keyword */
END_RESOURCE				return END_RESOURCE;		/* Keyword */
VAR_CONFIG				return VAR_CONFIG;		/* Keyword */
VAR_ACCESS				return VAR_ACCESS;		/* Keyword */
END_VAR					return END_VAR;			/* Keyword */
WITH					return WITH;			/* Keyword */
PROGRAM					return PROGRAM;			/* Keyword */
RETAIN					return RETAIN;			/* Keyword */
NON_RETAIN				return NON_RETAIN;		/* Keyword */
READ_WRITE				return READ_WRITE;		/* Keyword */
READ_ONLY				return READ_ONLY;		/* Keyword */

	/* PRIORITY, SINGLE and INTERVAL are not a keywords, so we only return them when 
	 * it is explicitly required and we are not expecting any identifiers
	 * that could also use the same letter sequence (i.e. an identifier: piority, ...)
	 */
<task_init_state>{
PRIORITY		return PRIORITY;
SINGLE			return SINGLE;
INTERVAL		return INTERVAL;
}

	/***********************************/
	/* B 2.1 Instructions and Operands */
	/***********************************/
<il_state>\n		return EOL;


	/*******************/
	/* B 2.2 Operators */
	/*******************/
	/* NOTE: we can't have flex return the same token for
	 *       ANDN and &N, neither for AND and &, since
	 *       AND and ANDN are considered valid variable
	 *       function or functionblock type names!
	 *       This means that the parser may decide that the
	 *       AND or ANDN strings found in the source code
	 *       are being used as variable names
	 *       and not as operators, and will therefore transform
	 *       these tokens into indentifier tokens!
	 *       We can't have the parser thinking that the source
	 *       code contained the string AND (which may be interpreted
	 *       as a vairable name) when in reality the source code
	 *       merely contained the character &, so we use two
	 *       different tokens for & and AND (and similarly
	 *       ANDN and &N)!
	 */
 /* The following tokens clash with ST expression operators and Standard Functions */
 /* They are also keywords! */
AND		return AND;		/* Keyword */
MOD		return MOD;		/* Keyword */
OR		return OR;		/* Keyword */
XOR		return XOR;		/* Keyword */
NOT		return NOT;		/* Keyword */

 /* The following tokens clash with Standard Functions */
 /* They are keywords because they are a function name */
<il_state>{
ADD		return ADD;		/* Keyword (Standard Function) */
DIV		return DIV;		/* Keyword (Standard Function) */
EQ		return EQ;		/* Keyword (Standard Function) */
GE		return GE;		/* Keyword (Standard Function) */
GT		return GT;		/* Keyword (Standard Function) */
LE		return LE;		/* Keyword (Standard Function) */
LT		return LT;		/* Keyword (Standard Function) */
MUL		return MUL;		/* Keyword (Standard Function) */
NE		return NE;		/* Keyword (Standard Function) */
SUB		return SUB;		/* Keyword (Standard Function) */
}

 /* The following tokens clash with SFC action qualifiers */
 /* They are not keywords! */
<il_state>{
S		return S;
R		return R;
}

 /* The following tokens clash with ST expression operators */
&		return AND2;		/* NOT a Delimiter! */

 /* The following tokens have no clashes */
 /* They are not keywords! */
<il_state>{
LD		return LD;
LDN		return LDN;
ST		return ST;
STN		return STN;
S1		return S1;
R1		return R1;
CLK		return CLK;
CU		return CU;
CD		return CD;
PV		return PV;
IN		return IN;
PT		return PT;
ANDN		return ANDN;
&N		return ANDN2;
ORN		return ORN;
XORN		return XORN;
CAL		return CAL;
CALC		return CALC;
CALCN		return CALCN;
RET		return RET;
RETC		return RETC;
RETCN		return RETCN;
JMP		return JMP;
JMPC		return JMPC;
JMPCN		return JMPCN;
}

	/***********************/
	/* B 3.1 - Expressions */
	/***********************/
"**"		return OPER_EXP;	/* NOT a Delimiter! */
"<>"		return OPER_NE;		/* NOT a Delimiter! */
">="		return OPER_GE;		/* NOT a Delimiter! */
"<="		return OPER_LE;		/* NOT a Delimiter! */
&		return AND2;		/* NOT a Delimiter! */
AND		return AND;		/* Keyword */
XOR		return XOR;		/* Keyword */
OR		return OR;		/* Keyword */
NOT		return NOT;		/* Keyword */
MOD		return MOD;		/* Keyword */


	/*****************************************/
	/* B 3.2.2 Subprogram Control Statements */
	/*****************************************/
:=		return ASSIGN;		/* Delimiter */
=>		return SENDTO;		/* Delimiter */
RETURN		return RETURN;		/* Keyword */


	/********************************/
	/* B 3.2.3 Selection Statements */
	/********************************/
IF		return IF;		/* Keyword */
THEN		return THEN;		/* Keyword */
ELSIF		return ELSIF;		/* Keyword */
ELSE		return ELSE;		/* Keyword */
END_IF		return END_IF;		/* Keyword */

CASE		return CASE;		/* Keyword */
OF		return OF;		/* Keyword */
ELSE		return ELSE;		/* Keyword */
END_CASE	return END_CASE;	/* Keyword */


	/********************************/
	/* B 3.2.4 Iteration Statements */
	/********************************/
FOR		return FOR;		/* Keyword */
TO		return TO;		/* Keyword */
BY		return BY;		/* Keyword */
DO		return DO;		/* Keyword */
END_FOR		return END_FOR;		/* Keyword */

WHILE		return WHILE;		/* Keyword */
DO		return DO;		/* Keyword */
END_WHILE	return END_WHILE;	/* Keyword */

REPEAT		return REPEAT;		/* Keyword */
UNTIL		return UNTIL;		/* Keyword */
END_REPEAT	return END_REPEAT;	/* Keyword */

EXIT		return EXIT;		/* Keyword */






	/********************************************************/
	/********************************************************/
	/********************************************************/
	/*****                                              *****/
	/*****                                              *****/
	/*****  N O W    W O R K    W I T H    V A L U E S  *****/
	/*****                                              *****/
	/*****                                              *****/
	/********************************************************/
	/********************************************************/
	/********************************************************/


	/********************************************/
	/* B.1.4.1   Directly Represented Variables */
	/********************************************/
{direct_variable}   {yylval->ID=creat_strcopy(yytext); return parser->get_direct_variable_token(yytext);}


	/******************************************/
	/* B 1.4.3 - Declaration & Initialisation */
	/******************************************/
{incompl_location}	{yylval->ID=creat_strcopy(yytext); return incompl_location_token;}


	/************************/
	/* B 1.2.3.1 - Duration */
	/************************/
{fixed_point}		{yylval->ID=creat_strcopy(yytext); return fixed_point_token;}
{interval}		{/*fprintf(stderr, "entering time_literal_state ##%s##\n", yytext);*/ unput_and_mark('#', yyscanner, parser); yy_push_state(time_literal_state, yyscanner);}
{erroneous_interval}	{return erroneous_interval_token;}

<time_literal_state>{
{integer}d		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-1] = '\0'; return integer_d_token;}
{integer}h		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-1] = '\0'; return integer_h_token;}
{integer}m		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-1] = '\0'; return integer_m_token;}
{integer}s		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-1] = '\0'; return integer_s_token;}
{integer}ms		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-2] = '\0'; return integer_ms_token;}
{fixed_point}d		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-1] = '\0'; return fixed_point_d_token;}
{fixed_point}h		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-1] = '\0'; return fixed_point_h_token;}
{fixed_point}m		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-1] = '\0'; return fixed_point_m_token;}
{fixed_point}s		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-1] = '\0'; return fixed_point_s_token;}
{fixed_point}ms		{yylval->ID=creat_strcopy(yytext); yylval->ID[yyleng-2] = '\0'; return fixed_point_ms_token;}

_			/* do nothing - eat it up!*/
\#			{/*fprintf(stderr, "popping from time_literal_state (###)\n");*/ yy_pop_state(yyscanner); return end_interval_token;}
.			{/*fprintf(stderr, "time_literal_state: found invalid character '%s'. Aborting!\n", yytext);*/ ERROR;}
\n			{ERROR;}
}
	/*******************************/
	/* B.1.2.2   Character Strings */
	/*******************************/
{double_byte_character_string} {yylval->ID=creat_strcopy(yytext); return double_byte_character_string_token;}
{single_byte_character_string} {yylval->ID=creat_strcopy(yytext); return single_byte_character_string_token;}


	/******************************/
	/* B.1.2.1   Numeric literals */
	/******************************/
{integer}		{yylval->ID=creat_strcopy(yytext); return integer_token;}
{real}			{yylval->ID=creat_strcopy(yytext); return real_token;}
{binary_integer}	{yylval->ID=creat_strcopy(yytext); return binary_integer_token;}
{octal_integer} 	{yylval->ID=creat_strcopy(yytext); return octal_integer_token;}
{hex_integer} 		{yylval->ID=creat_strcopy(yytext); return hex_integer_token;}


	/*****************************************/
	/* B.1.1 Letters, digits and identifiers */
	/*****************************************/
<st_state>{identifier}/({st_whitespace_or_pragma_or_comment})"=>"	{yylval->ID=creat_strcopy(yytext); return sendto_identifier_token;}
<il_state>{identifier}/({il_whitespace_or_pragma_or_comment})"=>"	{yylval->ID=creat_strcopy(yytext); return sendto_identifier_token;}
{identifier} 				{yylval->ID=creat_strcopy(yytext);
					 // printf("returning identifier...: %s, %d\n", yytext, parser->get_identifier_token(yytext));
					 return parser->get_identifier_token(yytext);}






	/************************************************/
	/************************************************/
	/************************************************/
	/*****                                      *****/
	/*****                                      *****/
	/*****   T H E    L E F T O V E R S . . .   *****/
	/*****                                      *****/
	/*****                                      *****/
	/************************************************/
	/************************************************/
	/************************************************/

	/* do the single character tokens...
	 *
	 *  e.g.:  ':'  '('  ')'  '+'  '*'  ...
	 */
.	{return yytext[0];}

%%

/* return the specified character to the input stream */
/* WARNING: this function destroys the contents of yytext */
void unput_char(const char c, yyscan_t yyscanner) {
    struct yyguts_t* yyg = (struct yyguts_t*)yyscanner;
    unput(c);
}

/* return all the text in the current token back to the input stream, except the first n chars. */
void unput_text(int n, yyscan_t scanner, parser_t* parser) {
    struct yyguts_t* yyg = (struct yyguts_t*)scanner;
    if (n < 0)
        ERROR;
    signed int i;  // must be signed! The iterartion may end with -1 when this function is called with n=0 !!

    char* yycopy = creat_strcopy(yytext); /* unput_char() destroys yytext, so we copy it first */
    for (int i = yyleng - 1; i >= n; i--)
        unput_char(yycopy[i], scanner);

    yycopy[n] = '\0';
    if (parser)
        parser->restore_tracking();
    parser->UpdateTracking(yycopy);

    free(yycopy);
}

/* return all the text in the current token back to the input stream,
 * but first return to the stream an additional character to mark the end of the token.
 */
void unput_and_mark(const char mark_char, yyscan_t scanner, parser_t* parser) {
    struct yyguts_t* yyg = (struct yyguts_t*)scanner;
    char* yycopy = creat_strcopy(yytext); /* unput_char() destroys yytext, so we copy it first */
    unput_char(mark_char, scanner);
    for (int i = yyleng - 1; i >= 0; i--)
        unput_char(yycopy[i], scanner);

    free(yycopy);
    parser->restore_tracking();
}
