#define MAX_TABLE_SIZE 10

#define _addop_ "ADDOP"
#define _mulop_ "MULOP"
#define _incop_ "INCOP"
#define _relop_ "RELOP"
#define _asgnop_ "ASSIGNOP"
#define _logop_ "LOGICOP"
#define _bitop_ "BITOP"
#define _not_ "NOT"
#define _lparen_ "LPAREN"
#define _rparen_ "RPAREN"
#define _lcurl_ "LCURL"
#define _rcurl_ "RCURL"
#define _lsq_ "LSQUARE"
#define _rsq_ "RSQUARE"
#define _comma_ "COMMA"
#define _semicolon_ "SEMICOLON"

#include "sym_table.h"

SymbolTable symTable(MAX_TABLE_SIZE);
int num_lines = 1;
int num_err = 0;

void replace_help(string &str, string const &prev, string const &new) {
	size_t pos = 0;
    while (pos += new.length())
    {
        pos = str.find(prev, pos);
        if (pos == std::string::npos) {
            break;
        }
 
        str.erase(pos, prev.length());
        str.insert(pos, new);
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
	replace_help(replaced, "\\\\", "\\\\");
	replace_help(replaced, "\\0", "\0");

	return replaced;
}


void insertTosymTable(string token_symbol,string token_name) {
	bool insert_success = symTable.__insert(token_name, token_symbol);
	if(insert_success)	symTable.__print("A");
}

void addToken_keyword() {
	string token_name = yytext;
	transform(token_name.begin(), token_name.end(), token_name.begin(), ::toupper);
	fprintf(tokenout, "<%s,%s>\n", token_name.data(), yytext);
	fprintf(logout, "Line# %d: TOKEN <%s> Lexeme %s found\n", num_lines, token_name.data(), yytext);
}

void addToken_operator(string token_name) {
	if(token_name == _lcurl_)	symTable.enterScope();
	else if(token_name == _rcurl_)	symTable.exitScope();

	fprintf(tokenout, "<%s,%s>\n", token_name.data(), yytext);
	fprintf(logout, "Line# %d: TOKEN <%s> Lexeme %s found\n", num_lines, token_name.data(), yytext);
}

void addToken_const_int() {
	string token_name = "CONST_INT";
	fprintf(tokenout, "<%s,%s>\n", token_name.data(), yytext);
	fprintf(logout, "Line# %d: TOKEN <%s> Lexeme %s found\n", num_lines, token_name.data(), yytext);
}

void addToken_const_float() {
	string token_name = "CONST_FLOAT";
	fprintf(tokenout, "<%s,%s>\n", token_name.data(), yytext);
	fprintf(logout, "Line# %d: TOKEN <%s> Lexeme %s found\n", num_lines, token_name.data(), yytext);
}

void addToken_const_char() {
	string token_name = "CONST_CHAR";

	//replace with ascii representations
	string char_literal = replace(yytext);

	//delete enclosing quotations
	char_literal = "" + char_literal.substr(1);
	char_literal = char_literal.substr(0, char_literal.size() - 1) + "";

	fprintf(tokenout, "<%s,%s>\n", token_name.data(), char_literal.data());
	fprintf(logout, "Line# %d: TOKEN <%s> Lexeme %s found\n", num_lines, token_name.data(), char_literal.data());
}

void addToken_string() {
	string token_name = "STRING";

	string string_literal = replace(yytext);

	//delete enclosing quotations
	string_literal = "" + string_literal.substr(1);
	string_literal = string_literal.substr(0, string_literal.size() - 1) + "";

	fprintf(tokenout,  "<%s,%s>\n", token_name.data(), string_literal.data());
	fprintf(logout, "Line# %d: TOKEN <%s> Lexeme %s found\n", num_lines, token_name.data(), yytext);

	num_lines += std::count(string_literal.begin(), string_literal.end(), '\n');
}

void addToken_identifier() {
	string token_name = "ID";
	fprintf(tokenout, "<%s,%s>\n", token_name.data(), yytext);
	fprintf(logout, "Line# %d: TOKEN <%s> Lexeme %s found\n", num_lines, token_name.data(), yytext);
	insertTosymTable(token_name, yytext);
}

void printError(string msg) {
	fprintf(logout, "Error at line# %d: %s %s\n", num_lines, msg.data(), yytext);
	num_err++;
	string string_literal = replace(yytext);
	num_lines += std::count(string_literal.begin(), string_literal.end(), '\n');
}
