%{
#include<bits/stdc++.h>
#include <typeinfo>
#include "sym_table.cpp"
using namespace std;

FILE* logout;
ofstream codeout;
ofstream opt_codeout;
extern int line_count;
extern FILE *yyin;

void yyerror(string s){}
int yyparse(void);
int yylex(void);

SymbolTable *sym_tab = new SymbolTable(10);

bool is_function_now = false;
vector<SymbolInfo> function_params;

string do_implicit_typecast(string left_op,string right_op)
{
    if(left_op == "NULL" || right_op == "NULL") return "NULL"; // already reported , now supressing more errors

    if(left_op == "void" || right_op == "void") return "error";

    if((left_op == "float" || left_op == "float_array") && (right_op == "float" || right_op == "float_array")) return "float";
    if((left_op == "float" || left_op == "float_array") && (right_op == "int" || right_op == "int_array")) return "float";
    if((left_op == "int" || left_op=="int_array") && (right_op == "float" || right_op == "float_array")) return "float";
    if((left_op == "int" || left_op=="int_array") && (right_op == "int" || right_op == "int_array")) return "int";

    return "error";
}

bool is_param_typecast_ok(string og_p,string pass_p)
{
    if(pass_p == "NULL") return true; // already error reported and converted to NULL , this is made true to supress more error

    if(og_p == "void") return pass_p == "void";
    if(og_p == "int") return (pass_p == "int" || pass_p == "int_array");
    if(og_p == "float") return pass_p != "void";
}

bool check_assignop(string left_op,string right_op)
{
    if(left_op == "NULL" || right_op == "NULL") return true; // already error reported and converted to NULL , this is made true to supress more error

    if(left_op == "void" || right_op == "void") return false;
    if(left_op == "" || right_op == "") return false;

    if((left_op == "int" || left_op == "int_array") && (right_op == "int" || right_op == "int_array") ) return true;
    
    if((left_op == "float" || left_op == "float_array") && (right_op != "void") )return true;

    return false;
}

void print_grammar_rule(string head, string body)
{
    fprintf(logout, "%s : %s\n", head.data(), body.data());
}

void print_log_text(string log_text)
{
    fprintf(logout, "%s\n", log_text.data());
}

typedef struct ptnode {
    string resultType;
    vector<string> args_list;
    vector<SymbolInfo*> decl_list;
    string code;
    string tempVar;
    string stk_offset;
    string text;
} ptnode;

ptnode* getNewNode()
{
    ptnode *t = new struct ptnode();
    t->resultType = "";

    return(t);
}

///////////////////////////////////////////

string cur_function_name = "";

void insert_function_to_global(SymbolInfo* temp_s,string data_type)
{

    cur_function_name = temp_s->lexeme;

    // insert function ID to SymbolTable with data_type
    temp_s->setDataType(data_type);
    temp_s->isFunc = true;

    // update parameter type
    for(auto temp_p : function_params)
    {
        temp_s->args_list.push_back(temp_p.data_type);
    }

    if(!sym_tab->_insert(*temp_s))
    {
        SymbolInfo* ret_symbol = sym_tab->_search(temp_s->lexeme);

        if(ret_symbol->isFuncDecl == false){
            // error_multiple_declaration(temp_s->lexeme);
        }
        else{

            // declared before , now definition happening

            // check if any clash between declaration and definition

            if(ret_symbol->data_type != temp_s->data_type)
            {
                // error_function_return_condflict(temp_s->lexeme);
            }

            if(ret_symbol->args_list.size() != temp_s->args_list.size())
            {
                // error_function_parameter_number(temp_s->lexeme,true);
            }
            else
            {
                for(int i=0;i<ret_symbol->args_list.size();i++)
                {
                    if(ret_symbol->args_list[i] != temp_s->args_list[i]){
                        // error_function_parameter_type(i+1,temp_s->lexeme);
                        break;
                    }
                }
            }

            // the following line is commented out because in case of clash , use the declaration info 
            // ret_symbol->args_list = $2->args_list;
            ret_symbol->isFuncDecl = false; // declaration + 
        }

        // cout<<"Dec -> "<<ret_symbol->lexeme<<" :: "<<ret_symbol->isFuncDecl<<endl;
    }
    else{

        // Finalizing Definition

        SymbolInfo* ret_symbol = sym_tab->_search(temp_s->lexeme);
        ret_symbol->isFuncDecl = false;
        // cout<<"Dec ->> "<<ret_symbol->lexeme<<" :: "<<ret_symbol->isFuncDecl<<endl;

        for(int i=0;i<function_params.size();i++)
        {
            if(function_params[i].lexeme == "dummy_lexeme"){
                // error_parameter_name_missing(i+1,ret_symbol->lexeme);
            }
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

vector<string> DATA_vector;

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

%}

%union{
    SymbolInfo* symInfo;
    struct ptnode *node;
}


%token IF ELSE LOWER_THAN_ELSE FOR WHILE DO BREAK CHAR DOUBLE RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN INCOP DECOP ASSIGNOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
%token <symInfo> ID INT FLOAT VOID ADDOP MULOP RELOP LOGICOP CONST_CHAR CONST_INT STRING

%type <node> start program unit variable var_declaration type_specifier func_declaration func_definition parameter_list
%type <node> expression factor unary_expression term simple_expression rel_expression statement statements compound_statement logic_expression expression_statement
%type <node> arguments argument_list
%type <node> declaration_list 
%type <node> dummy_scope_function 

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE


%%

start: program
	{
		//write your code in this block in all the similar blocks below

        print_grammar_rule("start","program");

        $$ = getNewNode();

        // update type
        $$->resultType = $1->resultType;
        
        $$->text = $1->text;

        // code
        $$->code = $1->code;

        // print_log_text($$->text);

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
	;

program: program unit  {
            print_grammar_rule("program","program unit");

            $$ = getNewNode();
            $$->text = $1->text;
            $$->text += "\n";
            $$->text += $2->text;

            print_log_text($$->text);

            // code
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;

            $$->code = $1->code;
            $$->code += $2->code;

        }
	| unit { 
            print_grammar_rule("program","unit");

            $$ = getNewNode();
            $$->text = $1->text;

            // update type
            $$->resultType = $1->resultType;

            print_log_text($$->text); 

            // code
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;

        }
	;
	
unit: var_declaration { 
            print_grammar_rule("unit","var_declaration"); 

            $$ = getNewNode();
            $$->text = $1->text;

            // update type
            $$->resultType = $1->resultType;

            print_log_text($$->text); 

            // code
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;

        }
     | func_declaration { 
            print_grammar_rule("unit","func_declaration"); 

            $$ = getNewNode();
            $$->text = $1->text;

            // update type
            $$->resultType = $1->resultType;

            print_log_text($1->text); 

            // code
            $$->code = $1->code;

            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;

            SP_VAL = 0;

        }
     | func_definition { 
            print_grammar_rule("unit","func_definition");

            $$ = getNewNode();
            $$->text = $1->text;

            // update type
            $$->resultType = $1->resultType;

            print_log_text($1->text); 

            // code
            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;

            SP_VAL = 0;

        }
     ;
     
func_declaration: type_specifier ID LPAREN parameter_list RPAREN SEMICOLON { 
                
                print_grammar_rule("func_declaration","type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
                
                $$ = getNewNode();

                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;
                $$->text += "(";
                $$->text += $4->text;
                $$->text += ")";
                $$->text += ";";

                // insert function ID to SymbolTable with data_type
                $2->setDataType($1->text);
                $2->isFunc = true;

                // update parameter type
                for(auto temp_s : function_params)
                {
                    $2->args_list.push_back(temp_s.data_type);
                }

                if(sym_tab->_insert(*$2))
                {
                    SymbolInfo* ret_symbol = sym_tab->_search($2->lexeme);
                    ret_symbol->isFuncDecl = true; // mark as function declaration
                }
                else
                {
                    // error_multiple_declaration($2->lexeme);
                }

                print_log_text($$->text);

                // clear param_info
                function_params.clear();

    
        }
		| type_specifier ID LPAREN RPAREN SEMICOLON { 

                print_grammar_rule("func_declaration","type_specifier ID LPAREN RPAREN SEMICOLON");
                
                $$ = getNewNode();

                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;
                $$->text += "(";
                $$->text += ")";
                $$->text += ";";

                // insert function ID to SymbolTable with data_type
                $2->setDataType($1->text);
                $2->isFunc = true;
                
                if(sym_tab->_insert(*$2))
                {
                    SymbolInfo* ret_symbol = sym_tab->_search($2->lexeme);
                    ret_symbol->isFuncDecl = true; // mark as function declaration
                }
                else
                {
                    // error_multiple_declaration($2->lexeme);
                }

                print_log_text($$->text);

                function_params.clear();

            }
		;

		 
func_definition: type_specifier ID LPAREN parameter_list RPAREN { is_function_now = true; insert_function_to_global($2,$1->text);} compound_statement { 
                print_grammar_rule("func_definition","type_specifier ID LPAREN parameter_list RPAREN compound_statement");
                
                $$ = getNewNode();

                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;
                $$->text += "(";
                $$->text += $4->text;
                $$->text += ")";
                $$->text += $7->text; 

                print_log_text($$->text);

                                // code
                $$->code = $2->lexeme+" PROC\n";

                if($2->lexeme=="main")
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

                if($2->lexeme=="main")
                {
                    $$->code += "\n;DOS EXIT\nMOV AH,4ch\nINT 21h\n";
                }
                else 
                {
                    $$->code += "RET\n";
                }


                $$->code += $2->lexeme+" ENDP\n\n";

                if($2->lexeme=="main") $$->code += "END MAIN\n";

                // clear temp function params
                is_function_now = false;
                function_params.clear();
            }
		|   type_specifier ID LPAREN RPAREN {is_function_now = true;insert_function_to_global($2,$1->text);} compound_statement { 
                print_grammar_rule("func_definition","type_specifier ID LPAREN RPAREN compound_statement");

                $$ = getNewNode();

                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;
                $$->text += "(";
                $$->text += ")";
                $$->text += $6->text;

                // insert function ID to SymbolTable with data_type
                $2->setDataType($1->text);
                $2->isFunc = true;
                sym_tab->_insert(*$2);

                print_log_text($$->text);

                // code

                // code

                $$->code = $2->lexeme+" PROC\n";

                if($2->lexeme=="main")
                {
                    $$->code += "MOV AX, @DATA\nMOV DS, AX\n";
                }

                $$->code += "PUSH BP\nMOV BP,SP\n";
                $$->code += "SUB SP,"+to_string(SP_VAL)+"\n";

                $$->code += $6->code+"\n";

                $$->code += cur_function_label(cur_function_name)+":\n";
                $$->code += "ADD SP,"+to_string(SP_VAL)+"\n";
                $$->code += "POP BP\n";

                if($2->lexeme=="main")
                {
                    $$->code += "\n;DOS EXIT\nMOV AH,4ch\nINT 21h\n";
                }
                else 
                {
                    $$->code += "RET\n";
                }
                

                $$->code += $2->lexeme+" ENDP\n";

                if($2->lexeme=="main") $$->code += "END MAIN\n";
            
                // clear temp function params
                is_function_now = false;
                function_params.clear();
            }
 		;				


parameter_list: parameter_list COMMA type_specifier ID {

               print_grammar_rule("parameter_list","parameter_list COMMA type_specifier ID");

                $$ = getNewNode();

                // update text
                $$->text = $1->text;
                $$->text += ",";
                $$->text += $3->text;
                $$->text += " ";
                $$->text += $4->lexeme;

                // insert parameter ID to SymbolTable with data_type
                $4->setDataType($3->text);
                function_params.push_back(*$4);

                print_log_text($$->text);
            }
        | parameter_list COMMA type_specifier {
             print_grammar_rule("parameter_list","parameter_list COMMA type_specifier");

                $$ = getNewNode();

                // update text
                $$->text = $1->text;
                $$->text += ",";
                $$->text += $3->text;

                SymbolInfo temp_s = SymbolInfo("dummy_lexeme","dummy_value");
                temp_s.data_type = $3->text;

                function_params.push_back(temp_s);

                print_log_text($$->text);

        }
 		| type_specifier ID  { 
                print_grammar_rule("parameter_list","type_specifier ID");
                
                $$ = getNewNode();

                // update text
                $$->text = $1->text;
                $$->text += " ";
                $$->text += $2->lexeme;

                // insert parameter ID to Parameter SymbolTable with data_type
                $2->setDataType($1->text);
                function_params.push_back(*$2);

                print_log_text($$->text);

        }
		| type_specifier {
            print_grammar_rule("parameter_list","type_specifier");

            $$ = getNewNode();

            // update type
            $$->resultType = $1->resultType;

            // update text
            $$->text = $1->text;

            SymbolInfo temp_s = SymbolInfo("dummy_lexeme","dummy_value");
            temp_s.data_type = $1->text;

            function_params.push_back(temp_s);

            print_log_text($$->text);

        }
 		;
 		
compound_statement: LCURL dummy_scope_function statements RCURL {
                print_grammar_rule("compound_statement","LCURL statements RCURL");
                
                $$ = getNewNode();

                // update text
                $$->text = "{\n"; 
                $$->text += $3->text; 
                $$->text += "\n}"; 

                print_log_text($$->text);

                // code
                $$->code = $2->code;
                $$->code += $3->code;
                $$->tempVar = $3->tempVar;
                $$->stk_offset = $3->stk_offset;

                // EXIT
                sym_tab->_print(logout, 'A');
                sym_tab->exitScope();
            }
            | LCURL dummy_scope_function RCURL {

                print_grammar_rule("compound_statement","LCURL RCURL");

                $$ = getNewNode();

                // update text
                $$->text = "{";  
                $$->text += "}"; 

                print_log_text($$->text);

                $$->code = $2->code;

                // EXIT
                sym_tab->_print(logout, 'A');
                sym_tab->exitScope();

                // // clear temp function params
                // is_function_now = false;
                // function_params.clear();
             }
 		    ;

dummy_scope_function:  {

                    $$ = getNewNode();

                    sym_tab->enterScope(); 

                    $$->code = "";
                    int PP_Val = 4;

                    if(is_function_now)
                    {
                        // $$->code += "; retrieving function parameter\n";

                        for(auto &el:function_params)
                        {

                            if(el.lexeme == "dummy_lexeme") continue;
                            if(el.data_type == "void")
                            {
                                // error_var_type();
                                el.data_type = "NULL";
                            }
                            // insert ID
                            // cout<<"INSIDE FUNCTIONNN"<<endl;

                            incSP();
                            el.stk_offset = to_string(SP_VAL);

                            if(!sym_tab->_insert(el)) // already present in current scope
                            {
                                // error_multiple_declaration(el.lexeme + " in parameter");
                            }


                            $$->code += "MOV AX,"+stk_address_param(to_string(PP_Val))+"\n";
                            $$->code += "MOV "+stk_address_typecast(el.stk_offset)+",AX\n";
                            PP_Val+=2;

                        }

                    }
                }
                ;
 		    
var_declaration: type_specifier declaration_list SEMICOLON { 

            print_grammar_rule("var_declaration","type_specifier declaration_list SEMICOLON");
            
            $$ = getNewNode();

            // update text
            $$->text = $1->text;
            $$->text += " ";
            $$->text += $2->text;
            $$->text += ";";

            if($1->text == "void"){
                // error_data_type();
            }
            else{
                // insert all declaration_list ID to SymbolTable with data_type
                for(auto el:$2->decl_list)
                {
                        if(el->data_type == "array")
                        {
                            el->setDataType($1->text + "_array");

                            if(sym_tab->getCurrentScopeID()!=1) // not global
                            {
                                incSP(el->ara_size);
                                el->stk_offset = to_string(SP_VAL);
                            }
                            else
                            {
                                DATA_vector.push_back(el->lexeme + " dw "+to_string(el->ara_size)+" dup ($)");
                            }

                        }
                        else 
                        {
                            el->setDataType($1->text); 

                            if(sym_tab->getCurrentScopeID()!=1) // not global
                            {
                                incSP();
                                el->stk_offset = to_string(SP_VAL);
                            }
                            else
                            {
                                DATA_vector.push_back(el->lexeme + " dw ?");
                            }
                
                        }
                    
                    if(!sym_tab->_insert(*el)) // already present in current scope
                    {
                        // error_multiple_declaration(el->lexeme);
                    }

                }
            }

            print_log_text($$->text);

        }
 		;
 		 
type_specifier: INT  { 
                    print_grammar_rule("type_specifier","INT"); 

                    $$ = getNewNode();
                    $$->text = $1->lexeme; 

                    print_log_text($$->text);

                }
 		| FLOAT { 
                    print_grammar_rule("type_specifier","FLOAT"); 

                    $$ = getNewNode();
                    $$->text = $1->lexeme; 

                    print_log_text($$->text);

        }
 		| VOID { 
                    print_grammar_rule("type_specifier","VOID"); 

                    $$ = getNewNode();
                    $$->text = $1->lexeme;

                    print_log_text($$->text);
                }
 		;
 		
declaration_list: declaration_list COMMA ID { 
                    print_grammar_rule("declaration_list","declaration_list COMMA ID");
                    
                    $$ = getNewNode();

                    // update text
                    $$->text = $1->text;
                    $$->text += ",";
                    $$->text += $3->lexeme;

                    // update type
                    $$->resultType = $1->resultType;

                    // init update vector
                    $$->decl_list= $1->decl_list;
                    $$->decl_list.push_back($3);
                    // $$->print();

                    print_log_text($$->text);
            }
 		    | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
               print_grammar_rule("declaration_list","declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
           
                $$ = getNewNode();

                // update text
                $$->text = $1->text;
                $$->text += ",";
                $$->text += $3->lexeme;
                $$->text += "[";
                $$->text += $5->lexeme;
                $$->text += "]";

                // update type
                $$->resultType = $1->resultType;

                // init & update vector
                $$->decl_list= $1->decl_list;
                $3->setDataType("array");
                $3->ara_size = stoi($5->lexeme);
                $$->decl_list.push_back($3);
                // $$->print();

                print_log_text($$->text);
           }
 		    | ID {     
                    print_grammar_rule("declaration_list","ID");

                    $$ = getNewNode();

                    // update text
                    $$->text = $1->lexeme;

                    // init vector
                    $$->decl_list.push_back($1);

                    print_log_text($$->text);

            }
 		    | ID LTHIRD CONST_INT RTHIRD {

                    print_grammar_rule("declaration_list","ID LTHIRD CONST_INT RTHIRD");

                    $$ = getNewNode();

                    // update text
                    $$->text = $1->lexeme;
                    $$->text += "[";
                    $$->text += $3->lexeme;
                    $$->text += "]";

                    // init vector
                    $1->setDataType("array");
                    $1->ara_size = stoi($3->lexeme);
                    $$->decl_list.push_back($1);
                    // cout<<"PRINT"<<endl;
                    // $$->print();

                    print_log_text($$->text);
            }
 		  ;
 		  
statements: statement {
            print_grammar_rule("statements","statement");
            
            $$ = getNewNode();
            $$->text = $1->text;

            print_log_text($$->text);

            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;

        }
	   | statements statement {
            print_grammar_rule("statements","statements statement");
        
            $$ = getNewNode();
            $$->text = $1->text;
            $$->text += "\n";
            $$->text += $2->text;

            print_log_text($$->text);

            $$->code = $1->code+"\n";
            $$->code += $2->code;
        }
        
	   ;
	   
statement: var_declaration {
            print_grammar_rule("statement","var_declaration");

            $$ = getNewNode();
            $$->text = $1->text;

            // update type
            $$->resultType = $1->resultType;

            print_log_text($$->text);

            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;

        }
      | func_definition {
          print_grammar_rule("statement","func_definition");

            $$ = getNewNode();
            $$->text = $1->text;

            print_log_text($$->text);
            // error_nested_function();

            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;

      }
      | func_declaration {
          print_grammar_rule("statement","func_declaration");

            $$ = getNewNode();
            $$->text = $1->text;

            print_log_text($$->text);
            // error_nested_function();

            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;

      }
	  | expression_statement {
            print_grammar_rule("statement","expression_statement");

            $$ = getNewNode();
            $$->text = $1->text;

            // update type
            $$->resultType = $1->resultType;

            print_log_text($$->text);

            $$->code = "; "+$$->text+"\n";
            $$->code += $1->code;

            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
        }
	  | compound_statement {
            print_grammar_rule("statement","compound_statement");

            $$ = getNewNode();
            $$->text = $1->text;

            // update type
            $$->resultType = $1->resultType;

            print_log_text($$->text);

            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
        }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement {
            print_grammar_rule("statement","FOR LPAREN expression_statement expression_statement expression RPAREN statement");

            $$ = getNewNode();

            // update text
            $$->text = "for";
            $$->text += "(";
            $$->text += $3->text;
            $$->text += $4->text;
            $$->text += $5->text;
            $$->text += ")";
            $$->text += $7->text;
            
            print_log_text($$->text);

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
            print_grammar_rule("statement","IF LPAREN expression RPAREN statement");
            
            $$ = getNewNode();
            // update text
            $$->text = "if";
            $$->text += "(";
            $$->text += $3->text;
            $$->text += ")";
            $$->text += $5->text;

            print_log_text($$->text);

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

            print_grammar_rule("statement","IF LPAREN expression RPAREN statement ELSE statement");
        
            $$ = getNewNode();
            // update text
            $$->text = "if";
            $$->text += "(";
            $$->text += $3->text;
            $$->text += ")";
            $$->text += $5->text;
            $$->text += "\nelse ";
            $$->text += $7->text;

            print_log_text($$->text);

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
            print_grammar_rule("statement","WHILE LPAREN expression RPAREN statement");

            $$ = getNewNode();
            // update text
            $$->text = "while";
            $$->text += "(";
            $$->text += $3->text;
            $$->text += ")";
            $$->text += $5->text;

            print_log_text($$->text);

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
            print_grammar_rule("statement","PRINTLN LPAREN ID RPAREN SEMICOLON");

            $$ = getNewNode();
            $$->text = "printf";
            $$->text += "(";
            $$->text += $3->lexeme;
            $$->text += ")";
            $$->text += ";";

            print_log_text($$->text);

            // check error
            SymbolInfo* ret_symbol = sym_tab->_search($3->lexeme);

            if(ret_symbol == NULL)
            {
                // error_undeclared_variable($3->lexeme);
                $$->resultType = "NULL";
            }

            $$->code = "\n; "+$$->text+"\n";
            
            if(ret_symbol != NULL && ret_symbol->stk_offset != "") $$->code += "MOV AX,"+stk_address(ret_symbol->stk_offset)+"\n";
            else $$->code += "MOV AX,"+$3->lexeme+"\n";
            
            $$->code += "MOV FOR_PRINT,AX\n";
            $$->code += "CALL OUTPUT";
        }
        | PRINTLN LPAREN ID LTHIRD expression RTHIRD RPAREN SEMICOLON {
            print_grammar_rule("statement","PRINTLN LPAREN ID RPAREN SEMICOLON");

            $$ = getNewNode();
            $$->text = "printf";
            $$->text += "(";
            $$->text += $3->lexeme;
            $$->text += "[";
            $$->text += $5->text;
            $$->text += "]";
            $$->text += ")";
            $$->text += ";";

            print_log_text($$->text);

            // check error
            SymbolInfo* ret_symbol = sym_tab->_search($3->lexeme);

            if(ret_symbol == NULL)
            {
                // error_undeclared_variable($3->lexeme);
                $$->resultType = "NULL";
            }

            if(ret_symbol != NULL)
            {
                $$->code = "\n; "+$$->text+"\n";

                // code

                $$->code += $5->code+"\n";
                $$->stk_offset = ret_symbol->stk_offset+"+SI";

                if(ret_symbol->stk_offset != "")
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
            print_grammar_rule("statement","RETURN expression SEMICOLON");

            $$ = getNewNode();
            $$->text = "return";
            $$->text += " ";
            $$->text += $2->text;
            $$->text += ";";

            print_log_text($$->text);

            $$->code = "; "+$$->text+"\n";
            $$->code += $2->code+"\n";
            
            if($2->stk_offset != "") $$->code += "MOV AX,"+stk_address($2->stk_offset)+"\n";
            else {
                $$->code += "MOV AX,"+ process_global_variable($2->text)+"\n";
            } 

            $$->code += "JMP "+cur_function_label(cur_function_name)+"\n";

            //$$->code += "POP BP\n";
            //$$->code += "RET";
        }
	  ;
	  
expression_statement: SEMICOLON	{
                    print_grammar_rule("expression_statement","SEMICOLON");

                    $$ = getNewNode();
                    $$->text = ";";

                    print_log_text($$->text);

                }		
			| expression SEMICOLON {
                    print_grammar_rule("expression_statement","expression SEMICOLON");
                    
                    $$ = getNewNode();

                    // update text
                    $$->text = $1->text;
                    $$->text += ";";

                    print_log_text($$->text);

                    $$->code = $1->code;
                    $$->tempVar = $1->tempVar;
                    $$->stk_offset = $1->stk_offset;
                }
			;
	  
variable: ID { 
            print_grammar_rule("variable","ID");
            $$ = getNewNode();

            // update text
            $$->text = $1->lexeme;

            // check error
            SymbolInfo* ret_symbol = sym_tab->_search($1->lexeme);

            if(ret_symbol == NULL)
            {
                // error_undeclared_variable($1->lexeme);
                $$->resultType = "NULL";
            }
            else
            {
                if(ret_symbol->data_type == "int_array" || ret_symbol->data_type == "float_array")
                {
                    // error_type_mismatch(ret_symbol->lexeme + " is an array"); // should i change this to indexing
                    $$->resultType = "NULL";
                }
                else{
                    $$->resultType = ret_symbol->data_type;
                }
                //  cout<<"Helper : "<<$$->resultType<<endl;
            }

            print_log_text($$->text);


            $$->code = "";
            $$->tempVar = $1->lexeme;

            if(ret_symbol != NULL) $$->stk_offset = ret_symbol->stk_offset;
        }		
	 | ID LTHIRD expression RTHIRD {
            print_grammar_rule("variable","ID LTHIRD expression RTHIRD");
            
            $$ = getNewNode();

            // update text
            $$->text = $1->lexeme;
            $$->text += "[";
            $$->text += $3->text;
            $$->text += "]";

            // check error
            SymbolInfo* ret_symbol = sym_tab->_search($1->lexeme);

            if(ret_symbol == NULL)
            {
                // error_undeclared_variable($1->lexeme);
                $$->resultType = "NULL";
            }
            else
            {
                if(ret_symbol->data_type == "int" || ret_symbol->data_type == "float")
                {
                    // error_not_array(ret_symbol->lexeme);
                    $$->resultType = "NULL";
                }
                else{
                    $$->resultType = ret_symbol->data_type;
                }
                // cout<<"resultType : "<<$$->resultType<<endl;
            }

            if($3->resultType != "int")
            {
                // error_array_index_invalid();
            }

            print_log_text($$->text);

            if(ret_symbol != NULL)
            {
                // code

                $$->code = $3->code+"\n";

                if(ret_symbol->stk_offset!="")
                {
                    $$->code += "MOV SI,"+stk_address($3->stk_offset)+"\n";
                    $$->code += "ADD SI,SI";
                    $$->stk_offset = ret_symbol->stk_offset+"+SI";
                }
                else
                {
                    $$->code += "MOV BX,"+stk_address($3->stk_offset)+"\n";
                    $$->code += "ADD BX,BX";
                    //$$->stk_offset = ret_symbol->stk_offset+"+SI";
                }
            }
         }
	 ;
	 
 expression: logic_expression	{
                print_grammar_rule("expression","logic_expression");

                $$ = getNewNode();
                // update text
                $$->text = $1->text;
                // update vector : push up
                $$->resultType = $1->resultType;

                // $$->code = "; "+$1->text+"\n";
                $$->code = $1->code;
                $$->tempVar = $1->tempVar;
                $$->stk_offset = $1->stk_offset;

                print_log_text($$->text);
            }
	   | variable ASSIGNOP logic_expression {
                print_grammar_rule("expression","variable ASSIGNOP logic_expression");
                
                $$ = getNewNode();

                // update text
                $$->text = $1->text;
                $$->text += "=";
                $$->text += $3->text;

                //check error
                // cout<<$1->resultType<<" ---- "<<$3->resultType<<endl;
                if(!check_assignop($1->resultType,$3->resultType))
                {
                    if($1->resultType=="void" || $3->resultType=="void")
                    {
                        // error_type_cast_void();
                    }
                    else
                    {
                        // error_type_mismatch();
                    }
                }

                print_log_text($$->text);

                // code
                
                $$->code = $3->code+"\n";

                if($3->stk_offset != "") $$->code += "MOV CX,"+stk_address($3->stk_offset)+"\n";
                else $$->code += "MOV CX,"+process_global_variable($3->text)+"\n";

                if($1->code != "") $$->code += $1->code+"\n";

                if($1->stk_offset != "") $$->code += "MOV "+stk_address_typecast($1->stk_offset)+",CX";
                else $$->code += "MOV "+process_global_variable($1->text)+",CX";
            }	
	   ;


			 
logic_expression: rel_expression {
                print_grammar_rule("logic_expression","rel_expression");

                $$ = getNewNode();
                // update text
                $$->text = $1->text;
                // update vector : push up
                $$->resultType = $1->resultType;

                print_log_text($$->text);

                $$->code = $1->code;
                $$->tempVar = $1->tempVar;
                $$->stk_offset = $1->stk_offset;
            }	
		 | rel_expression LOGICOP rel_expression {
                print_grammar_rule("logic_expression","rel_expression LOGICOP rel_expression");
                
                $$ = getNewNode();
                // update text
                $$->text = $1->text;
                $$->text += $2->lexeme;
                $$->text += $3->text;

                // do implicit typecast
                string typecast_ret = do_implicit_typecast($1->resultType,$3->resultType);

                if(typecast_ret != "NULL")
                {
                    if(typecast_ret != "error") $$->resultType = "int"; // ALWAYS INT
                    else {

                        if($1->resultType=="void" || $3->resultType=="void")
                        {
                            // error_type_cast_void();
                        }
                        else
                        {
                            // error_type_cast();
                        }

                         $$->resultType = "NULL";
                    }
                    
                    // cout<<"Implicit Typecast : "<<$$->resultType<<"\n"<<endl;
                }
                else
                {
                    $$->resultType = "NULL";
                }

                print_log_text($$->text);

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
                print_grammar_rule("rel_expression","simple_expression");

                $$ = getNewNode();
                // update text
                $$->text = $1->text;
                // update vector : push up
                $$->resultType = $1->resultType;

                print_log_text($$->text);

                $$->code = $1->code;
                $$->tempVar = $1->tempVar;
                $$->stk_offset = $1->stk_offset;
            }
		| simple_expression RELOP simple_expression	{
                print_grammar_rule("rel_expression","simple_expression RELOP simple_expression");
                
                $$ = getNewNode();
                // update text
                $$->text = $1->text;
                $$->text += $2->lexeme;
                $$->text += $3->text;

                // do implicit typecast
                string typecast_ret = do_implicit_typecast($1->resultType,$3->resultType);

                if(typecast_ret != "NULL")
                {
                    if(typecast_ret != "error") $$->resultType = "int"; // ALWAYS INT
                    else {

                        if($1->resultType=="void" || $3->resultType=="void")
                        {
                            // error_type_cast_void();
                        }
                        else
                        {
                            // error_type_cast();
                        }

                         $$->resultType = "NULL";
                    }
                    // cout<<"Implicit Typecast : "<<$$->resultType<<"\n"<<endl;
                }
                else
                {
                    $$->resultType = "NULL";
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

                print_log_text($$->text);
            }
		;
				
simple_expression: term {

                    print_grammar_rule("simple_expression","term");

                    $$ = getNewNode();
                    // update text
                    $$->text = $1->text;
                    // update vector : push up
                    $$->resultType = $1->resultType;

                    print_log_text($$->text);

                    $$->code = $1->code;
                    $$->tempVar = $1->tempVar;
                    $$->stk_offset = $1->stk_offset;
            }
		    |   simple_expression ADDOP term {
                    print_grammar_rule("simple_expression","simple_expression ADDOP term");

                    $$ = getNewNode();
                    // update text
                    $$->text = $1->text;
                    $$->text += $2->lexeme;
                    $$->text += $3->text;
                    // do implicit typecast
                    // cout<<$1->resultType<<" --- "<<$3->resultType<<endl;
                    string typecast_ret = do_implicit_typecast($1->resultType,$3->resultType);

                    if(typecast_ret != "NULL")
                    {
                        if(typecast_ret != "error") $$->resultType = typecast_ret;
                        else {

                        if($1->resultType=="void" || $3->resultType=="void")
                        {
                            // error_type_cast_void();
                        }
                        else
                        {
                            // error_type_cast();
                        }

                         $$->resultType = "NULL";
                        }
                        // cout<<"Implicit Typecast : "<<$$->resultType<<"\n"<<endl;
                    }
                    else
                    {
                        $$->resultType = "NULL";
                    }

                    print_log_text($$->text);

                    if($2->lexeme=="+")
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

            print_grammar_rule("term","unary_expression");

            $$ = getNewNode();
            // update text
            $$->text = $1->text;
            // update vector : push up
            $$->resultType = $1->resultType;

            print_log_text($$->text);

            $$->code = $1->code;
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
    }
    |  term MULOP unary_expression {

            print_grammar_rule("term","term MULOP unary_expression");

            $$ = getNewNode();
            // update text
            $$->text = $1->text;
            $$->text += $2->lexeme;
            $$->text += $3->text;
            // implicit typecast
            string typecast_ret = do_implicit_typecast($1->resultType,$3->resultType);

            if($2->lexeme == "%") // both operand should be integer
            {
                if($3->text == "0")
                {
                    // error_type_cast_mod_zero();
                    $$->resultType = "NULL";
                }
                else
                {
                    if(typecast_ret != "int")
                    {
                        // error_type_cast_mod();
                        $$->resultType = "NULL";
                    }
                    else{
                        $$->resultType = "int";
                        // cout<<"HERERE"<<endl;

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
                    if(typecast_ret != "error") $$->resultType = typecast_ret;
                    else {

                        if($1->resultType=="void" || $3->resultType=="void")
                        {
                            // error_type_cast_void();
                        }
                        else
                        {
                            // error_type_cast();
                        }

                         $$->resultType = "NULL";
                    }
                    // cout<<"Implicit Typecast : "<<$$->resultType<<"\n"<<endl;
                }
                else
                {
                    $$->resultType = "NULL";
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

            print_log_text($$->text);
    }
    ;

unary_expression: ADDOP unary_expression  {
                print_grammar_rule("unary_expression","ADDOP unary_expression");
                
                $$ = getNewNode();
                // update text
                $$->text = $1->lexeme;
                $$->text += $2->text;
                // implicit typecast
                $$->resultType = $2->resultType;

                print_log_text($$->text);

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
                print_grammar_rule("unary_expression","NOT unary_expression");
                
                $$ = getNewNode();
                // update text
                $$->text = "!";
                $$->text += $2->text;
                // implicit typecast
                $$->resultType = $2->resultType;

                print_log_text($$->text);

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
                print_grammar_rule("unary_expression","factor");
                
                $$ = getNewNode();
                // update text
                $$->text = $1->text;
                // implicit typecast
                $$->resultType = $1->resultType;

                print_log_text($$->text);

                $$->code = $1->code;
                $$->tempVar = $1->tempVar;
                $$->stk_offset = $1->stk_offset;
            }
		 ;
	
factor: variable {

            print_grammar_rule("factor","variable");

            $$ = getNewNode();
            // update text
            $$->text = $1->text;
            // implicit typecast
            $$->resultType = $1->resultType;

            print_log_text($$->text);

            $$->code = $1->code;
            $$->tempVar = $1->text; // no operation , so tempVar is realVar
            $$->stk_offset = $1->stk_offset;
        }
	| ID LPAREN argument_list RPAREN {

            print_grammar_rule("factor","ID LPAREN argument_list RPAREN");

            $$ = getNewNode();
            // update text
            $$->text = $1->lexeme;
            $$->text += "(";
            $$->text += $3->text;
            $$->text += ")";

            // check error
            SymbolInfo* ret_symbol = sym_tab->_search($1->lexeme);

            if(ret_symbol == NULL)
            {
                // error_undeclared_function($1->lexeme);
                $$->resultType = "NULL";
            }
            else
            {
                if(ret_symbol->isFunc == false)
                {
                    $$->resultType = "NULL";
                    // error_not_function($1->lexeme);
                    break;
                }

                $$->resultType = ret_symbol->data_type;

                if(ret_symbol->isFuncDecl) // only declared , no definition
                {
                    // error_function_not_implemented();
                }
                else // other errors
                {
                    if(ret_symbol->args_list.size() != $3->args_list.size())
                    {
                        // error_function_parameter_number(ret_symbol->lexeme);
                    }
                    else
                    {
                        for(int i=0;i<ret_symbol->args_list.size();i++)
                        {
                            if(!is_param_typecast_ok(ret_symbol->args_list[i],$3->args_list[i])){
                                // error_function_parameter_type(i+1,ret_symbol->lexeme);
                                break;
                            }
                        }
                    }
                }
            }

            print_log_text($$->text);

            if(ret_symbol != NULL)
            {
                //code 

                $$->code = $3->code+"\n";
                $$->code += "CALL "+$1->lexeme+"\n";
                $$->code += "ADD SP,"+to_string(2*ret_symbol->args_list.size());

                if(ret_symbol->data_type != "void")
                {
                    string tempVar = newTemp();
                    $$->stk_offset = to_string(SP_VAL);
                    // // temp_SP_vector.push_back(to_string(SP_VAL));
                    $$->code += "\nMOV "+stk_address_typecast($$->stk_offset)+",AX";
                }
            }
        }
	| LPAREN expression RPAREN {

            print_grammar_rule("factor","LPAREN expression RPAREN");

            $$ = getNewNode();
            // update text
            $$->text = "(";
            $$->text += $2->text;
            $$->text += ")";

            $$->resultType = $2->resultType;

            $$->code = $2->code;
            $$->tempVar = $2->tempVar;
            $$->stk_offset = $2->stk_offset;

            print_log_text($$->text);        
        }
	| CONST_INT  { 
            print_grammar_rule("factor","CONST_INT");

            // update text
            $$ = getNewNode();
            $$->text = $1->lexeme;

            // pass up
            $$->resultType = "int";

            print_log_text($$->text);

            // code
            string tempVar = newTemp();
            
            $$->tempVar = tempVar; // init
            $$->stk_offset = to_string(SP_VAL);
            temp_SP_vector.push_back(to_string(SP_VAL));
            $$->code = "MOV "+stk_address_typecast($$->stk_offset)+","+$1->lexeme;
        }
	| variable INCOP {
            print_grammar_rule("factor","variable INCOP");

            $$ = getNewNode();
          
            $$->text = $1->text;
            $$->text += "++";

            // update type
            $$->resultType = $1->resultType;

            print_log_text($$->text);

            /**
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
            $$->code = "INC "+stk_address_typecast($$->stk_offset);
            **/

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
            print_grammar_rule("factor","variable DECOP");

            $$ = getNewNode();
            $$->text = $1->text;
            $$->text += "--";

            // update type
            $$->resultType = $1->resultType;

            print_log_text($$->text);

            /**
            $$->tempVar = $1->tempVar;
            $$->stk_offset = $1->stk_offset;
            $$->code = "DEC "+stk_address_typecast($$->stk_offset);
            **/

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

                    print_grammar_rule("argument_list","arguments");

                    $$ = getNewNode();
                    $$->text = $1->text;

                    $$->args_list = $1->args_list; 

                    print_log_text($$->text);

                    $$->code = $1->code;
                    $$->tempVar = $1->tempVar;
                    $$->stk_offset = $1->stk_offset;
                }
			| {
                print_grammar_rule("argument_list","");
                $$ = getNewNode();
            }   
			;
	
arguments: arguments COMMA logic_expression {

                print_grammar_rule("arguments","arguments COMMA logic_expression");
                
                $$ = getNewNode();
                $$->text = $1->text; 
                $$->text += ","; 
                $$->text += $3->text;

                // update vector
                $$->args_list = $1->args_list; 
                $$->args_list.push_back($3->resultType);

                print_log_text($$->text);

                $$->code = $3->code+"\n";
                if($3->stk_offset != "") $$->code += "PUSH "+stk_address($3->stk_offset)+"\n";
                else $$->code += "PUSH "+$3->text+"\n";

                $$->code += $1->code;
            }
	    | logic_expression {

                print_grammar_rule("arguments","logic_expression");

                $$ = getNewNode();

                // update text
                $$->text = $1->text; 
                // update helper type
                $$->resultType = $1->resultType;
                // cout<<"Logic Helper : "<<$$->resultType<<endl;
                // init vector
                $$->args_list.push_back($1->resultType);

                print_log_text($$->text);

                $$->stk_offset = $1->stk_offset;
                $$->tempVar = $1->tempVar;

                $$->code = $1->code+"\n";

                if($$->stk_offset != "") $$->code += "PUSH "+stk_address($$->stk_offset);
                else $$->code += "PUSH "+$1->text+"\n";
            }
	    ;

%%

main(int argc,char *argv[])
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
	codeout.open("code.asm");
	opt_codeout.open("optimized_code.asm");

    DATA_vector.push_back("IS_NEG DB ?");
    DATA_vector.push_back("FOR_PRINT DW ?");
    DATA_vector.push_back("CR EQU 0DH\nLF EQU 0AH\nNEWLINE DB CR, LF , '$'");


    yyin=fin;
	yyparse();

    sym_tab->_print(logout, 'A');

    fclose(yyin);

    fclose(logout);
	codeout.close();
	opt_codeout.close();

    exit(0);
}
