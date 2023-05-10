#include "sym_table.h"

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

SymbolTable symTable(MAX_TABLE_SIZE);
int num_lines = 1;
int num_err = 0;

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

void insertIntoTable(string token, string sym) {
	bool insert_success = symTable.__insert(sym, token);
	if(insert_success)	symTable.__print("A");
}

void addKeyword() {
	string token = yytext;
	transform(token.begin(), token.end(), token.begin(), ::toupper);
	fprintf(tokenout, "<%s, %s>\n", token.data(), yytext);
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", num_lines, token.data(), yytext);
}

void add_punc_op(string token) {
	fprintf(tokenout, "<%s, %s>\n", token.data(), yytext);
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", num_lines, token.data(), yytext);

	if(token == _lcurl_)	symTable.enterScope();
	else if(token == _rcurl_)	symTable.exitScope();
}

void addConstInt() {
	string token = "CONST_INT";
	fprintf(tokenout, "<%s, %s>\n", token.data(), yytext);
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", num_lines, token.data(), yytext);
}

void addConstFloat() {
	string token = "CONST_FLOAT";
	fprintf(tokenout, "<%s, %s>\n", token.data(), yytext);
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", num_lines, token.data(), yytext);
}

void addConstChar() {
	string token = "CONST_CHAR";

	//replace with ascii representations
	string const_char = replace(yytext);

	//remove enclosing quotations
	const_char = "" + const_char.substr(1);
	const_char = const_char.substr(0, const_char.size() - 1) + "";

	fprintf(tokenout, "<%s, %s>\n", token.data(), const_char.data());
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", num_lines, token.data(), const_char.data());
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
	fprintf(tokenout,  "<%s, %s>\n", token.data(), const_str.data());
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", num_lines, token.data(), yytext);

	num_lines += num_newline_char;
}

void installID() {
	string token = "ID";
	fprintf(tokenout, "<%s, %s>\n", token.data(), yytext);
	fprintf(logout, "Line# %d: Token <%s> Lexeme %s found\n", num_lines, token.data(), yytext);
	insertIntoTable(token, yytext);
}

void ignoreComment(){
	string string_literal = replace(yytext);
	fprintf(logout, "Line# %d: Token <SINGLE LINE COMMENT> Lexeme %s found\n", num_lines, yytext);
	num_lines += std::count(string_literal.begin(), string_literal.end(), '\n');
}

void showError(string msg) {
	string string_literal = replace(yytext);
	int err_line_count = std::count(string_literal.begin(), string_literal.end(), '\n');

	fprintf(logout, "Error at line# %d: %s %s\n", num_lines + err_line_count, msg.data(), yytext);

	num_err++;
	num_lines += err_line_count;
}

void showCmntError(string msg, string unf_cmnt){
	string string_literal = replace(unf_cmnt.data());
	int err_line_count = std::count(string_literal.begin(), string_literal.end(), '\n');

	fprintf(logout, "Error at line# %d: %s %s\n", num_lines + err_line_count, msg.data(), unf_cmnt.data());
	
	num_err++;
	num_lines += err_line_count;
}
