%option noyywrap

%x COMMENT_ML

%{
#include "actions.h"
int newlines_in_cmnt = 0;
char* cmntStart;
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
{NEWLINE}		{num_lines++;}

{WHITESPACE}	{}

"if" 		|
"for" 		|
"do" 		|
"int" 		|
"float" 	|
"void" 		|
"switch" 	|
"default" 	|
"else" 		|
"while" 	|
"break" 	|
"char" 		|
"double" 	|
"return"	|
"case" 		|
"continue" 	{addKeyword();}

("+"|"-")						{add_punc_op(_addop_);}
("*"|"/"|"%")					{add_punc_op(_mulop_);}
("++"|"--")						{add_punc_op(_incop_);}
("<"|"<="|">"|">="|"=="|"!=") 	{add_punc_op(_relop_);}
("=")							{add_punc_op(_asgnop_);}
("&&"|"||")						{add_punc_op(_logop_);}
("&"|"|"|"^"|"<<"|">>")			{add_punc_op(_bitop_);}
"!"								{add_punc_op(_not_);}
"("								{add_punc_op(_lparen_);}
")"								{add_punc_op(_rparen_);}
"{"								{add_punc_op(_lcurl_);}
"}"								{add_punc_op(_rcurl_);}
"["								{add_punc_op(_lsq_);}
"]"								{add_punc_op(_rsq_);}
","								{add_punc_op(_comma_);}
";"								{add_punc_op(_semicolon_);}


{DIGITS}			{addConstInt();}
{FLOAT}				{addConstFloat();}
{TOO_MANY_POINTS}	{showError("TOO_MANY_DECIMAL_POINTS");}
{ILL_FORMED_NUM}	{showError("ILLFORMED_NUMBER");}

{SLASH_IN_QUOTES}	{showError("UNFINISHED_CONST_CHAR");}
({CHAR}|{ESC})		{addConstChar();}
{INVALID_CHAR}  	{showError("MULTICHAR_CONST_CHAR");}
{UNF_CHAR}			{showError("UNFINISHED_CONST_CHAR");}
{EMP_CHAR}			{showError("EMPTY_CONST_CHAR");}

{STR}				{addString();}
{UNF_STR}			{showError("UNFINISHED_STRING");}


{ID}				{installID();}
{INVALID_ID}		{showError("INVALID_ID_SUFFIX_NUM_PREFIX");}


{CMNT_SL}			{ignoreComment();}

<INITIAL>"/*" 		{ 
					cmntStart = yytext;
					yymore();
					BEGIN COMMENT_ML; 
					}
<COMMENT_ML>"*/" 	{ 
					fprintf(logout, "Line# %d: Token <MULTI LINE COMMENT> Lexeme %s found\n", num_lines, yytext);
					num_lines += newlines_in_cmnt;
					newlines_in_cmnt = 0;
					BEGIN INITIAL;
					}
<COMMENT_ML>. 		{yymore();} 
<COMMENT_ML>\n 		{yymore(); newlines_in_cmnt++;} 
<COMMENT_ML><<EOF>> {
					showCmntError("UNFINISHED_COMMENT", cmntStart); 
					symTable.__print("A");
					fprintf(logout,"Total lines: %d\nTotal errors: %d\n",num_lines,num_err); 
					return 0;
					}

.					{showError("UNRECOGNIZED_CHAR");}

<<EOF>> 			{
					symTable.__print("A");
					fprintf(logout,"Total lines: %d\nTotal errors: %d\n",num_lines,num_err);
					return 0;
					}
%%

int main(int argc,char *argv[]){

	if(argc!=2){
		printf("Please provide input file name and try again\n");
		return 0;
	}
	FILE *fin=fopen(argv[1],"r");
	if(fin==NULL){
		printf("Cannot open specified file\n");
		return 0;
	}

	logout= fopen("log.txt","w");
	tokenout= fopen("token.txt","w");

	yyin= fin;
	yylex();
	fclose(yyin);
	fclose(tokenout);
	fclose(logout);
	return 0;
}