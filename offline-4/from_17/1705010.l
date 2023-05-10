%option noyywrap
%x COMMENT_ML

%{
int newlines_in_cmnt = 0;
char* cmntStart;
#include<bits/stdc++.h>
#include <fstream>
#include <string>
#include "sym_table.cpp"
#include "y.tab.h"

extern YYSTYPE yylval;
extern SymbolTable *sym_tab;
void yyerror(char *);
extern FILE* logout;
int line_count = 1;

void add_punc_op(string token) {
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", line_count, token.data(), yytext);
}

void addConstInt() {
	string token = "CONST_INT";
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

CHAR 			\'{NOT_NEWLINE}\'
ESC 			((\'\\n\')|(\'\\t\')|(\'\\a\')|(\'\\b\')|(\'\\r\')|(\'\\f\')|(\'\\v\')|(\'\\\'\')|(\'\\\"\')|(\'\\\\')|(\'\\0\'))

UNF_STR 		\"([^'"\\\n]|(\\)({NOT_NEWLINE}|{NEWLINE}))*
STR 			{UNF_STR}\"

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
"int" { SymbolInfo *s= new  SymbolInfo(yytext, "INT"); yylval.symInfo = s; return INT;}
"char" {return CHAR;}
"double" {return DOUBLE;}
"void" { SymbolInfo *s= new  SymbolInfo(yytext, "VOID"); yylval.symInfo = s; return VOID;}
"return" {return RETURN;}
"switch" {return SWITCH;}
"case" {return CASE;}
"default" {return DEFAULT;}
"continue" {return CONTINUE;}
"println"	{return PRINTLN;}

{ID}	{
		installID();
		SymbolInfo *s= new  SymbolInfo(yytext, "ID");
		yylval.symInfo = s;
		return ID;
}

{DIGITS}	{
				addConstInt();
				SymbolInfo *s= new  SymbolInfo(yytext, "CONST_INT");
				yylval.symInfo = s;
				return CONST_INT;
			}

"+"|"-" { add_punc_op("ADDOP"); SymbolInfo *s= new  SymbolInfo(yytext, "ADDOP"); yylval.symInfo = s; return ADDOP;}
"*"|"/"|"%"	{ add_punc_op("MULOP"); SymbolInfo *s= new  SymbolInfo(yytext, "MULOP"); yylval.symInfo = s; return MULOP;}
"++"	{ add_punc_op("INCOP"); return INCOP;}
"--"	{ add_punc_op("DECOP"); return DECOP;}

"<"|"<="|">"|">="|"=="|"!="	{ add_punc_op("RELOP"); SymbolInfo *s= new  SymbolInfo(yytext, "RELOP"); yylval.symInfo = s; return RELOP;}
"="	{ add_punc_op("ASSIGNOP"); return ASSIGNOP;}
"&&"|"||"	{ add_punc_op("LOGICOP"); SymbolInfo *s= new  SymbolInfo(yytext, "LOGICOP"); yylval.symInfo = s; return LOGICOP;}
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
						yylval.symInfo = s;
						return CONST_CHAR;
					}
{STR}				{
						addString();
						SymbolInfo *s = new  SymbolInfo(yytext, "STRING");
						yylval.symInfo = s;
						return STRING;
					}


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
<COMMENT_ML><<EOF>> {return 0;}

.					{}

<<EOF>> 			{
						return 0;
					}
%%