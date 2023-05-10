%{
#include <stdio.h>
#include <iostream>
#include<bits/stdc++.h>
#include <typeinfo>
#include <fstream>
#include <sstream>
#include <string.h>
using namespace std;

#include "sym_table.cpp"

FILE* logout;
FILE* errout;
FILE* parseout;

extern int line_count;
int err_count = 0;

extern FILE *yyin;

void yyerror(string s){
    // fprintf(errout, "Line# %d: %s\n", line_count, s.data());
    // err_count++;
}

int yyparse(void);
int yylex(void);

SymbolTable *sym_tab = new SymbolTable(10);

bool curr_ID_func = false;
vector<SymbolInfo> temp_param_list;


string typecast(char* left, char* right)
{
    if(!strcmp(left,"NULL") || !strcmp(right,"NULL")) return "NULL";

    if(!strcmp(left,"void") || !strcmp(right,"void")) return "error";

    if((!strcmp(left,"float") || !strcmp(left,"float_array")) && (!strcmp(right,"float") || !strcmp(right,"float_array"))) return "float";
    if((!strcmp(left,"float") || !strcmp(left,"float_array")) && (!strcmp(right,"int") || !strcmp(right,"int_array"))) return "float";
    if((!strcmp(left,"int") || !strcmp(left,"int_array")) && (!strcmp(right,"float") || !strcmp(right,"float_array"))) return "float";
    if((!strcmp(left,"int") || !strcmp(left,"int_array")) && (!strcmp(right,"int") || !strcmp(right,"int_array"))) return "int";

    return "error";
}

bool is_typecast_valid(string required,string given)
{
    if(required == "void") return given == "void";
    if(required == "int") return (given == "int" || given == "int_array");
    if(required == "float") return given == "float";
}

bool is_assignment_valid(char* left, char* right)
{
    if(!strcmp(left,"NULL") || !strcmp(right,"NULL")) return true; 

    if(!strcmp(left,"void") || !strcmp(right,"void")) return false;
    if(!strcmp(left,"") || !strcmp(right,"")) return false;

    if((!strcmp(left,"int") || !strcmp(left,"int_array")) && (!strcmp(right,"int") || !strcmp(right,"int_array"))) return true;
    if((!strcmp(left,"float") || !strcmp(left,"float_array")) && strcmp(right,"void")) return true;

    return false;
}

void print_rule(string head,string body)
{
    fprintf(logout, "%s : %s\n", head.data(), body.data());
}

void mult_declaration_error(string error_symbol, bool _isFunc)
{
    if(_isFunc) fprintf(errout, "Line# %d: Redefinition of parameter \'%s\'\n", line_count, error_symbol.data());
    else    fprintf(errout, "Line# %d: \'%s\' redeclared as different kind of symbol\n", line_count, error_symbol.data());
    err_count++;
}

void typecast_error()
{
    fprintf(errout, "Line# %d: Incompatible Operand\n", line_count);
    err_count++;
}

void void_expression_error()
{
    fprintf(errout, "Line# %d: Void cannot be used in expression\n", line_count);
    err_count++;
}

void type_conflict_error(string msg)
{
    fprintf(errout, "Line# %d: Conflicting types for \'%s\'\n", line_count, msg.data());
    err_count++;
}

typedef struct ptnode {
    char value[100];
    char token[100];
    char resultType[100];
    vector<string> args_list;
    vector<SymbolInfo*> decl_list;
	bool lastchild;
	struct ptnode *child;
    struct ptnode *leaf;
} ptnode;

ptnode *Root=NULL;
int numWS = 0;

void printtree(ptnode *node)
{
    ptnode *itr;

    for(int i=1;i<numWS;i++)   fprintf(parseout, " ");

    if(numWS)  fprintf(parseout, "\\");

    if(node->lastchild)
    {
        if(!strcmp(node->token, "FUNCTION")){
            strcpy(node->token, "ID");
        }
        fprintf(parseout, "%s : %s\n", node->token, node->value);
    }
    else
    {
        if(!strcmp(node->token, "INT") || !strcmp(node->token, "FLOAT") || !strcmp(node->token, "VOID")){
            strcpy(node->token, "type_specifier");
        }
        fprintf(parseout, "%s\n", node->token);
        numWS++;
    }

    for(itr = node->child; itr != NULL; itr = itr->leaf) printtree(itr);

    if(node->lastchild==0) numWS--;
}

ptnode* getNewNode()
{
    ptnode *t = new struct ptnode();
    t->leaf = NULL;
    t->child = NULL;
    t->lastchild = 0;

    strcpy(t->token, "");
    strcpy(t->value, "");
    strcpy(t->resultType, "");

    return(t);
}

ptnode* makeChildNode(ptnode* to_insert, ptnode* root)
{
	if(root->child  ==  NULL)
		root->child = to_insert;
	else
	{
		ptnode *itr;
		for(itr = root->child; itr->leaf != NULL; itr = itr->leaf);
		itr->leaf = to_insert;
	}
	return(root);
}

ptnode* makeChildNode(SymbolInfo* sym, ptnode* root)
{
	ptnode *to_insert = getNewNode();
	to_insert->lastchild = 1;
	strcpy(to_insert->value, sym->lexeme.c_str());
	strcpy(to_insert->token, sym->token.c_str());
	root = makeChildNode(to_insert, root);
	return (root);
}

ptnode* makeChildNode(string value, string token, ptnode* root)
{
	ptnode *to_insert = getNewNode();
	to_insert->lastchild = 1;
	strcpy(to_insert->value, value.c_str());
	strcpy(to_insert->token, token.c_str());
	root = makeChildNode(to_insert, root);
	return (root);
}

ptnode* makeChildNode(string token, ptnode* t)
{
	ptnode *to_insert = getNewNode();
	to_insert->lastchild = 1;
    if(token == "LPAREN")   strcpy(to_insert->value, "(");
    else if(token == "RPAREN")  strcpy(to_insert->value, ")");
    else if(token == "COMMA")  strcpy(to_insert->value, ",");
    else if(token == "SEMICOLON")  strcpy(to_insert->value, ";");
    else if(token == "LCURL")  strcpy(to_insert->value, "{");
    else if(token == "RCURL")  strcpy(to_insert->value, "}");
    else if(token == "LTHIRD")  strcpy(to_insert->value, "[");
    else if(token == "RTHIRD")  strcpy(to_insert->value, "]");
    else if(token == "NOT")  strcpy(to_insert->value, "!");
    else if(token == "ASSIGNOP")  strcpy(to_insert->value, "=");
    else if(token == "DECOP")  strcpy(to_insert->value, "--");
    else if(token == "INCOP")  strcpy(to_insert->value, "++");
    else if(token == "RETURN")  strcpy(to_insert->value, "return");
	strcpy(to_insert->token, token.c_str());
	t = makeChildNode(to_insert,t);
	return (t);
}

void insert_to_symtable(SymbolInfo* func_id,char* ret_type)
{
    bool isParamListError = false;

    for(int i=0;i<temp_param_list.size();i++)
    {
        if(temp_param_list[i].lexeme == "some_name"){
            fprintf(errout, "Line# %d: Syntax error at parameter list of function definition\n", line_count);
            err_count++;
            isParamListError = true;
            break;
        }
    }

    if(!isParamListError){
        
        func_id->token = "FUNCTION";
        func_id->data_type = ret_type;
        func_id->isFunc = true;

        for(auto param : temp_param_list)
        {
            func_id->args_list.push_back(param.data_type);
        }

        if(!sym_tab->_insert(*func_id))
        {
            SymbolInfo* si = sym_tab->_search(func_id->lexeme);

            if(si->isFuncDecl == false){
                mult_declaration_error(func_id->lexeme, si->isFuncParam);
            }
            else{
                if(si->data_type != func_id->data_type)
                {
                    fprintf(errout, "Line# %d: Conflicting types for \'%s\'\n", line_count, (func_id->lexeme).data());
                    err_count++;
                }

                if(si->args_list.size() != func_id->args_list.size())
                {
                    type_conflict_error(func_id->lexeme);
                }
                else
                {
                    for(int i = 0; i < (si->args_list.size()); i++)
                    {
                        if(si->args_list[i] != func_id->args_list[i]){
                            type_conflict_error(func_id->lexeme);
                        }
                    }
                }
                si->isFuncDecl = false;
            }
        }
        else{
            SymbolInfo* si = sym_tab->_search(func_id->lexeme);
            si->isFuncDecl = false;
        }
    }
}

%}

%union{
    SymbolInfo* symInfo;
    char* string;
    struct ptnode *node;
}

%token <string> IF ELSE LOWER_THAN_ELSE FOR WHILE DO BREAK CHAR DOUBLE RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN INCOP DECOP ASSIGNOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
%token <symInfo> ID INT FLOAT VOID ADDOP MULOP RELOP LOGICOP CONST_CHAR CONST_INT CONST_FLOAT STRING ERROR_CHAR ERROR_FLOAT  
%type <node> start program unit variable var_declaration type_specifier func_declaration func_definition parameter_list expression factor unary_expression term simple_expression rel_expression statement statements compound_statement logic_expression expression_statement arguments argument_list declaration_list

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start: program
	{
		//write your code in this block in all the similar blocks below

        print_rule("start","program");

        Root = getNewNode();
        strcpy(Root->token,"start");
        Root = makeChildNode($1,Root);
	}
	;

program: program unit  {
            print_rule("program","program unit");
            ptnode *a = getNewNode();
            strcpy(a->token,"program");
            a=makeChildNode($1,a);
            a=makeChildNode($2,a);
            $$ = a;
        }
	| unit { 
            print_rule("program","unit");
            ptnode *a = getNewNode();
            strcpy(a->token,"program");
            a=makeChildNode($1,a);
            $$ = a;
        }
	;
	
unit: var_declaration { 
            print_rule("unit","var_declaration"); 
            ptnode *a = getNewNode();
            strcpy(a->token,"unit");
            a=makeChildNode($1,a);
            $$ = a;
        }
     | func_declaration { 
            print_rule("unit","func_declaration"); 
            ptnode *a = getNewNode();
            strcpy(a->token,"unit");
            a=makeChildNode($1,a);
            $$ = a;
        }
     | func_definition { 
            print_rule("unit","func_definition");
            ptnode *a = getNewNode();
            strcpy(a->token,"unit");
            a=makeChildNode($1,a);
            $$ = a;
        }
     ;
     
func_declaration: type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {  
                print_rule("func_declaration","type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_declaration");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN", a);
                a=makeChildNode($4,a);
                a=makeChildNode("RPAREN", a);
                a=makeChildNode("SEMICOLON", a);
                $$ = a;        

                $2->setDataType($1->token);
                $2->token = "FUNCTION";
                $2->isFunc = true;


                for(auto sym : temp_param_list)
                {
                    $2->args_list.push_back(sym.data_type);
                }
                
                if(sym_tab->_insert(*$2))
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    si->isFuncDecl = true;
                }
                else
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    mult_declaration_error($2->lexeme, si->isFuncParam);
                }


                temp_param_list.clear();
        }
        | type_specifier ID LPAREN parameter_list RPAREN error { 
                
                print_rule("func_declaration","type_specifier ID LPAREN parameter_list RPAREN");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_declaration");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN", a);
                a=makeChildNode($4,a);
                a=makeChildNode("RPAREN", a);
                $$ = a;


                $2->setDataType($1->token);
                $2->token = "FUNCTION";
                $2->isFunc = true;


                for(auto sym : temp_param_list)
                {
                    $2->args_list.push_back(sym.data_type);
                }

                if(sym_tab->_insert(*$2))
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    si->isFuncDecl = true;
                }
                else
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    mult_declaration_error($2->lexeme, si->isFuncParam);
                }


                temp_param_list.clear();    
        }
        | type_specifier ID LPAREN parameter_list error RPAREN SEMICOLON { 
                print_rule("func_declaration","type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_declaration");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN", a);
                a=makeChildNode($4,a);
                a=makeChildNode("RPAREN", a);
                a=makeChildNode("SEMICOLON", a);
                $$ = a;


                $2->setDataType($1->token);
                $2->token = "FUNCTION";
                $2->isFunc = true;


                for(auto sym : temp_param_list)
                {
                    $2->args_list.push_back(sym.data_type);
                }

                if(sym_tab->_insert(*$2))
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    si->isFuncDecl = true;
                }
                else
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    mult_declaration_error($2->lexeme, si->isFuncParam);
                }


                temp_param_list.clear();
        }
        | type_specifier ID LPAREN parameter_list error RPAREN error { 
                
                print_rule("func_declaration","type_specifier ID LPAREN parameter_list RPAREN");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_declaration");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN", a);
                a=makeChildNode($4,a);
                a=makeChildNode("RPAREN", a);
                $$ = a;


                $2->setDataType($1->token);
                $2->token = "FUNCTION";
                $2->isFunc = true;


                for(auto sym : temp_param_list)
                {
                    $2->args_list.push_back(sym.data_type);
                }

                if(sym_tab->_insert(*$2))
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    si->isFuncDecl = true;
                }
                else
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    mult_declaration_error($2->lexeme, si->isFuncParam);
                }


                temp_param_list.clear();
        }
		| type_specifier ID LPAREN RPAREN SEMICOLON { 

                print_rule("func_declaration","type_specifier ID LPAREN RPAREN SEMICOLON");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_declaration");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN", a);
                a=makeChildNode("RPAREN", a);
                a=makeChildNode("SEMICOLON", a);
                $$ = a;


                $2->setDataType($1->token);
                $2->token = "FUNCTION";
                $2->isFunc = true;
                
                if(sym_tab->_insert(*$2))
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    si->isFuncDecl = true;
                }
                else
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    mult_declaration_error($2->lexeme, si->isFuncParam);
                }

                temp_param_list.clear();
            }
            | type_specifier ID LPAREN RPAREN error { 

            print_rule("func_declaration","type_specifier ID LPAREN RPAREN");

            ptnode *a = getNewNode();
            strcpy(a->token,"func_declaration");
            a=makeChildNode($1,a);
            a=makeChildNode($2,a);
            a=makeChildNode("LPAREN", a);
            a=makeChildNode("RPAREN", a);
            $$ = a;

            // insert function ID to SymbolTable with data_type
            $2->setDataType($1->token);
            $2->token = "FUNCTION";
            $2->isFunc = true;
            
            if(sym_tab->_insert(*$2))
            {
                SymbolInfo* si = sym_tab->_search($2->lexeme);
                si->isFuncDecl = true;
            }
            else
            {
                SymbolInfo* si = sym_tab->_search($2->lexeme);
                mult_declaration_error($2->lexeme, si->isFuncParam);
            }

            temp_param_list.clear();
        }
        | type_specifier ID LPAREN error RPAREN SEMICOLON { 

                print_rule("func_declaration","type_specifier ID LPAREN RPAREN SEMICOLON");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_declaration");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN", a);
                a=makeChildNode("RPAREN", a);
                a=makeChildNode("SEMICOLON", a);
                $$ = a;


                $2->setDataType($1->token);
                $2->token = "FUNCTION";
                $2->isFunc = true;
                
                if(sym_tab->_insert(*$2))
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    si->isFuncDecl = true;
                }
                else
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    mult_declaration_error($2->lexeme, si->isFuncParam);
                }

                temp_param_list.clear();
            }
        | type_specifier ID LPAREN error RPAREN error { 
                print_rule("func_declaration","type_specifier ID LPAREN RPAREN");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_declaration");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN", a);
                a=makeChildNode("RPAREN", a);
                $$ = a;


                $2->setDataType($1->token);
                $2->token = "FUNCTION";
                $2->isFunc = true;
                
                if(sym_tab->_insert(*$2))
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    si->isFuncDecl = true;
                }
                else
                {
                    SymbolInfo* si = sym_tab->_search($2->lexeme);
                    mult_declaration_error($2->lexeme, si->isFuncParam);
                }

                temp_param_list.clear();
            }
		;

		 
func_definition: type_specifier ID LPAREN parameter_list RPAREN { curr_ID_func = true;insert_to_symtable($2,$1->token); } compound_statement { 
                print_rule("func_definition","type_specifier ID LPAREN parameter_list RPAREN compound_statement");
                ptnode *a = getNewNode();
                strcpy(a->token,"func_definition");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN",a);
                a=makeChildNode($4,a);
                a=makeChildNode("RPAREN",a);
                a=makeChildNode($7,a);
                $$ = a;


                curr_ID_func = false;
                temp_param_list.clear();
            }
        | type_specifier ID LPAREN parameter_list error RPAREN { curr_ID_func = true;insert_to_symtable($2,$1->token); } compound_statement { 
                print_rule("func_definition","type_specifier ID LPAREN parameter_list RPAREN compound_statement");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_definition");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN",a);
                a=makeChildNode($4,a);
                a=makeChildNode("RPAREN",a);
                a=makeChildNode($8,a);
                $$ = a;


                curr_ID_func = false;
                temp_param_list.clear();
        }
		|   type_specifier ID LPAREN RPAREN {curr_ID_func = true;insert_to_symtable($2,$1->token);} compound_statement { 
                print_rule("func_definition","type_specifier ID LPAREN RPAREN compound_statement");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_definition");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN",a);
                a=makeChildNode("RPAREN",a);
                a=makeChildNode($6,a);
                $$ = a;


                curr_ID_func = false;
                temp_param_list.clear();
            }
        |  type_specifier ID LPAREN error RPAREN { curr_ID_func = true;insert_to_symtable($2,$1->token); } compound_statement {
                print_rule("func_definition","type_specifier ID LPAREN error RPAREN compound_statement");

                ptnode *a = getNewNode();
                strcpy(a->token,"func_definition");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode("LPAREN",a);
                a=makeChildNode("RPAREN",a);
                a=makeChildNode($7,a);
                $$ = a;

                curr_ID_func = false;
                temp_param_list.clear();
        }
 		;				


parameter_list: parameter_list COMMA type_specifier ID {
                print_rule("parameter_list","parameter_list COMMA type_specifier ID");

                ptnode *a = getNewNode();
                strcpy(a->token,"parameter_list");
                a=makeChildNode($1,a);
                a=makeChildNode("COMMA",a);
                a=makeChildNode($3,a);
                a=makeChildNode($4,a);
                $$ = a;


                $4->setDataType($3->value);
                $4->token = $3->token;
                $4->isFuncParam = true;
                temp_param_list.push_back(*$4);
            }
        | parameter_list error COMMA type_specifier ID {
            print_rule("parameter_list","parameter_list COMMA type_specifier ID");
        
            ptnode *a = getNewNode();
            strcpy(a->token,"parameter_list");
            a=makeChildNode($1,a);
            a=makeChildNode("COMMA",a);
            a=makeChildNode($4,a);
            a=makeChildNode($5,a);
            $$ = a;


            $5->setDataType($4->value);
            $5->token = $4->token;
            $5->isFuncParam = true;
            temp_param_list.push_back(*$5);
        }
        | parameter_list COMMA type_specifier {
            print_rule("parameter_list","parameter_list COMMA type_specifier");
            ptnode *a = getNewNode();
            strcpy(a->token,"parameter_list");
            a=makeChildNode($1,a);
            a=makeChildNode("COMMA",a);
            a=makeChildNode($3,a);
            $$ = a;

            SymbolInfo sym = SymbolInfo("some_name","some_val");
            sym.data_type = $3->value;
            sym.isFuncParam = true;
            temp_param_list.push_back(sym);
        }
        | parameter_list error COMMA type_specifier {
            print_rule("parameter_list","parameter_list COMMA type_specifier");

            ptnode *a = getNewNode();
            strcpy(a->token,"parameter_list");
            a=makeChildNode($1,a);
            a=makeChildNode("COMMA",a);
            a=makeChildNode($4,a);
            $$ = a;

            SymbolInfo sym = SymbolInfo("some_name","some_val");
            sym.data_type = $4->value;
            sym.isFuncParam = true;
            temp_param_list.push_back(sym);
        }
 		| type_specifier ID  { 
                print_rule("parameter_list","type_specifier ID");
                ptnode *a = getNewNode();
                strcpy(a->token,"parameter_list");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                $$ = a;


                $2->setDataType($1->value);
                $2->token = $1->token;
                $2->isFuncParam = true;
                temp_param_list.push_back(*$2);
        }
		| type_specifier {
            print_rule("parameter_list","type_specifier");
            ptnode *a = getNewNode();
            strcpy(a->token,"parameter_list");
            a=makeChildNode($1,a);
            $$ = a;

            SymbolInfo sym = SymbolInfo("some_name","some_val");
            sym.data_type = $1->value;
            sym.isFuncParam = true;
            temp_param_list.push_back(sym);
        }
 		;
 		
compound_statement: LCURL dummy_scope_function statements RCURL {
                print_rule("compound_statement","LCURL statements RCURL");

                ptnode *a = getNewNode();
                strcpy(a->token,"compound_statement");
                a=makeChildNode("LCURL", a);
                a=makeChildNode($3, a);
                a=makeChildNode("RCURL", a);
                $$ = a;


                sym_tab->_print(logout,'A');
                sym_tab->exitScope();
            }
            | LCURL dummy_scope_function RCURL {

                print_rule("compound_statement","LCURL RCURL");

                ptnode *a = getNewNode();
                strcpy(a->token,"compound_statement");
                a=makeChildNode("LCURL", a);
                a=makeChildNode("RCURL", a);
                $$ = a;


                sym_tab->_print(logout,'A');
                sym_tab->exitScope();
             }
            | LCURL dummy_scope_function statements error RCURL {
                print_rule("compound_statement","LCURL statements RCURL");

                ptnode *a = getNewNode();
                strcpy(a->token,"compound_statement");
                a=makeChildNode("LCURL", a);
                a=makeChildNode($3, a);
                a=makeChildNode("RCURL", a);
                $$ = a;

 
                sym_tab->_print(logout,'A');
                sym_tab->exitScope();
            }
            | LCURL dummy_scope_function error statements RCURL {
                print_rule("compound_statement","LCURL statements RCURL");

                ptnode *a = getNewNode();
                strcpy(a->token,"compound_statement");
                a=makeChildNode("LCURL", a);
                a=makeChildNode($4, a);
                a=makeChildNode("RCURL", a);
                $$ = a;


                sym_tab->_print(logout,'A');
                sym_tab->exitScope();
            }
             | LCURL dummy_scope_function error RCURL {
                
                print_rule("compound_statement","LCURL error RCURL");

                ptnode *a = getNewNode();
                strcpy(a->token,"compound_statement");
                a=makeChildNode("LCURL", a);
                a=makeChildNode("RCURL", a);
                $$ = a;


                sym_tab->_print(logout,'A');
                sym_tab->exitScope();
             }
 		    ;
dummy_scope_function:  {

                    sym_tab->enterScope(); 

                    if(curr_ID_func)
                    {
                        for(auto param : temp_param_list)
                        {
                            if(param.lexeme == "some_name") continue;
                            if(!sym_tab->_insert(param))
                            {
                                mult_declaration_error(param.lexeme,param.isFuncParam);
                            }
                        }
                    }
                }
                ;
 		    
var_declaration: type_specifier declaration_list SEMICOLON { 

            print_rule("var_declaration","type_specifier declaration_list SEMICOLON");
            ptnode *a = getNewNode();
            strcpy(a->token,"var_declaration");
            a=makeChildNode($1,a);
            a=makeChildNode($2,a);
            a=makeChildNode("SEMICOLON",a);
            $$ = a;

            if(!strcmp($1->value,"void")){
                fprintf(errout, "Line# %d: Variable or field \'%s\' declared void\n", line_count, (($2->decl_list[0])->lexeme).data());
                err_count++;
            }
            else{
                for(auto var : $2->decl_list)
                {
                    if(var->data_type == "array") { var->setDataType(strcat($1->value, "_array")) ; var->token = "ARRAY";}
                    else { var->setDataType($1->value); var->token = $1->token; }
                    
                    if(var->token == "INT")  var->setDataType("int");
                    else if(var->token == "FLOAT")  var->setDataType("float");

                    if(!sym_tab->_insert(*var))
                    {
                        if(!strcmp(var->data_type.c_str(),$1->value)) mult_declaration_error(var->lexeme, var->isFuncParam);
                        else type_conflict_error(var->lexeme);
                    }
                }
            }
        }
        | type_specifier declaration_list error SEMICOLON {       
            print_rule("var_declaration","type_specifier declaration_list SEMICOLON");

            ptnode *a = getNewNode();
            strcpy(a->token,"var_declaration");
            a=makeChildNode($1,a);
            a=makeChildNode($2,a);
            a=makeChildNode("SEMICOLON",a);
            $$ = a;
            
            for(auto var : $2->decl_list)
            {
                if(var->data_type == "array") {var->setDataType(strcat($1->value,"_array")) ; var->token = "ARRAY";}
                else {var->setDataType($1->value); var->token = $1->value;}
                
                if(!sym_tab->_insert(*var))
                {
                    if(!strcmp(var->data_type.c_str(),$1->value)) mult_declaration_error(var->lexeme, var->isFuncParam);
                    else type_conflict_error(var->lexeme);
                }

            }
        }
 		;
 		 
type_specifier: INT  { 
                    print_rule("type_specifier","INT"); 

                    ptnode *a = getNewNode();
                    strcpy(a->token,"type_specifier");
                    a=makeChildNode($1,a);
                    $$ = a;
                    strcpy($$->value,"int");
                    strcpy($$->token,"INT");
                }
 		| FLOAT { 
                    print_rule("type_specifier","FLOAT"); 

                    ptnode *a = getNewNode();
                    strcpy(a->token,"type_specifier");
                    a=makeChildNode($1,a);
                    $$ = a;
                    strcpy($$->value,"float");
                    strcpy($$->token,"FLOAT");
                }
 		| VOID { 
                    print_rule("type_specifier","VOID"); 
                    ptnode *a = getNewNode();
                    strcpy(a->token,"type_specifier");
                    a=makeChildNode($1,a);
                    $$ = a;
                    strcpy($$->value,"void");
                    strcpy($$->token,"VOID");
                }
 		;
 		
declaration_list: declaration_list COMMA ID { 
                    print_rule("declaration_list","declaration_list COMMA ID");
                    
                    ptnode *a = getNewNode();
                    strcpy(a->token,"declaration_list");
                    a=makeChildNode($1,a);
                    a=makeChildNode("COMMA",a);
                    a=makeChildNode($3,a);
                    $$ = a;

                    
                    strcpy($$->resultType, $1->resultType);

                    
                    $$->decl_list= $1->decl_list;
                    $$->decl_list.push_back($3);
            }
            | declaration_list error COMMA ID {
                print_rule("declaration_list","declaration_list COMMA ID");

                ptnode *a = getNewNode();
                strcpy(a->token,"declaration_list");
                a=makeChildNode($1,a);
                a=makeChildNode("COMMA",a);
                a=makeChildNode($4,a);
                $$ = a;

                
                strcpy($$->resultType, $1->resultType);

                
                $$->decl_list= $1->decl_list;
                $$->decl_list.push_back($4);
                fprintf(errout, "Line# %d: Syntax error at declaration list of variable declaration\n", line_count);
                err_count++;
            }
 		    | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
                print_rule("declaration_list","declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");

                ptnode *a = getNewNode();
                strcpy(a->token,"declaration_list");
                a=makeChildNode($1,a);
                a=makeChildNode("COMMA",a);
                a=makeChildNode($3,a);
                a=makeChildNode("LTHIRD",a);
                a=makeChildNode($5,a);
                a=makeChildNode("RTHIRD",a);
                $$ = a;

                
                strcpy($$->resultType, $1->resultType);

                
                $$->decl_list= $1->decl_list;
                $3->token ="ARRAY";
                $3->data_type ="array";
                $$->decl_list.push_back($3);
           }
           | declaration_list error COMMA ID LTHIRD CONST_INT RTHIRD {
                print_rule("declaration_list","declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");

                ptnode *a = getNewNode();
                strcpy(a->token,"declaration_list");
                a=makeChildNode($1,a);
                a=makeChildNode("COMMA",a);
                a=makeChildNode($4,a);
                a=makeChildNode("LTHIRD",a);
                a=makeChildNode($6,a);
                a=makeChildNode("RTHIRD",a);
                $$ = a;

                
                strcpy($$->resultType, $1->resultType);

                
                $$->decl_list= $1->decl_list;
                $4->token ="ARRAY";
                $4->data_type ="array";
                $$->decl_list.push_back($4);
           }
           | declaration_list COMMA ID LTHIRD CONST_FLOAT RTHIRD {
                print_rule("declaration_list","declaration_list COMMA ID LTHIRD CONST_FLOAT RTHIRD");

                ptnode *a = getNewNode();
                strcpy(a->token,"declaration_list");
                a=makeChildNode($1,a);
                a=makeChildNode("COMMA",a);
                a=makeChildNode($3,a);
                a=makeChildNode("LTHIRD",a);
                a=makeChildNode($5,a);
                a=makeChildNode("RTHIRD",a);
                $$ = a;

                
                strcpy($$->resultType, $1->resultType);

                
                $$->decl_list= $1->decl_list;
                $$->decl_list.push_back($3);

                fprintf(errout, "Line# %d: Non-integer Array Size\n", line_count);
                err_count++;
            }
            | declaration_list error COMMA ID LTHIRD CONST_FLOAT RTHIRD {
                print_rule("declaration_list","declaration_list COMMA ID LTHIRD CONST_FLOAT RTHIRD");

                ptnode *a = getNewNode();
                strcpy(a->token,"declaration_list");
                a=makeChildNode($1,a);
                a=makeChildNode("COMMA",a);
                a=makeChildNode($4,a);
                a=makeChildNode("LTHIRD",a);
                a=makeChildNode($6,a);
                a=makeChildNode("RTHIRD",a);
                $$ = a;

                
                strcpy($$->resultType, $1->resultType);

                
                $$->decl_list= $1->decl_list;
                $$->decl_list.push_back($4);

                fprintf(errout, "Line# %d: Non-integer Array Size\n", line_count);
                err_count++;
            }
 		    | ID {     
                    print_rule("declaration_list","ID");

                    ptnode *a = getNewNode();
                    strcpy(a->token,"declaration_list");
                    a=makeChildNode($1,a);
                    $$ = a;

                    
                    $$->decl_list.push_back($1);
            }
 		    | ID LTHIRD CONST_INT RTHIRD {

                    print_rule("declaration_list","ID LTHIRD CONST_INT RTHIRD");

                    ptnode *a = getNewNode();
                    strcpy(a->token,"declaration_list");
                    a=makeChildNode($1,a);
                    a=makeChildNode("LTHIRD",a);
                    a=makeChildNode($3,a);
                    a=makeChildNode("RTHIRD",a);
                    $$ = a;

                    
                    $1->token = "ARRAY";
                    $1->data_type ="array";
                    $$->decl_list.push_back($1);
            }
            | ID LTHIRD CONST_FLOAT RTHIRD {
                    print_rule("declaration_list","ID LTHIRD CONST_FLOAT RTHIRD");

                    ptnode *a = getNewNode();
                    strcpy(a->token,"declaration_list");
                    a=makeChildNode($1,a);
                    a=makeChildNode("LTHIRD",a);
                    a=makeChildNode($3,a);
                    a=makeChildNode("RTHIRD",a);
                    $$ = a;

                    
                    $$->decl_list.push_back($1);

                    fprintf(errout, "Line# %d: Non-integer Array Size\n", line_count);
                    err_count++;
           }
 		  ;
 		  
statements: statement {
            print_rule("statements","statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statements");
            a=makeChildNode($1,a);
            $$ = a;
            
        }
	   | statements statement {
            print_rule("statements","statements statement");
        
            ptnode *a = getNewNode();
            strcpy(a->token,"statements");
            a=makeChildNode($1,a);
            a=makeChildNode($2,a);
            $$ = a;
        }
        | statements error statement {
            print_rule("statements","statements statement");
        
            ptnode *a = getNewNode();
            strcpy(a->token,"statements");
            a=makeChildNode($1,a);
            a=makeChildNode($3,a);
            $$ = a;
        }
        
	   ;
	   
statement: var_declaration {
            print_rule("statement","var_declaration");

            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;
        }
      | func_definition {
            print_rule("statement","func_definition");

            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;

            fprintf(errout, "Line# %d: A function cannot be defined inside another function\n", line_count);
            err_count++;
      }
      | func_declaration {
            print_rule("statement","func_declaration");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;

            fprintf(errout, "Line# %d: A function cannot be declared inside another function\n", line_count);
            err_count++;
      }
	  | expression_statement {
            print_rule("statement","expression_statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;
        }
	  | compound_statement {
            print_rule("statement","compound_statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;
        }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement {
            print_rule("statement","FOR LPAREN expression_statement expression_statement expression RPAREN statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1, "FOR", a);
            a=makeChildNode("LPAREN", a);
            a=makeChildNode($3, a);
            a=makeChildNode($4, a);
            a=makeChildNode($5, a);
            a=makeChildNode("RPAREN", a);
            a=makeChildNode($7, a);
            $$ = a;
        }
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE { 
            print_rule("statement","IF LPAREN expression RPAREN statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1, "IF",a);
            a=makeChildNode("LPAREN",a);
            a=makeChildNode($3,a);
            a=makeChildNode("RPAREN",a);
            a=makeChildNode($5,a);
            $$ = a;
        }
	  | IF LPAREN expression RPAREN statement ELSE statement {

            print_rule("statement","IF LPAREN expression RPAREN statement ELSE statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1, "IF",a);
            a=makeChildNode("LPAREN",a);
            a=makeChildNode($3,a);
            a=makeChildNode("RPAREN",a);
            a=makeChildNode($1, "ELSE",a);
            a=makeChildNode($5,a);
            $$ = a;
        
        }
	  | WHILE LPAREN expression RPAREN statement {
            print_rule("statement","WHILE LPAREN expression RPAREN statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,"WHILE",a);
            $$ = a;
        }
	  | PRINTLN LPAREN ID RPAREN SEMICOLON {
            print_rule("statement","PRINTLN LPAREN ID RPAREN SEMICOLON");

            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,"PRINTLN",a);
            a=makeChildNode("LPAREN",a);
            a=makeChildNode($3,a);
            a=makeChildNode("RPAREN",a);
            a=makeChildNode("SEMICOLON",a);
            $$ = a;


            SymbolInfo* si = sym_tab->_search($3->lexeme);

            if(si == NULL)
            {
                fprintf(errout, "Line# %d: Undeclared variable \'%s\'\n", line_count, ($3->lexeme).data());
                err_count++;
                strcpy($$->resultType,"NULL");
            }
            
        }
	  | RETURN expression SEMICOLON {
            print_rule("statement","RETURN expression SEMICOLON");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode("RETURN",a);
            a=makeChildNode($2,a);
            a=makeChildNode("SEMICOLON",a);
            $$ = a;
        }
	  ;
	  
expression_statement: SEMICOLON	{
                    print_rule("expression_statement","SEMICOLON");
                    ptnode *a = getNewNode();
                    strcpy(a->token,"expression_statement");
                    a=makeChildNode("SEMICOLON",a);
                    $$ = a;
                }		
			| expression SEMICOLON {
                    print_rule("expression_statement","expression SEMICOLON");
                    ptnode *a = getNewNode();
                    strcpy(a->token,"expression_statement");
                    a=makeChildNode($1,a);
                    a=makeChildNode("SEMICOLON",a);
                    $$ = a;
                }
			;
	  
variable: ID { 
            print_rule("variable","ID");

            ptnode *a = getNewNode();
            strcpy(a->token,"variable");
            a=makeChildNode($1,a);
            $$ = a;


            SymbolInfo* si = sym_tab->_search($1->lexeme);

            if(si == NULL)
            {
                fprintf(errout, "Line# %d: Undeclared variable \'%s\'\n", line_count, ($1->lexeme).data());
                err_count++;
                strcpy($$->resultType, "NULL");
            }
            else
            {
                if(si->data_type == "int_array" || si->data_type == "float_array")
                {
                    type_conflict_error(si->lexeme);
                    strcpy($$->resultType, "NULL");
                }
                else{
                    strcpy($$->resultType, si->data_type.c_str());
                }
            }

        }		
	 | ID LTHIRD expression RTHIRD {
            print_rule("variable","ID LTHIRD expression RTHIRD");

            ptnode *a = getNewNode();
            strcpy(a->token,"variable");
            a=makeChildNode($1,a);
            a=makeChildNode("LTHIRD",a);
            a=makeChildNode($3,a);
            a=makeChildNode("RTHIRD",a);
            $$ = a;


            SymbolInfo* si = sym_tab->_search($1->lexeme);

            if(si == NULL)
            {
                fprintf(errout, "Line# %d: Undeclared variable \'%s\'\n", line_count, ($1->lexeme).data());
                err_count++;
                strcpy($$->resultType, "NULL");
            }
            else
            {
                if(si->data_type == "int" || si->data_type == "float")
                {
                    fprintf(errout, "Line# %d: \'%s\' is not an array\n", line_count, (si->lexeme).data());
                    err_count++;
                    strcpy($$->resultType, "NULL");
                }
                else{
                    strcpy($$->resultType, si->data_type.c_str());
                }
            }

            if(strcmp($3->resultType, "int"))
            {
                fprintf(errout, "Line# %d: Array subscript is not an integer\n", line_count);
                err_count++;
            }
         }
	 ;
	 
 expression: logic_expression	{
                print_rule("expression","logic_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"expression");
                a=makeChildNode($1,a);
                $$ = a;


                strcpy($$->resultType, $1->resultType);
            }
	   | variable ASSIGNOP logic_expression {
                print_rule("expression","variable ASSIGNOP logic_expression");

                ptnode *a = getNewNode();
                strcpy(a->token,"expression");
                a=makeChildNode($1,a);
                a=makeChildNode("ASSIGNOP",a);
                a=makeChildNode($3,a);
                $$ = a;

                if(!is_assignment_valid($1->resultType,$3->resultType))
                {
                    if(strcmp($1->resultType,"void")==0 || strcmp($3->resultType,"void")==0)
                    {
                        void_expression_error();
                    }
                    else if((!strcmp($1->resultType,"int") || !strcmp($1->resultType,"int_array")) && 
                            (!strcmp($3->resultType,"float") || !strcmp($3->resultType,"float_array")))
                    {
                        fprintf(errout, "Line# %d: Warning: possible loss of data in assignment of FLOAT to INT\n", line_count);
                        err_count++;
                    }
                }
            }	
	   ;


			 
logic_expression: rel_expression {
                print_rule("logic_expression","rel_expression"); 
                ptnode *a = getNewNode();
                strcpy(a->token,"logic_expression");
                a=makeChildNode($1,a);
                $$ = a;


                strcpy($$->resultType, $1->resultType);
            }	
		 | rel_expression LOGICOP rel_expression {
                print_rule("logic_expression","rel_expression LOGICOP rel_expression");

                ptnode *a = getNewNode();
                strcpy(a->token,"logic_expression");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode($3,a);
                $$ = a;


                string typecast_ret = typecast($1->resultType,$3->resultType);

                if(typecast_ret != "NULL")
                {
                    if(typecast_ret != "error") strcpy($$->resultType,"int");
                    else {

                        if(!strcmp($1->resultType, "void") || !strcmp($3->resultType, "void"))
                        {
                            void_expression_error();
                        }
                        else
                        {
                            typecast_error();
                        }

                        strcpy($$->resultType, "NULL");
                    }
                }
                else
                {
                    strcpy($$->resultType, "NULL");
                }
            }	
		 ;
			
rel_expression: simple_expression {
                print_rule("rel_expression","simple_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"rel_expression");
                a=makeChildNode($1,a);
                $$ = a;


                strcpy($$->resultType, $1->resultType);
            }
		| simple_expression RELOP simple_expression	{
                print_rule("rel_expression","simple_expression RELOP simple_expression");

                ptnode *a = getNewNode();
                strcpy(a->token,"rel_expression");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode($3,a);
                $$ = a;


                string typecast_ret = typecast($1->resultType,$3->resultType);

                if(typecast_ret != "NULL")
                {
                    if(typecast_ret != "error") strcpy($$->resultType, "int");
                    else {

                        if(!strcmp($1->resultType, "void") || !strcmp($3->resultType, "void"))
                        {
                            void_expression_error();
                        }
                        else
                        {
                            typecast_error();
                        }

                        strcpy($$->resultType, "NULL");
                    }
                }
                else
                {
                    strcpy($$->resultType, "NULL");
                }
            }
		;
				
simple_expression: term {

                    print_rule("simple_expression","term");
                    ptnode *a = getNewNode();
                    strcpy(a->token,"simple_expression");
                    a=makeChildNode($1,a);
                    $$ = a;

    
                    strcpy($$->resultType, $1->resultType);
            }
		    |   simple_expression ADDOP term {
                    print_rule("simple_expression","simple_expression ADDOP term");

                    ptnode *a = getNewNode();
                    strcpy(a->token,"simple_expression");
                    a=makeChildNode($1,a);
                    a=makeChildNode($2,a);
                    a=makeChildNode($3,a);
                    $$ = a;

                    string typecast_ret = typecast($1->resultType,$3->resultType);

                    if(typecast_ret != "NULL")
                    {
                        if(typecast_ret != "error")     strcpy($$->resultType, typecast_ret.c_str());
                        else {
                            if(!strcmp($1->resultType, "void") || !strcmp($3->resultType, "void"))
                            {
                                void_expression_error();
                            }
                            else
                            {
                                typecast_error();
                            }

                            strcpy($$->resultType, "NULL");
                        }
                    }
                    else
                    {
                        strcpy($$->resultType, "NULL");
                    }
            }
		    ;
					
term:	unary_expression {

            print_rule("term","unary_expression");
            ptnode *a = getNewNode();
            strcpy(a->token,"term");
            a=makeChildNode($1,a);
            $$ = a;


            strcpy($$->resultType, $1->resultType);
    }
    |  term MULOP unary_expression {

            print_rule("term","term MULOP unary_expression");

            ptnode *a = getNewNode();
            strcpy(a->token,"term");
            a=makeChildNode($1,a);
            a=makeChildNode($2,a);
            a=makeChildNode($3,a);
            $$ = a;


            string typecast_ret = typecast($1->resultType,$3->resultType);

            if($2->lexeme == "%")
            {
                if(!strcmp($3->value,"0"))
                {
                    fprintf(errout, "Line# %d: Warning: modulus by zero\n", line_count);
                    err_count++;
                    strcpy($$->resultType, "NULL");
                }
                else
                {
                    if(typecast_ret != "int")
                    {
                        fprintf(errout, "Line# %d: Operands of modulus must be integers\n", line_count);
                        err_count++;
                        strcpy($$->resultType, "NULL");
                    }
                    else{
                        strcpy($$->resultType, "int");
                    }
                }
            }
            else
            {
                if(typecast_ret != "NULL")
                {
                    if(typecast_ret != "error") strcpy($$->resultType, typecast_ret.c_str());
                    else {
                        if(strcmp($1->resultType, "void")==0 || strcmp($3->resultType, "void")==0)
                        {
                            void_expression_error();
                        }
                        else
                        {
                            typecast_error();
                        }

                        strcpy($$->resultType, "NULL");
                    }
                }
                else
                {
                    strcpy($$->resultType, "NULL");
                }
            }
    }
    ;

unary_expression: ADDOP unary_expression  {
                print_rule("unary_expression","ADDOP unary_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"unary_expression");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                $$ = a;
    
                strcpy($$->resultType, $2->resultType);
            }
		    | NOT unary_expression {
                print_rule("unary_expression","NOT unary_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"unary_expression");
                a=makeChildNode("NOT",a);
                a=makeChildNode($2,a);
                $$ = a;
    
                strcpy($$->resultType, $2->resultType);
            }
		    | factor  { 
                print_rule("unary_expression","factor");
                ptnode *a = getNewNode();
                strcpy(a->token,"unary_expression");
                a=makeChildNode($1,a);
                $$ = a;
                strcpy($$->value, $1->value);
    
                strcpy($$->resultType, $1->resultType);
            }
		 ;
	
factor: variable {

            print_rule("factor","variable");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            $$ = a;


            strcpy($$->resultType, $1->resultType);
        }
	| ID LPAREN argument_list RPAREN {

            print_rule("factor","ID LPAREN argument_list RPAREN");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            a=makeChildNode("LPAREN",a);
            a=makeChildNode($3,a);
            a=makeChildNode("RPAREN",a);
            $$ = a;


            SymbolInfo* si = sym_tab->_search($1->lexeme);

            if(si == NULL)
            {
                fprintf(errout, "Line# %d: Undeclared function \'%s\'\n", line_count, ($1->lexeme).data());
                err_count++;
                strcpy($$->resultType,"NULL");
            }
            else
            {
                if(si->isFunc == false)
                {
                    strcpy($$->resultType,"NULL");
                    fprintf(errout, "Line# %d: %s not a function\n", line_count, ($1->lexeme).data());
                    err_count++;
                }

                //convert data_type to lowercase and pass it up as resultType of 'factor'
                char *temp = new char(100);
                strcpy(temp, si->data_type.c_str());
                for(int i = 0; i < 100; i++)    temp[i] = tolower(temp[i]);
                strcpy($$->resultType, temp);
                free(temp);
                //

                if(si->isFuncDecl)
                {
                    fprintf(errout, "Line# %d: Function declared, but not defined\n", line_count);
                    err_count++;
                }
                else
                {
                    if(($3->args_list.size() - si->args_list.size()) > 0){
                        fprintf(errout, "Line# %d: Too many arguments to function \'%s\'\n", line_count, (si->lexeme).data());
                        err_count++;
                    }
                    else if(($3->args_list.size() - si->args_list.size()) < 0){
                        fprintf(errout, "Line# %d: Too few arguments to function \'%s\'\n", line_count, (si->lexeme).data());
                        err_count++;
                    }
                    else
                    {
                        for(int i=0;i<si->args_list.size();i++)
                        {
                            if(!is_typecast_valid(si->args_list[i], $3->args_list[i])){
                                fprintf(errout, "Line# %d: Type mismatch for argument %d of \'%s\'\n", line_count, (i+1), (si->lexeme).data());
                                err_count++;
                            }
                        }
                    }
                }
            }
        }
	| LPAREN expression RPAREN {

            print_rule("factor","LPAREN expression RPAREN");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode("LPAREN",a);
            a=makeChildNode($2,a);
            a=makeChildNode("RPAREN",a);
            $$ = a;
        
            strcpy($$->resultType, $2->resultType);
        }
	| CONST_INT  { 
            print_rule("factor","CONST_INT");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            $$ = a;
            strcpy($$->value, $1->lexeme.c_str());
            strcpy($$->resultType, "int");
        }
	| CONST_FLOAT  { 
            print_rule("factor","CONST_FLOAT");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            $$ = a;
            strcpy($$->value, $1->lexeme.c_str());
            strcpy($$->resultType, "float");
        }
    | ERROR_FLOAT  { 
            print_rule("factor","ERROR_FLOAT");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            $$ = a;
            strcpy($$->value, $1->lexeme.c_str());
            strcpy($$->resultType, "NULL");
        }
	| variable INCOP {
            print_rule("factor","variable INCOP");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            a=makeChildNode("INCOP",a);
            $$ = a;
        }
	| variable DECOP {
            print_rule("factor","variable DECOP");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            a=makeChildNode("DECOP",a);
            $$ = a;
        }
	;
	
argument_list: arguments {
                    print_rule("argument_list","arguments");
                    ptnode *a = getNewNode();
                    strcpy(a->token,"argument_list");
                    a=makeChildNode($1,a);
                    $$ = a;
                    $$->args_list = $1->args_list; 
                }
			| {
                print_rule("argument_list","");
                ptnode *a = getNewNode();
                strcpy(a->token,"argument_list");
                $$ = a;
            }   
			;
	
arguments: arguments COMMA logic_expression {

                print_rule("arguments","arguments COMMA logic_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"arguments");
                a=makeChildNode($1,a);
                a=makeChildNode("COMMA",a);
                a=makeChildNode($3,a);
                $$ = a;


                $$->args_list = $1->args_list; 
                $$->args_list.push_back($3->resultType);
            }
	    | logic_expression {

                print_rule("arguments","logic_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"arguments");
                a=makeChildNode($1,a);
                $$ = a;


                strcpy($$->resultType, $1->resultType);
                $$->args_list.push_back($1->resultType);
            }
	    ;

%%

int main(int argc,char *argv[])
{
    if(argc!=2){
		printf("Please provide input file name and try again\n");
		return 0;
	}
	
	FILE *fin=fopen(argv[1],"r");
	if(fin==NULL){
		printf("Cannot open specified file\n");
		return 0;
	}

    logout = fopen("log.txt", "w");
	errout = fopen("error.txt", "w");
    parseout = fopen("parse.txt", "w");

    yyin=fin;
	yyparse();
    if(Root != NULL) printtree(Root);

    fprintf(logout, "Total lines: %d\n", line_count);
    fprintf(logout, "Total errors: %d\n", err_count);

    fclose(yyin);
    fclose(parseout);
    fclose(logout);
	fclose(errout);

    return 0;
}