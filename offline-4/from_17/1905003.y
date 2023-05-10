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
ofstream codeout;
ofstream opt_codeout;

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
    string code;
    string tempVar;
    string stk_offset;
    string text;
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

string cur_function_name = "";
void insert_to_symtable(SymbolInfo* func_id,char* ret_type)
{
    cur_function_name = func_id->lexeme;
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

	
///////////////////////////////////////
///////// MACHINE CODE GEN ////////////
string newWordVariable(string name)
{
    return name+" dw ?";
}
int labelCount=0;
int tempCount=0;
vector<string>DATA_vector;
int SP_VAL = 0;
void incSP(int ara_size = -1)
{
    if(ara_size == -1) SP_VAL += 2;
    else SP_VAL += ara_size*2; // 2 for word
}
char *newLabel()
{
	char *lb= new char[4];
	strcpy(lb,"L");
	char b[3];
	sprintf(b,"%d", labelCount);
	labelCount++;
	strcat(lb,b);
	return lb;
}
char *newTemp()
{
	char *t= new char[4];
	strcpy(t,"t");
	char b[3];
	sprintf(b,"%d", tempCount);
	tempCount++;
	strcat(t,b);
    incSP();
	return t;
}
string getJumpText(string relop)
{
    if(relop=="<") return "jl";
    if(relop=="<=") return "jle";
    if(relop==">") return "jg";
    if(relop==">=") return "jge";
    if(relop=="==") return "je";
    if(relop=="!=") return "jne";
}
string stk_address(string stk_offset)
{
    return "[bp-"+stk_offset+"]";
}
string stk_address_param(string stk_offset)
{
    return "[bp+"+stk_offset+"]";
}
string stk_address_typecast(string stk_offset)
{
    return "WORD PTR [bp-"+stk_offset+"]";
}
string cur_function_label(string name)
{
    return "L_"+name;
}
string process_global_variable(string str)
{
    vector<string> ret;
    char delim = '[';
    size_t start;
    size_t end = 0;
    while ((start = str.find_first_not_of(delim, end)) != string::npos)
    {
        end = str.find(delim, start);
        ret.push_back(str.substr(start, end - start));
    }
    int sz = ret.size();
    if(sz == 1) return ret[0];
    else return ret[0]+"[BX]";
}
vector<string> tokenize(string str,char delim)
{
    vector<string> ret;
    size_t start;
    size_t end = 0;
    while ((start = str.find_first_not_of(delim, end)) != string::npos)
    {
        end = str.find(delim, start);
        ret.push_back(str.substr(start, end - start));
    }
    return ret;
}
void optimize_code(string code)
{
    vector<string>line_v  = tokenize(code,'\n');
    int line_v_sz = line_v.size();
    string prev_line_cmd = "";
    vector<string>prev_line_token;
    for(int i=0;i<line_v_sz;i++)
    {
        string cur_line = line_v[i];
        vector<string>cur_line_token;
        if(cur_line[0] == ';')
        {
            opt_codeout<<cur_line<<endl;
            continue;
        }
        vector<string>token_v = tokenize(cur_line,' ');
        if(token_v[0] == "MOV" || token_v[0]=="mov")
        {
            if(token_v[1] == "WORD")
            {
                cur_line_token = tokenize(token_v[3],',');
            }
            else
            {
                cur_line_token = tokenize(token_v[1],',');
            }
            if(prev_line_cmd == "MOV" || prev_line_cmd == "mov")
            {
                
                if(i>0)
                {
                    // for(auto x:prev_line_token)
                    //     cout<<x<<endl;
                    // cout<<endl;
                    // cout<<"---"<<endl;
                    // cout<<endl;
                    // for(auto x:cur_line_token)
                    //     cout<<x<<endl;
                    // cout<<"==========="<<endl;
                    if(cur_line_token[0] == prev_line_token[1] && cur_line_token[1] == prev_line_token[0])
                    {
                        // optimize
                    }
                    else 
                    {
                        opt_codeout<<cur_line<<endl;
                    }
                }
                else
                {
                    opt_codeout<<cur_line<<endl;
                }
            }
            else
            {
               opt_codeout<<cur_line<<endl; 
            }
            prev_line_token = cur_line_token;
        }
        else
        {
            int sz_token_v = token_v.size();
            if(sz_token_v >= 2)
            {
                if(token_v[1] == "PROC")
                    opt_codeout<<endl;
            }
            opt_codeout<<cur_line<<endl;
            prev_line_token.clear();
        }
        
        prev_line_cmd = token_v[0];
        
    }
}
vector<string>temp_SP_vector;
bool isATempVariable(string s)
{
    for(string x:temp_SP_vector)
        if(x == s) return true;
    return false;
}
///////////////////////////////////////

%}

%union{
    SymbolInfo* symInfo;
    char* string;
    struct ptnode *node;
}

%token <string> IF ELSE LOWER_THAN_ELSE FOR WHILE DO BREAK CHAR DOUBLE RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN INCOP DECOP ASSIGNOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
%token <symInfo> ID INT FLOAT VOID ADDOP MULOP RELOP LOGICOP CONST_CHAR CONST_INT CONST_FLOAT STRING ERROR_CHAR ERROR_FLOAT  
%type <node> start program unit variable var_declaration type_specifier func_declaration func_definition parameter_list expression factor unary_expression term simple_expression rel_expression statement statements compound_statement logic_expression expression_statement arguments argument_list declaration_list dummy_scope_function

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start: program
	{
		//write your code in this block in all the similar blocks below

        print_rule("start","program");

        Root = getNewNode();
        strcpy(Root->token,"start");
        Root = makeChildNode($1,Root);  Root->text = $1->text;

        strcpy(Root->resultType, $1->resultType);
        Root->code = $1->code;

        if(err_count == 0)
        {
            string asm_header = ".MODEL SMALL\n\n.STACK 100H";
            string output_proc = "\r\nOUTPUT PROC\r\n               \r\n        MOV CX , 0FH     \r\n        PUSH CX ; marker\r\n        \r\n        MOV IS_NEG, 0H\r\n        MOV AX , FOR_PRINT\r\n        TEST AX , 8000H\r\n        JE OUTPUT_LOOP\r\n                    \r\n        MOV IS_NEG, 1H\r\n        MOV AX , 0FFFFH\r\n        SUB AX , FOR_PRINT\r\n        ADD AX , 1H\r\n        MOV FOR_PRINT , AX\r\n\r\n    OUTPUT_LOOP:\r\n    \r\n        ;MOV AH, 1\r\n        ;INT 21H\r\n        \r\n        MOV AX , FOR_PRINT\r\n        XOR DX,DX\r\n        MOV BX , 10D\r\n        DIV BX ; QUOTIENT : AX  , REMAINDER : DX     \r\n        \r\n        MOV FOR_PRINT , AX\r\n        \r\n        PUSH DX\r\n        \r\n        CMP AX , 0H\r\n        JNE OUTPUT_LOOP\r\n        \r\n        ;LEA DX, NEWLINE ; DX : USED IN IO and MUL,DIV\r\n        ;MOV AH, 9 ; AH,9 used for character string output\r\n        ;INT 21H;\r\n\r\n        MOV AL , IS_NEG\r\n        CMP AL , 1H\r\n        JNE OP_STACK_PRINT\r\n        \r\n        MOV AH, 2\r\n        MOV DX, '-' ; stored in DL for display \r\n        INT 21H\r\n            \r\n        \r\n    OP_STACK_PRINT:\r\n    \r\n        ;MOV AH, 1\r\n        ;INT 21H\r\n    \r\n        POP BX\r\n        \r\n        CMP BX , 0FH\r\n        JE EXIT_OUTPUT\r\n        \r\n       \r\n        MOV AH, 2\r\n        MOV DX, BX ; stored in DL for display \r\n        ADD DX , 30H\r\n        INT 21H\r\n        \r\n        JMP OP_STACK_PRINT\r\n\r\n    EXIT_OUTPUT:\r\n    \r\n        ;POP CX \r\n\r\n        LEA DX, NEWLINE\r\n        MOV AH, 9 \r\n        INT 21H\r\n    \r\n        RET     \r\n      \r\nOUTPUT ENDP";
            codeout<<asm_header<<endl;
            codeout<<".DATA"<<endl;
            for(auto dv:DATA_vector) codeout<<dv<<endl;
            codeout<<endl;
            codeout<<".CODE"<<endl;
            // fileToCode(codeout,"output_proc.txt");
            codeout<<output_proc<<endl;
            codeout<<"\n"<<$$->code<<"\n"<<endl;
            ///////////
            opt_codeout<<asm_header<<endl;
            opt_codeout<<".DATA"<<endl;
            for(auto dv:DATA_vector) opt_codeout<<dv<<endl;
            opt_codeout<<endl;
            opt_codeout<<".CODE"<<endl;
            // fileToCode(opt_codeout,"output_proc.txt");
            opt_codeout<<output_proc<<endl;
            opt_codeout<<"\n"<<endl;
            optimize_code($$->code);
        }
	}
	;

program: program unit  {
            print_rule("program","program unit");
            ptnode *a = getNewNode();
            strcpy(a->token,"program");
            a=makeChildNode($1,a);
            a=makeChildNode($2,a);
            $$ = a;
            $$->text = $1->text;
            $$->text += "\n";
            $$->text += $2->text;

            // code
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
            $$->code = $1->code;
            $$->code += $2->code;
        }
	| unit { 
            print_rule("program","unit");
            ptnode *a = getNewNode();
            strcpy(a->token,"program");
            a=makeChildNode($1,a);
            $$ = a;
            $$->text = $1->text;

            strcpy($$->resultType, $1->resultType);
            // code
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
        }
	;
	
unit: var_declaration { 
            print_rule("unit","var_declaration"); 
            ptnode *a = getNewNode();
            strcpy(a->token,"unit");
            a=makeChildNode($1,a);
            $$ = a;
            $$->text = $1->text;

            strcpy($$->resultType, $1->resultType);
            // code
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
        }
     | func_declaration { 
            print_rule("unit","func_declaration"); 
            ptnode *a = getNewNode();
            strcpy(a->token,"unit");
            a=makeChildNode($1,a);
            $$ = a;
            $$->text = $1->text;

            // update type
            strcpy($$->resultType, $1->resultType);
            // code
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
            SP_VAL = 0;
        }
     | func_definition { 
            print_rule("unit","func_definition");
            ptnode *a = getNewNode();
            strcpy(a->token,"unit");
            a=makeChildNode($1,a);
            $$ = a;
            $$->text = $1->text;

            // update type
            strcpy($$->resultType, $1->resultType);
            // code
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
            SP_VAL = 0;
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
                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;
                $$->text += "(";
                $$->text += $4->text;
                $$->text += ")";
                $$->text += ";";

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

                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;
                $$->text += "(";
                $$->text += ")";
                $$->text += ";";


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

                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;
                $$->text += "(";
                $$->text += $4->text;
                $$->text += ")";
                $$->text += $7->text;

                // code
                $$->code = $2->lexeme+" PROC\n";
                if($2->lexeme =="main")
                {
                    $$->code += "MOV AX, @DATA\nMOV DS, AX\n";
                }
                $$->code += "PUSH BP\nMOV BP,SP\n";
                $$->code += "SUB SP,"+to_string(SP_VAL)+"\n";
                $$->code += $4->code+"\n";
                $$->code += $7->code+"\n";
                $$->code += cur_function_label(cur_function_name)+":\n";
                $$->code += "ADD SP,"+to_string(SP_VAL)+"\n";
                $$->code += "POP BP\n";
                if($2->lexeme =="main")
                {
                    $$->code += "\n;DOS EXIT\nMOV AH,4ch\nINT 21h\n";
                }
                else 
                {
                    $$->code += "RET\n";
                }
                $$->code += $2->lexeme +" ENDP\n\n";
                if($2->lexeme =="main") $$->code += "END MAIN\n";

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

                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;
                $$->text += "(";
                $$->text += ")";
                $$->text += $6->text;

                // code
                $$->code = $2->lexeme +" PROC\n";
                if($2->lexeme =="main")
                {
                    $$->code += "MOV AX, @DATA\nMOV DS, AX\n";
                }
                $$->code += "PUSH BP\nMOV BP,SP\n";
                $$->code += "SUB SP,"+to_string(SP_VAL)+"\n";
                $$->code += $6->code+"\n";
                $$->code += cur_function_label(cur_function_name)+":\n";
                $$->code += "ADD SP,"+to_string(SP_VAL)+"\n";
                $$->code += "POP BP\n";
                if($2->lexeme =="main")
                {
                    $$->code += "\n;DOS EXIT\nMOV AH,4ch\nINT 21h\n";
                }
                else 
                {
                    $$->code += "RET\n";
                }
                
                $$->code += $2->lexeme +" ENDP\n";
                if($2->lexeme =="main") $$->code += "END MAIN\n";

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

                // update text
                $$->text = $1->text;
                $$->text += ",";
                $$->text += $3->text;
                $$->text += " ";
                $$->text += $4->lexeme;

                $4->setDataType($3->value);
                $4->token = $3->token;
                $4->isFuncParam = true;
                temp_param_list.push_back(*$4);
            }
        | parameter_list COMMA type_specifier {
            print_rule("parameter_list","parameter_list COMMA type_specifier");
            ptnode *a = getNewNode();
            strcpy(a->token,"parameter_list");
            a=makeChildNode($1,a);
            a=makeChildNode("COMMA",a);
            a=makeChildNode($3,a);
            $$ = a;

            // update text
            $$->text = $1->text;
            $$->text += ",";
            $$->text += $3->text;

            SymbolInfo sym = SymbolInfo("some_name","some_val");
            sym.data_type = $3->value;
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

                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;

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
            // update text
            $$->text = $1->text;

            strcpy($$->resultType, $1->resultType);

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

                // update text
                $$->text = "{\n"; 
                $$->text += $3->text; 
                $$->text += "\n}";

                // code
                $$->code = $2->code;
                $$->code += $3->code;
                $$->tempVar = $3->tempVar;
                $$->stk_offset = $3->stk_offset;

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

                // update text
                $$->text = "{";  
                $$->text += "}"; 

                $$->code = $2->code;

                sym_tab->_print(logout,'A');
                sym_tab->exitScope();
             }
 		    ;
dummy_scope_function:  {
                    $$ = getNewNode();
                    sym_tab->enterScope(); 
                    $$->code = "";
                    int PP_Val = 4;

                    if(curr_ID_func)
                    {
                        for(auto &param : temp_param_list)
                        {
                            if(param.lexeme == "some_name") continue;
                            if(param.data_type == "void")
                            {
                                // error_var_type();
                                param.data_type = "NULL";
                            }

                            incSP();
                            param.stk_offset = to_string(SP_VAL);

                            if(!sym_tab->_insert(param))
                            {
                                mult_declaration_error(param.lexeme,param.isFuncParam);
                            }

                            $$->code += "MOV AX,"+stk_address_param(to_string(PP_Val))+"\n";
                            $$->code += "MOV "+stk_address_typecast(param.stk_offset)+",AX\n";
                            PP_Val+=2;
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

            // update text
            $$->text = $1->text;
            $$->text += " ";
            $$->text += $2->text;
            $$->text += ";";

            if(!strcmp($1->value,"void")){
                fprintf(errout, "Line# %d: Variable or field \'%s\' declared void\n", line_count, (($2->decl_list[0])->lexeme).data());
                err_count++;
            }
            else{
                for(auto var : $2->decl_list)
                {
                    if(var->data_type == "array")
                    {
                        var->setDataType(strcat($1->value, "_array")) ; var->token = "ARRAY";
                        if(sym_tab->getCurrentScopeID()!=1) // not global
                        {
                            incSP(var->ara_size);
                            var->stk_offset = to_string(SP_VAL);
                        }
                        else
                        {
                            DATA_vector.push_back(var->lexeme + " dw "+to_string(var->ara_size)+" dup ($)");
                        }
                    }
                    else 
                    {
                        var->setDataType($1->value); var->token = $1->token;
                        if(sym_tab->getCurrentScopeID()!=1) // not global
                        {
                            incSP();
                            var->stk_offset = to_string(SP_VAL);
                        }
                        else
                        {
                            DATA_vector.push_back(var->lexeme + " dw ?");
                        }
            
                    }
                    // if(var->data_type == "array") { var->setDataType(strcat($1->value, "_array")) ; var->token = "ARRAY";}
                    // else { var->setDataType($1->value); var->token = $1->token; }
                    
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
 		;
 		 
type_specifier: INT  { 
                    print_rule("type_specifier","INT"); 

                    ptnode *a = getNewNode();
                    strcpy(a->token,"type_specifier");
                    a=makeChildNode($1,a);
                    $$ = a;     $$->text = $1->lexeme;
                    strcpy($$->value,"int");
                    strcpy($$->token,"INT");
                }
 		| FLOAT { 
                    print_rule("type_specifier","FLOAT"); 

                    ptnode *a = getNewNode();
                    strcpy(a->token,"type_specifier");
                    a=makeChildNode($1,a);
                    $$ = a;     $$->text = $1->lexeme;
                    strcpy($$->value,"float");
                    strcpy($$->token,"FLOAT");
                }
 		| VOID { 
                    print_rule("type_specifier","VOID"); 
                    ptnode *a = getNewNode();
                    strcpy(a->token,"type_specifier");
                    a=makeChildNode($1,a);
                    $$ = a;     $$->text = $1->lexeme;
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
                    // update text
                    $$->text = $1->text;
                    $$->text += ",";
                    $$->text += $3->lexeme;
                    
                    strcpy($$->resultType, $1->resultType);

                    $$->decl_list= $1->decl_list;
                    $$->decl_list.push_back($3);
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
                // update text
                $$->text = $1->text;
                $$->text += ",";
                $$->text += $3->lexeme;
                $$->text += "[";
                $$->text += $5->lexeme;
                $$->text += "]";
                
                strcpy($$->resultType, $1->resultType);
                
                $$->decl_list= $1->decl_list;
                $3->token ="ARRAY";
                $3->data_type ="array";
                $3->ara_size = stoi($5->lexeme);
                $$->decl_list.push_back($3);
           }
 		    | ID {     
                    print_rule("declaration_list","ID");

                    ptnode *a = getNewNode();
                    strcpy(a->token,"declaration_list");
                    a=makeChildNode($1,a);
                    $$ = a;
                    // update text
                    $$->text = $1->lexeme;
                    
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
                    // update text
                    $$->text = $1->lexeme;
                    $$->text += "[";
                    $$->text += $3->lexeme;
                    $$->text += "]";
                    
                    $1->token = "ARRAY";
                    $1->data_type ="array";
                    $1->ara_size = stoi($3->lexeme);
                    $$->decl_list.push_back($1);
            }
 		  ;
 		  
statements: statement {
            print_rule("statements","statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statements");
            a=makeChildNode($1,a);
            $$ = a;
            $$->text = $1->text;
            
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
        }
	   | statements statement {
            print_rule("statements","statements statement");
        
            ptnode *a = getNewNode();
            strcpy(a->token,"statements");
            a=makeChildNode($1,a);
            a=makeChildNode($2,a);
            $$ = a;
            $$->text = $1->text;
            $$->text += "\n";
            $$->text += $2->text;

            $$->code = $1->code+"\n";
            $$->code += $2->code;
        }
	   ;
	   
statement: var_declaration {
            print_rule("statement","var_declaration");

            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;     $$->text = $1->text;

            strcpy($$->resultType, $1->resultType);
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
        }
      | func_definition {
            print_rule("statement","func_definition");

            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;     $$->text = $1->text;

            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
      }
      | func_declaration {
            print_rule("statement","func_declaration");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;     $$->text = $1->text;

            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
      }
	  | expression_statement {
            print_rule("statement","expression_statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;     $$->text = $1->text;

            strcpy($$->resultType, $1->resultType);
            $$->code = "; " + $$->text +"\n";
            $$->code += $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
        }
	  | compound_statement {
            print_rule("statement","compound_statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,a);
            $$ = a;     $$->text = $1->text;

            strcpy($$->resultType, $1->resultType);
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
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

            // update text
            $$->text = "for";
            $$->text += "(";
            $$->text += $3->text;
            $$->text += $4->text;
            $$->text += $5->text;
            $$->text += ")";
            $$->text += $7->text;

            string tempL1 = newLabel();
            string tempL2 = newLabel();
            string to_print = $$->text;
            to_print.erase(remove(to_print.begin(), to_print.end(), '\n'), to_print.end());
            $$->code = "; "+to_print+"\n";
            $$->code += $3->code+"\n";
            $$->code += tempL1+":\n"; // loop starting label
            $$->code += "; "+$4->text+"\n";
            $$->code += $4->code+"\n"; // eval expression
            $$->code += "; check for loop condition\n";
            $$->code += "CMP "+ stk_address($4->stk_offset)+",0\n"; // check if need to exit
            $$->code += "JE "+tempL2+"\n"; // check if need to exit
            $$->code += $7->code+"\n";  // exec statement
            $$->code += "; "+$5->text+"\n";  // exec statement
            $$->code += $5->code+"\n";  // exec statement
            $$->code += "JMP "+tempL1+"\n"; // loop
            $$->code += tempL2+":\n"; // loop ending label
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

            // update text
            $$->text = "if";
            $$->text += "(";
            $$->text += $3->text;
            $$->text += ")";
            $$->text += $5->text;

            string to_print = $$->text;
            to_print.erase(remove(to_print.begin(), to_print.end(), '\n'), to_print.end());
            $$->code = "; "+to_print+"\n";
            $$->code += $3->code+"\n";
            
            string tempL1 = newLabel();
            $$->code += "CMP "+stk_address($3->stk_offset)+",0\n";
            $$->code += "JE "+tempL1+"\n";
            $$->code += $5->code+"\n";
            $$->code += tempL1+":\n";
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

            // update text
            $$->text = "if";
            $$->text += "(";
            $$->text += $3->text;
            $$->text += ")";
            $$->text += $5->text;
            $$->text += "\nelse ";
            $$->text += $7->text;

            string to_print = $$->text;
            to_print.erase(remove(to_print.begin(), to_print.end(), '\n'), to_print.end());
            $$->code = "; "+to_print+"\n";
            $$->code += $3->code+"\n";
            
            string tempL1 = newLabel();
            string tempL2 = newLabel();
            $$->code += "CMP "+stk_address($3->stk_offset)+",0\n";
            $$->code += "JE "+tempL1+"\n";
            $$->code += $5->code+"\n";
            $$->code += "JMP "+tempL2+"\n";
            $$->code += tempL1+":\n";
            $$->code += $7->code+"\n";
            $$->code += tempL2+":\n";
        
        }
	  | WHILE LPAREN expression RPAREN statement {
            print_rule("statement","WHILE LPAREN expression RPAREN statement");
            ptnode *a = getNewNode();
            strcpy(a->token,"statement");
            a=makeChildNode($1,"WHILE",a);
            $$ = a;

            // update text
            $$->text = "while";
            $$->text += "(";
            $$->text += $3->text;
            $$->text += ")";
            $$->text += $5->text;

            string tempL1 = newLabel();
            string tempL2 = newLabel();
            string to_print = $$->text;
            to_print.erase(remove(to_print.begin(), to_print.end(), '\n'), to_print.end());
            $$->code = "; "+to_print+"\n";
            $$->code += tempL1+":\n"; // loop starting label
            $$->code += "; "+$3->text+"\n";
            $$->code += $3->code+"\n"; // eval expression
            $$->code += "; check while loop condition\n";
            $$->code += "CMP "+ stk_address($3->stk_offset) +",0\n"; // check if need to exit
            $$->code += "JE "+tempL2+"\n"; // check if need to exit
            $$->code += $5->code+"\n";  // exec statement
            $$->code += "JMP "+tempL1+"\n"; // loop
            $$->code += tempL2+":\n"; // loop ending label
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

            $$->text = "printf";
            $$->text += "(";
            $$->text += $3->lexeme;
            $$->text += ")";
            $$->text += ";";


            SymbolInfo* si = sym_tab->_search($3->lexeme);

            if(si == NULL)
            {
                fprintf(errout, "Line# %d: Undeclared variable \'%s\'\n", line_count, ($3->lexeme).data());
                err_count++;
                strcpy($$->resultType,"NULL");
            }
            $$->code = "\n; "+$$->text+"\n";
            
            if(si != NULL && si->stk_offset != "") $$->code += "MOV AX,"+stk_address(si->stk_offset)+"\n";
            else $$->code += "MOV AX,"+$3->lexeme+"\n";
            
            $$->code += "MOV FOR_PRINT,AX\n";
            $$->code += "CALL OUTPUT";
        }
        | PRINTLN LPAREN ID LTHIRD expression RTHIRD RPAREN SEMICOLON {
            print_rule("statement","PRINTLN LPAREN ID RPAREN SEMICOLON");
            $$->text = "printf";
            $$->text += "(";
            $$->text += $3->lexeme;
            $$->text += "[";
            $$->text += $5->text;
            $$->text += "]";
            $$->text += ")";
            $$->text += ";";
            // check error
            SymbolInfo* si = sym_tab->_search($3->lexeme);
            if(si == NULL)
            {
                fprintf(errout, "Line# %d: Undeclared variable \'%s\'\n", line_count, ($3->lexeme).data());
                err_count++;
                strcpy($$->resultType,"NULL");
            }
            if(si != NULL)
            {
                $$->code = "\n; "+$$->text+"\n";
                // code
                $$->code += $5->code+"\n";
                $$->stk_offset = si->stk_offset+"+SI";
                if(si->stk_offset != "")
                {
                    $$->code += "MOV SI,"+stk_address($5->stk_offset)+"\n";
                    $$->code += "ADD SI,SI\n";
                    $$->code += "MOV AX,"+stk_address($$->stk_offset)+"\n";
                }
                else
                {   $$->code += "MOV BX,"+stk_address($5->stk_offset)+"\n";
                    $$->code += "ADD BX,BX\n";
                    $$->code += "MOV AX,"+$3->lexeme+"[BX]\n";
                }
                $$->code += "MOV FOR_PRINT,AX\n";
                $$->code += "CALL OUTPUT";
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

            $$->text = "return";
            $$->text += " ";
            $$->text += $2->text;
            $$->text += ";";

            $$->code = "; "+$$->text+"\n";
            $$->code += $2->code+"\n";
            
            if($2->stk_offset != "") $$->code += "MOV AX,"+stk_address($2->stk_offset)+"\n";
            else {
                $$->code += "MOV AX,"+ process_global_variable($2->text)+"\n";
            } 
            $$->code += "JMP "+cur_function_label(cur_function_name)+"\n";
        }
	  ;
	  
expression_statement: SEMICOLON	{
                    print_rule("expression_statement","SEMICOLON");
                    ptnode *a = getNewNode();
                    strcpy(a->token,"expression_statement");
                    a=makeChildNode("SEMICOLON",a);
                    $$ = a;     $$->text = ";";
                }		
			| expression SEMICOLON {
                    print_rule("expression_statement","expression SEMICOLON");
                    ptnode *a = getNewNode();
                    strcpy(a->token,"expression_statement");
                    a=makeChildNode($1,a);
                    a=makeChildNode("SEMICOLON",a);
                    $$ = a;

                    // update text
                    $$->text = $1->text;
                    $$->text += ";";

                    $$->code = $1->code;
                    $$->tempVar = $1->tempVar;
                    $$->stk_offset = $1->stk_offset;
                }
			;
	  
variable: ID { 
            print_rule("variable","ID");

            ptnode *a = getNewNode();
            strcpy(a->token,"variable");
            a=makeChildNode($1,a);
            $$ = a;

            // update text
            $$->text = $1->lexeme;

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

            $$->code = "";
            $$->tempVar = $1->lexeme;
            if(si != NULL) $$->stk_offset = si->stk_offset;
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

            // update text
            $$->text = $1->lexeme;
            $$->text += "[";
            $$->text += $3->text;
            $$->text += "]";

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

            if(si != NULL)
            {
                // code
                $$->code = $3->code+"\n";
                if(si->stk_offset!="")
                {
                    $$->code += "MOV SI,"+stk_address($3->stk_offset)+"\n";
                    $$->code += "ADD SI,SI";
                    $$->stk_offset = si->stk_offset+"+SI";
                }
                else
                {
                    $$->code += "MOV BX,"+stk_address($3->stk_offset)+"\n";
                    $$->code += "ADD BX,BX";
                    //$$->stk_offset = si->stk_offset+"+SI";
                }
            }
         }
	 ;
	 
 expression: logic_expression	{
                print_rule("expression","logic_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"expression");
                a=makeChildNode($1,a);
                $$ = a;

                // update text
                $$->text = $1->text;

                strcpy($$->resultType, $1->resultType);
                $$->code = $1->code;
                $$->tempVar = $1->tempVar;
                $$->stk_offset = $1->stk_offset;
            }
	   | variable ASSIGNOP logic_expression {
                print_rule("expression","variable ASSIGNOP logic_expression");

                ptnode *a = getNewNode();
                strcpy(a->token,"expression");
                a=makeChildNode($1,a);
                a=makeChildNode("ASSIGNOP",a);
                a=makeChildNode($3,a);
                $$ = a;

                // update text
                $$->text = $1->text;
                $$->text += "=";
                $$->text += $3->text;

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

                $$->code = $3->code+"\n";
                if($3->stk_offset != "") $$->code += "MOV CX,"+stk_address($3->stk_offset)+"\n";
                else $$->code += "MOV CX,"+process_global_variable($3->text)+"\n";
                if($1->code != "") $$->code += $1->code+"\n";
                if($1->stk_offset != "") $$->code += "MOV "+stk_address_typecast($1->stk_offset)+",CX";
                else $$->code += "MOV "+process_global_variable($1->text)+",CX";
            }	
	   ;


			 
logic_expression: rel_expression {
                print_rule("logic_expression","rel_expression"); 
                ptnode *a = getNewNode();
                strcpy(a->token,"logic_expression");
                a=makeChildNode($1,a);
                $$ = a;

                // update text
                $$->text = $1->text;

                strcpy($$->resultType, $1->resultType);
                $$->code = $1->code;
                $$->tempVar = $1->tempVar;
                $$->stk_offset = $1->stk_offset;
            }	
		 | rel_expression LOGICOP rel_expression {
                print_rule("logic_expression","rel_expression LOGICOP rel_expression");

                ptnode *a = getNewNode();
                strcpy(a->token,"logic_expression");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode($3,a);
                $$ = a;

                // update text
                $$->text = $1->text;
                $$->text += $2->lexeme;
                $$->text += $3->text;

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

                if($2->lexeme == "&&")
                {
                    // code for &&
                    $$->code = $1->code+"\n";
                    $$->code += $3->code+"\n";
                    if($1->stk_offset != "") $$->code += "CMP "+ stk_address($1->stk_offset)+",0\n";
                    else  $$->code += "CMP "+ process_global_variable($1->text)+",0\n";
                    string tempL1 = newLabel();
                    string tempL2 = newLabel();
                    $$->code += "JE "+tempL1+"\n";
                    if($3->stk_offset != "") $$->code += "CMP "+stk_address($3->stk_offset)+",0\n";
                    else $$->code += "CMP "+process_global_variable($3->text)+",0\n";
                    $$->code += "JE "+tempL1+"\n";
                    if(isATempVariable($1->stk_offset))
                    {
                        $$->stk_offset = $1->stk_offset;
                    }
                    else if(isATempVariable($3->stk_offset))
                    {
                        $$->stk_offset = $3->stk_offset;
                    }
                    else
                    {
                        string tempVar = newTemp();
                        $$->tempVar = tempVar;
                        $$->stk_offset = to_string(SP_VAL);
                        // temp_SP_vector.push_back(to_string(SP_VAL));
                    }
                    $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",1\n";
                    $$->code += "JMP "+tempL2+"\n";
                    $$->code += tempL1+":\n";
                    $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",0\n";
                    $$->code += tempL2+":\n";
                    
                }
                else if($2->lexeme == "||")
                {
                    // code for ||
                    $$->code = $1->code+"\n";
                    $$->code += $3->code+"\n";
                    if($1->stk_offset != "") $$->code += "CMP "+stk_address($1->stk_offset)+",0\n";
                    else  $$->code += "CMP "+process_global_variable($1->text)+",0\n";
                    string tempL1 = newLabel();
                    string tempL2 = newLabel();
                    $$->code += "JNE "+tempL1+"\n";
                    if($3->stk_offset != "") $$->code += "CMP "+stk_address($3->stk_offset)+",0\n";
                    else $$->code += "CMP "+process_global_variable($3->text)+",0\n";
                    $$->code += "JNE "+tempL1+"\n";
                    if(isATempVariable($1->stk_offset))
                    {
                        $$->stk_offset = $1->stk_offset;
                    }
                    else if(isATempVariable($3->stk_offset))
                    {
                        $$->stk_offset = $3->stk_offset;
                    }
                    else
                    {
                        string tempVar = newTemp();
                        $$->tempVar = tempVar;
                        $$->stk_offset = to_string(SP_VAL);
                        // temp_SP_vector.push_back(to_string(SP_VAL));
                    }
                    $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",0\n";
                    $$->code += "JMP "+tempL2+"\n";
                    $$->code += tempL1+":\n";
                    $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",1\n";
                    $$->code += tempL2+":\n";
                }
            }	
		 ;
			
rel_expression: simple_expression {
                print_rule("rel_expression","simple_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"rel_expression");
                a=makeChildNode($1,a);
                $$ = a;

                // update text
                $$->text = $1->text;

                strcpy($$->resultType, $1->resultType);
                $$->code = $1->code;
                $$->tempVar = $1->tempVar;
                $$->stk_offset = $1->stk_offset;
            }
		| simple_expression RELOP simple_expression	{
                print_rule("rel_expression","simple_expression RELOP simple_expression");

                ptnode *a = getNewNode();
                strcpy(a->token,"rel_expression");
                a=makeChildNode($1,a);
                a=makeChildNode($2,a);
                a=makeChildNode($3,a);
                $$ = a;

                // update text
                $$->text = $1->text;
                $$->text += $2->lexeme;
                $$->text += $3->text;


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

                string jumpText = getJumpText($2->lexeme);
                // code 
                $$->code = $1->code+"\n";
                $$->code += $3->code+"\n";
                if($1->stk_offset != "") $$->code += "MOV AX,"+stk_address($1->stk_offset)+"\n";
                else $$->code += "MOV AX,"+process_global_variable($1->text)+"\n";
                if($3->stk_offset != "") $$->code += "CMP AX,"+stk_address($3->stk_offset)+"\n";
                else $$->code += "CMP AX,"+process_global_variable($3->text)+"\n";
                string tempL1 = newLabel();
                string tempL2 = newLabel();
                if(isATempVariable($1->stk_offset))
                {
                    $$->stk_offset = $1->stk_offset;
                }
                else if(isATempVariable($3->stk_offset))
                {
                    $$->stk_offset = $3->stk_offset;
                }
                else
                {
                    string tempVar = newTemp();
                    $$->tempVar = tempVar;
                    $$->stk_offset = to_string(SP_VAL);
                    // // temp_SP_vector.push_back(to_string(SP_VAL));
                }
                $$->code += jumpText+" "+tempL1+"\n";
                $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",0"+"\n";
                $$->code += "JMP "+tempL2+"\n";
                $$->code += tempL1+":\n";
                $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",1"+"\n";
                $$->code += tempL2+":\n";
            }
		;
				
simple_expression: term {

                    print_rule("simple_expression","term");
                    ptnode *a = getNewNode();
                    strcpy(a->token,"simple_expression");
                    a=makeChildNode($1,a);
                    $$ = a;
                    $$->text = $1->text;

                    strcpy($$->resultType, $1->resultType);
                    $$->code = $1->code;
                    $$->tempVar = $1->tempVar;
                    $$->stk_offset = $1->stk_offset;
            }
		    |   simple_expression ADDOP term {
                    print_rule("simple_expression","simple_expression ADDOP term");

                    ptnode *a = getNewNode();
                    strcpy(a->token,"simple_expression");
                    a=makeChildNode($1,a);
                    a=makeChildNode($2,a);
                    a=makeChildNode($3,a);
                    $$ = a;

                    // update text
                    $$->text = $1->text;
                    $$->text += $2->lexeme;
                    $$->text += $3->text;

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

                    if($2->lexeme == "+")
                    {
                        // code for +
                        $$->code = $1->code+"\n";
                        
                        if($1->stk_offset!="") $$->code += "MOV AX,"+stk_address($1->stk_offset)+"\n";
                        else $$->code += "MOV AX,"+process_global_variable($1->text)+"\n";
                        string tempVarExtra = newTemp();
                        string tempVarExtra_stk_add = to_string(SP_VAL);
                        // temp_SP_vector.push_back(to_string(SP_VAL));
                        $$->code += "MOV "+stk_address_typecast(tempVarExtra_stk_add)+",AX\n";
                        $$->code += $3->code+"\n";
                        $$->code += "MOV AX,"+stk_address(tempVarExtra_stk_add)+"\n";
                        if($3->stk_offset!="") $$->code += "ADD AX,"+stk_address($3->stk_offset)+"\n";
                        else $$->code += "ADD AX,"+process_global_variable($3->text)+"\n";
                        if(isATempVariable($1->stk_offset))
                        {
                            $$->stk_offset = $1->stk_offset;
                        }
                        else if(isATempVariable($3->stk_offset))
                        {
                            $$->stk_offset = $3->stk_offset;
                        }
                        else
                        {
                            string tempVar = newTemp();
                            $$->tempVar = tempVar;
                            $$->stk_offset = to_string(SP_VAL);
                            // temp_SP_vector.push_back(to_string(SP_VAL));
                        }
                        $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",AX";
                    }
                    else
                    {
                        // code for -
                        $$->code = $1->code+"\n";
                        
                        if($1->stk_offset!="") $$->code += "MOV AX,"+stk_address($1->stk_offset)+"\n";
                        else $$->code += "MOV AX,"+process_global_variable($1->text)+"\n";
                        string tempVarExtra = newTemp();
                        string tempVarExtra_stk_add = to_string(SP_VAL);
                        // temp_SP_vector.push_back(to_string(SP_VAL));
                        $$->code += "MOV "+stk_address_typecast(tempVarExtra_stk_add)+",AX\n";
                        $$->code += $3->code+"\n";
                        
                        $$->code += "MOV AX,"+stk_address(tempVarExtra_stk_add)+"\n";
                        
                        if($3->stk_offset!="") $$->code += "SUB AX,"+stk_address($3->stk_offset)+"\n";
                        else $$->code += "SUB AX,"+process_global_variable($3->text)+"\n";
                        if(isATempVariable($1->stk_offset))
                        {
                            $$->stk_offset = $1->stk_offset;
                        }
                        else if(isATempVariable($3->stk_offset))
                        {
                            $$->stk_offset = $3->stk_offset;
                        }
                        else
                        {
                            string tempVar = newTemp();
                            $$->tempVar = tempVar;
                            $$->stk_offset = to_string(SP_VAL);
                            // temp_SP_vector.push_back(to_string(SP_VAL));
                        }
                        $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",AX";
                    }
            }
		    ;
					
term:	unary_expression {

            print_rule("term","unary_expression");
            ptnode *a = getNewNode();
            strcpy(a->token,"term");
            a=makeChildNode($1,a);
            $$ = a;
            $$->text = $1->text;

            strcpy($$->resultType, $1->resultType);
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
    }
    |  term MULOP unary_expression {

            print_rule("term","term MULOP unary_expression");

            ptnode *a = getNewNode();
            strcpy(a->token,"term");
            a=makeChildNode($1,a);
            a=makeChildNode($2,a);
            a=makeChildNode($3,a);
            $$ = a;

            $$->text = $1->text;
            $$->text += $2->lexeme;
            $$->text += $3->text;

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
                        // code
                        $$->code = $1->code+"\n";
                        
                        if($1->stk_offset!="") $$->code += "MOV CX,"+ stk_address($1->stk_offset)+"\n";
                        else $$->code += "MOV CX,"+process_global_variable($1->text)+"\n";
                        
                        $$->code += "CWD\n";
                        string tempVarExtra = newTemp();
                        string tempVarExtra_stk_add = to_string(SP_VAL);
                        // temp_SP_vector.push_back(to_string(SP_VAL));
                        $$->code += "MOV "+stk_address_typecast(tempVarExtra_stk_add)+",CX\n";
                        $$->code += $3->code+"\n";
                        
                        $$->code += "MOV CX,"+stk_address(tempVarExtra_stk_add)+"\n";
                        $$->code += "MOV AX,CX\n"; /// speacial case to handle noth array and normal variable
                        if($3->stk_offset!="") $$->code += "IDIV "+stk_address_typecast($3->stk_offset)+"\n";
                        else $$->code += "IDIV "+process_global_variable($3->text)+"\n";
                        if(isATempVariable($1->stk_offset))
                        {
                            $$->stk_offset = $1->stk_offset;
                        }
                        else if(isATempVariable($3->stk_offset))
                        {
                            $$->stk_offset = $3->stk_offset;
                        }
                        else
                        {
                            string tempVar = newTemp();
                            $$->tempVar = tempVar;
                            $$->stk_offset = to_string(SP_VAL);
                            // temp_SP_vector.push_back(to_string(SP_VAL));
                        }
                        $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",DX";
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

                if($2->lexeme == "*")
                {
                    // code for *
                    $$->code = $1->code+"\n";
                    if($1->stk_offset!="") $$->code += "MOV CX,"+stk_address($1->stk_offset)+"\n";
                    else $$->code += "MOV CX,"+process_global_variable($1->text)+"\n";
                    string tempVarExtra = newTemp();
                    string tempVarExtra_stk_add = to_string(SP_VAL);
                    // temp_SP_vector.push_back(to_string(SP_VAL));
                    $$->code += "MOV "+stk_address_typecast(tempVarExtra_stk_add)+",CX\n";
                    $$->code += $3->code+"\n";
                    
                    $$->code += "MOV CX,"+stk_address(tempVarExtra_stk_add)+"\n";
                    $$->code += "MOV AX,CX\n"; /// speacial case to handle noth array and normal variable
                    if($3->stk_offset!="") $$->code += "IMUL "+stk_address_typecast($3->stk_offset)+"\n";
                    else $$->code += "IMUL "+process_global_variable($3->text)+"\n";
                    if(isATempVariable($1->stk_offset))
                    {
                        $$->stk_offset = $1->stk_offset;
                    }
                    else if(isATempVariable($3->stk_offset))
                    {
                        $$->stk_offset = $3->stk_offset;
                    }
                    else
                    {
                        string tempVar = newTemp();
                        $$->tempVar = tempVar;
                        $$->stk_offset = to_string(SP_VAL);
                        // temp_SP_vector.push_back(to_string(SP_VAL));
                    }
                    $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",AX";
                }
                else if($2->lexeme == "/")
                {
                    // code
                    $$->code = $1->code+"\n";
                    if($1->stk_offset!="") $$->code += "MOV CX,"+ stk_address($1->stk_offset)+"\n";
                    else $$->code += "MOV CX,"+ process_global_variable($1->text)+"\n";
                    
                    $$->code += "CWD\n";
                    string tempVarExtra = newTemp();
                    string tempVarExtra_stk_add = to_string(SP_VAL);
                    // temp_SP_vector.push_back(to_string(SP_VAL));
                    $$->code += "MOV "+stk_address_typecast(tempVarExtra_stk_add)+",CX\n";
                    $$->code += $3->code+"\n";
                    
                    $$->code += "MOV CX,"+stk_address(tempVarExtra_stk_add)+"\n";
                    $$->code += "MOV AX,CX\n"; /// speacial case to handle noth array and normal variable
                    if($3->stk_offset!="") $$->code += "IDIV "+stk_address_typecast($3->stk_offset)+"\n";
                    else $$->code += "IDIV "+process_global_variable($3->text)+"\n";
                    if(isATempVariable($1->stk_offset))
                    {
                        $$->stk_offset = $1->stk_offset;
                    }
                    else if(isATempVariable($3->stk_offset))
                    {
                        $$->stk_offset = $3->stk_offset;
                    }
                    else
                    {
                        string tempVar = newTemp();
                        $$->tempVar = tempVar;
                        $$->stk_offset = to_string(SP_VAL);
                        // temp_SP_vector.push_back(to_string(SP_VAL));
                    }
                    $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",AX";
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

                // update text
                $$->text = $1->lexeme;
                $$->text += $2->text;
    
                strcpy($$->resultType, $2->resultType);
                if($1->lexeme == "+")
                {
                    $$->code = $2->code;
                    $$->tempVar = $2->tempVar;
                    $$->stk_offset = $2->stk_offset;
                }
                else
                {
                    $$->code = $2->code+"\n";
                    $$->code += "NEG "+stk_address_typecast($2->stk_offset);
                    $$->tempVar = $2->tempVar;
                    $$->stk_offset = $2->stk_offset;
                }
            }
		    | NOT unary_expression {
                print_rule("unary_expression","NOT unary_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"unary_expression");
                a=makeChildNode("NOT",a);
                a=makeChildNode($2,a);
                $$ = a;

                // update text
                $$->text = "!";
                $$->text += $2->text;
    
                strcpy($$->resultType, $2->resultType);
                $$->stk_offset = $2->stk_offset;
                $$->code = $2->code+"\n";
                $$->code += "CMP "+stk_address($2->stk_offset)+",0\n";
                string tempL1 = newLabel();
                string tempL2 = newLabel();
                $$->code += "JE "+tempL1+"\n";
                $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",0\n";
                $$->code += "JMP "+tempL2+"\n";
                $$->code += tempL1+":\n";
                $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",1\n";
                $$->code += tempL2+":\n";
                $$->tempVar = $2->tempVar;
            }
		    | factor  { 
                print_rule("unary_expression","factor");
                ptnode *a = getNewNode();
                strcpy(a->token,"unary_expression");
                a=makeChildNode($1,a);
                $$ = a;
                strcpy($$->value, $1->value);
                strcpy($$->resultType, $1->resultType);
                $$->code = $1->code;
                $$->tempVar = $1->tempVar;
                $$->stk_offset = $1->stk_offset;
            }
		 ;
	
factor: variable {

            print_rule("factor","variable");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            $$ = a;

            // update text
                $$->text = $1->text;

            strcpy($$->resultType, $1->resultType);
            $$->code = $1->code;
            $$->tempVar = $1->text; // no operation , so tempVar is realVar
            $$->stk_offset = $1->stk_offset;
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

            // update text
            $$->text = $1->lexeme;
            $$->text += "(";
            $$->text += $3->text;
            $$->text += ")";

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

            if(si != NULL)
            {
                //code 
                $$->code = $3->code+"\n";
                $$->code += "CALL "+$1->lexeme+"\n";
                $$->code += "ADD SP,"+to_string(2*si->args_list.size());
                if(si->data_type != "void")
                {
                    string tempVar = newTemp();
                    $$->stk_offset = to_string(SP_VAL);
                    // // temp_SP_vector.push_back(to_string(SP_VAL));
                    $$->code += "\nMOV "+stk_address_typecast($$->stk_offset)+",AX";
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

            // update text
            $$->text = "(";
            $$->text += $2->text;
            $$->text += ")";
        
            strcpy($$->resultType, $2->resultType);
            $$->code = $2->code;
            $$->tempVar = $2->tempVar;
            $$->stk_offset = $2->stk_offset;
        }
	| CONST_INT  { 
            print_rule("factor","CONST_INT");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            $$ = a;     $$->text = $1->lexeme;
            strcpy($$->value, $1->lexeme.c_str());
            strcpy($$->resultType, "int");

            // code
            string tempVar = newTemp();
            $$->tempVar = tempVar; // init
            $$->stk_offset = to_string(SP_VAL);
            temp_SP_vector.push_back(to_string(SP_VAL));
            $$->code = "MOV "+stk_address_typecast($$->stk_offset)+","+$1->lexeme;
        }
	| CONST_FLOAT  { 
            print_rule("factor","CONST_FLOAT");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            $$ = a;     $$->text = $1->lexeme;
            strcpy($$->value, $1->lexeme.c_str());
            strcpy($$->resultType, "float");
        }
    | ERROR_FLOAT  { 
            print_rule("factor","ERROR_FLOAT");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            $$ = a;     $$->text = $1->lexeme;
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

            $$->text = $1->text;
            $$->text += "++";

            strcpy($$->resultType, $1->resultType);
            /// as postfix , passing the previous value
            $$->tempVar = newTemp();
            $$->stk_offset = to_string(SP_VAL); // init 
            //// temp_SP_vector.push_back(to_string(SP_VAL));
            $$->code = $1->code+"\n";
            if($1->stk_offset != "") $$->code += "MOV AX,"+stk_address($1->stk_offset)+"\n";
            else $$->code += "MOV AX,"+process_global_variable($1->text)+"\n";
            
            $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",AX\n";
            if($1->stk_offset != "") $$->code += "INC "+stk_address_typecast($1->stk_offset); // actual variable
            else $$->code += "INC "+process_global_variable($1->text); // actual variable
        }
	| variable DECOP {
            print_rule("factor","variable DECOP");
            ptnode *a = getNewNode();
            strcpy(a->token,"factor");
            a=makeChildNode($1,a);
            a=makeChildNode("DECOP",a);
            $$ = a;

            $$->text = $1->text;
            $$->text += "--";

            strcpy($$->resultType, $1->resultType);
            /// as postfix , passing the previous value
            $$->tempVar = newTemp();
            $$->stk_offset = to_string(SP_VAL); // init 
            //// temp_SP_vector.push_back(to_string(SP_VAL));
            $$->code = $1->code+"\n";
            if($1->stk_offset != "") $$->code += "MOV AX,"+stk_address($1->stk_offset)+"\n";
            else $$->code += "MOV AX,"+process_global_variable($1->text)+"\n";
            
            $$->code += "MOV "+stk_address_typecast($$->stk_offset)+",AX\n";
            if($1->stk_offset != "") $$->code += "DEC "+stk_address_typecast($1->stk_offset); // actual variable
            else $$->code += "DEC "+process_global_variable($1->text); // actual variable
        }
	;
	
argument_list: arguments {
                    print_rule("argument_list","arguments");
                    ptnode *a = getNewNode();
                    strcpy(a->token,"argument_list");
                    a=makeChildNode($1,a);
                    $$ = a;
                    $$->text = $1->text;
                    $$->args_list = $1->args_list; 
                    $$->code = $1->code;
                    $$->tempVar = $1->tempVar;
                    $$->stk_offset = $1->stk_offset;
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

                $$->text = $1->text; 
                $$->text += ","; 
                $$->text += $3->text;

                $$->args_list = $1->args_list; 
                $$->args_list.push_back($3->resultType);
                $$->code = $3->code+"\n";
                if($3->stk_offset != "") $$->code += "PUSH "+stk_address($3->stk_offset)+"\n";
                else $$->code += "PUSH "+$3->text+"\n";
                $$->code += $1->code;
            }
	    | logic_expression {

                print_rule("arguments","logic_expression");
                ptnode *a = getNewNode();
                strcpy(a->token,"arguments");
                a=makeChildNode($1,a);
                $$ = a;     $$->text = $1->text;


                strcpy($$->resultType, $1->resultType);
                $$->args_list.push_back($1->resultType);
                $$->stk_offset = $1->stk_offset;
                $$->tempVar = $1->tempVar;
                $$->code = $1->code+"\n";
                if($$->stk_offset != "") $$->code += "PUSH "+stk_address($$->stk_offset);
                else $$->code += "PUSH "+$1->text+"\n";
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
    codeout.open("code.asm");
	opt_codeout.open("optimized_code.asm");
    DATA_vector.push_back("IS_NEG DB ?");
    DATA_vector.push_back("FOR_PRINT DW ?");
    DATA_vector.push_back("CR EQU 0DH\nLF EQU 0AH\nNEWLINE DB CR, LF , '$'");

    yyin=fin;
	yyparse();
    if(Root != NULL) printtree(Root);

    fprintf(logout, "Total lines: %d\n", line_count);
    fprintf(logout, "Total errors: %d\n", err_count);

    fclose(yyin);
	opt_codeout.close();
    codeout.close();
    fclose(parseout);
    fclose(logout);
	fclose(errout);

    return 0;
}