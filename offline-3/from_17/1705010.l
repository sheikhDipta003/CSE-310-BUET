%option noyywrap

%x COMMENT_ML

%{
int newlines_in_cmnt = 0;
char* cmntStart;
#include<bits/stdc++.h>
#include <fstream>
#include <string>
#include "SymbolTable.h"
#include "SymbolInfo.h"
#include "ScopeTable.h"
#include "Helper.h"
#include "y.tab.h"

extern YYSTYPE yylval;
extern SymbolTable *sym_tab;
void yyerror(char *);

extern FILE *logout;
extern FILE *errout;
extern int err_count;
int line_count = 1;

void add_punc_op(string token) {
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", line_count, token.data(), yytext);

	if(token == "LCURL")	sym_tab->enter_scope();
	else if(token == "RCURL")	sym_tab->exit_scope();
}

void addConstInt() {
	string token = "CONST_INT";
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", line_count, token.data(), yytext);
}

void addConstFloat() {
	string token = "CONST_FLOAT";
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", line_count, token.data(), yytext);
}

void installID() {
	string token = "ID";
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", line_count, token.data(), yytext);
}

void replace_help(string &str, string const &prev, string const &_new) {
	size_t pos = 0;
    while (pos += _new.length())
    {
        pos = str.find(prev, pos);
        if (pos == std::string::npos) {
            break;
        }
 
        str.erase(pos, prev.length());
        str.insert(pos, _new);
    }
}

string replace(const char* str) {
	string replaced = str;

	replace_help(replaced, "\\n", "\n");
	replace_help(replaced, "\\t", "\t");
	replace_help(replaced, "\\a", "\a");
	replace_help(replaced, "\\b", "\b");
	replace_help(replaced, "\\r", "\r");
	replace_help(replaced, "\\f", "\f");
	replace_help(replaced, "\\v", "\v");
	replace_help(replaced, "\\\'", "\'");
	replace_help(replaced, "\\\"", "\"");
	replace_help(replaced, "\\0", "\0");

	return replaced;
}

void addConstChar() {
	string token = "CONST_CHAR";

	//replace with ascii representations
	string const_char = replace(yytext);

	//remove enclosing quotations
	const_char = "" + const_char.substr(1);
	const_char = const_char.substr(0, const_char.size() - 1) + "";

	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", line_count, token.data(), const_char.data());
}

void addString() {
	//replace with ascii representations
	string const_str = replace(yytext);

	//remove enclosing quotations
	const_str = "" + const_str.substr(1);
	const_str = const_str.substr(0, const_str.size() - 1) + "";
	int num_newline_char = std::count(const_str.begin(), const_str.end(), '\n');

	string token;
	if(num_newline_char == 0)	token = "SINGLE LINE STRING";
	else	token = "MULTI LINE STRING";

	const_str.erase(std::remove(const_str.begin(), const_str.end(), '\\'), const_str.end()); 	//remove backslash
	const_str.erase(std::remove(const_str.begin(), const_str.end(), '\n'), const_str.end()); 	//remove newline
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", line_count, token.data(), yytext);

	line_count += num_newline_char;
}

void ignoreComment(){
	string string_literal = replace(yytext);
	fprintf(logout, "Line# %d: Token <SINGLE LINE COMMENT> Lexeme %s found\n", line_count, yytext);
	line_count += std::count(string_literal.begin(), string_literal.end(), '\n');
}

void showError(string msg) {
	string string_literal = replace(yytext);
	int err_line_count = std::count(string_literal.begin(), string_literal.end(), '\n');

	fprintf(errout, "Error at line# %d: %s %s\n", line_count + err_line_count, msg.data(), yytext);

	err_count++;
	line_count += err_line_count;
}

void showCommentError(string msg, string unf_cmnt){
	string string_literal = replace(unf_cmnt.data());
	int err_line_count = std::count(string_literal.begin(), string_literal.end(), '\n');

	fprintf(errout, "Error at line# %d: %s %s\n", line_count + err_line_count, msg.data(), unf_cmnt.data());
	
	err_count++;
	line_count += err_line_count;
}

%}


WHITESPACE 		[ \t\f\r\v]+
LETTER 			[a-zA-Z]
DIGIT 			[0-9]
DIGITS 			{DIGIT}+
NEWLINE 		\n
NOT_NEWLINE 	[^\n]
SLASH 			[\\]
SLASH_IN_QUOTES (\'\\\')

ID_START 		({LETTER}|_)
ID 				{ID_START}({LETTER}|{DIGIT}|_)*
INVALID_ID 		{DIGIT}({LETTER}|{DIGIT})*

CHAR 			\'{NOT_NEWLINE}\'
ESC 			((\'\\n\')|(\'\\t\')|(\'\\a\')|(\'\\b\')|(\'\\r\')|(\'\\f\')|(\'\\v\')|(\'\\\'\')|(\'\\\"\')|(\'\\\\')|(\'\\0\'))
INVALID_CHAR 	(\'{NOT_NEWLINE}{NOT_NEWLINE}+\')
UNF_CHAR 		\'{CHAR}*[^'\n]?
EMP_CHAR		\'\'

UNF_STR 		\"([^'"\\\n]|(\\)({NOT_NEWLINE}|{NEWLINE}))*
STR 			{UNF_STR}\"

DEC_POINT 		(\.)*
FLOAT 			({DIGITS})?(\.?{DIGITS})(E[+-]?{DIGITS})?
TOO_MANY_POINTS {DIGIT}*((\.)+{DIGITS})+(E{DEC_POINT}[+-]?{DEC_POINT}{DIGITS})?
ILL_FORMED_NUM 	({DIGITS}|{FLOAT})[E]*{FLOAT}*

CMNT_SL 		"//"({NOT_NEWLINE}*({SLASH}{NEWLINE}))*{NOT_NEWLINE}*

%%

{WHITESPACE} {}

{NEWLINE} {line_count++;}

"if" {return IF;}
"else" {return ELSE;}
"for" {return FOR;}
"while" {return WHILE;}
"do" {return DO;}
"break" {return BREAK;}
"int" { SymbolInfo *s= new  SymbolInfo(yytext, "INT"); yylval.symbol_info = s; return INT;}
"char" {return CHAR;}
"float" { SymbolInfo *s= new  SymbolInfo(yytext, "FLOAT"); yylval.symbol_info = s; return FLOAT;} 
"double" {return DOUBLE;}
"void" { SymbolInfo *s= new  SymbolInfo(yytext, "VOID"); yylval.symbol_info = s; return VOID;}
"return" {return RETURN;}
"switch" {return SWITCH;}
"case" {return CASE;}
"default" {return DEFAULT;}
"continue" {return CONTINUE;}
"printf"	{return PRINTLN;}

{ID}	{
		installID();
		SymbolInfo *s= new  SymbolInfo(yytext, "ID");
		yylval.symbol_info = s;
		return ID;
}

{DIGITS}	{
				addConstInt();
				SymbolInfo *s= new  SymbolInfo(yytext, "CONST_INT");
				yylval.symbol_info = s;
				return CONST_INT;
			}

{FLOAT}		{
				addConstFloat();
				SymbolInfo *s= new  SymbolInfo(yytext, "CONST_FLOAT");
				yylval.symbol_info = s;
				return CONST_FLOAT;
			}

{TOO_MANY_POINTS} {
	showError("TOO_MANY_DECIMAL_POINTS");

	SymbolInfo *s= new  SymbolInfo(yytext, "ERROR_FLOAT");
	yylval.symbol_info = s;
	return ERROR_FLOAT;
}

{ILL_FORMED_NUM} {
	showError("ILLFORMED_NUMBER");

	SymbolInfo *s= new  SymbolInfo(yytext, "ERROR_FLOAT");
	yylval.symbol_info = s;
	return ERROR_FLOAT;
}

{INVALID_ID} {
	showError("INVALID_ID_SUFFIX_NUM_PREFIX");

	SymbolInfo *s= new  SymbolInfo(yytext, "ID");
	yylval.symbol_info = s;
	return ID;
}

"+"|"-" { add_punc_op("ADDOP"); SymbolInfo *s= new  SymbolInfo(yytext, "ADDOP"); yylval.symbol_info = s; return ADDOP;}
"*"|"/"|"%"	{ add_punc_op("MULOP"); SymbolInfo *s= new  SymbolInfo(yytext, "MULOP"); yylval.symbol_info = s; return MULOP;}
"++"	{ add_punc_op("INCOP"); return INCOP;}
"--"	{ add_punc_op("DECOP"); return DECOP;}

"<"|"<="|">"|">="|"=="|"!="	{ add_punc_op("RELOP"); SymbolInfo *s= new  SymbolInfo(yytext, "RELOP"); yylval.symbol_info = s; return RELOP;}
"="	{ add_punc_op("ASSIGNOP"); return ASSIGNOP;}
"&&"|"||"	{ add_punc_op("LOGICOP"); SymbolInfo *s= new  SymbolInfo(yytext, "LOGICOP"); yylval.symbol_info = s; return LOGICOP;}
"!"	{add_punc_op("NOT"); return NOT;}

"("	{ add_punc_op("LPAREN"); return LPAREN;}
")"	{ add_punc_op("RPAREN"); return RPAREN;}
"{"	{ add_punc_op("LCURL"); return LCURL;}
"}"	{ add_punc_op("RCURL"); return RCURL;}
"["	{ add_punc_op("LTHIRD"); return LTHIRD;}
"]" { add_punc_op("RTHIRD"); return RTHIRD;}

","	{ add_punc_op("COMMA"); return COMMA;}
";"	{ add_punc_op("SEMICOLON"); return SEMICOLON;}

({CHAR}|{ESC})		{
						addConstChar();
						SymbolInfo *s = new  SymbolInfo(yytext, "CONST_CHAR");
						yylval.symbol_info = s;
						return CONST_CHAR;
					}
{INVALID_CHAR}  	{
						showError("MULTICHAR_CONST_CHAR");
						SymbolInfo *s = new  SymbolInfo(yytext, "ERROR_CHAR");
						yylval.symbol_info = s;
						return ERROR_CHAR;
					}
{UNF_CHAR}			{
						showError("UNFINISHED_CONST_CHAR");
						SymbolInfo *s = new  SymbolInfo("\0", "ERROR_CHAR");
						yylval.symbol_info = s;
						return ERROR_CHAR;
					}
{EMP_CHAR}			{
						showError("EMPTY_CONST_CHAR");
						SymbolInfo *s = new  SymbolInfo("\0", "ERROR_CHAR");
						yylval.symbol_info = s;
						return ERROR_CHAR;
					}


{STR}				{
						addString();
						SymbolInfo *s = new  SymbolInfo(yytext, "STRING");
						yylval.symbol_info = s;
						return STRING;
					}
{UNF_STR}			{showError("UNFINISHED_STRING");}


{CMNT_SL}			{ignoreComment();}

<INITIAL>"/*" 		{ 
						cmntStart = yytext;
						yymore();
						BEGIN COMMENT_ML; 
					}
<COMMENT_ML>"*/" 	{ 
						line_count += newlines_in_cmnt;
						newlines_in_cmnt = 0;
						BEGIN INITIAL;
					}
<COMMENT_ML>. 		{yymore();} 
<COMMENT_ML>\n 		{yymore(); newlines_in_cmnt++;} 
<COMMENT_ML><<EOF>> {showCommentError("UNFINISHED_COMMENT", cmntStart); return 0;}

.					{showError("UNRECOGNIZED_CHAR");}

<<EOF>> 			{
						sym_tab->print_all_scope(logout);
						fprintf(logout,"Total lines: %d\nTotal errors: %d\n",line_count,err_count);
						return 0;
					}
%%