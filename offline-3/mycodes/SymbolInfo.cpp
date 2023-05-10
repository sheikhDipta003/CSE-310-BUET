#include "SymbolInfo.h"

SymbolInfo::SymbolInfo(){
    this->lexeme = ""; this->token = ""; this->next = NULL;
    isFuncDecl = false;
    isFunc = false;
    isFuncParam = false;
}

SymbolInfo::SymbolInfo(SymbolInfo* nextP){
    this->next = nextP;
}
SymbolInfo::SymbolInfo(string lexeme, string token, SymbolInfo* nextP){
    this->lexeme = lexeme;
    this->token = token;
    this->next = nextP;
    bkt = -1;
    bkt_pos = 0;
}
SymbolInfo::SymbolInfo(string lexeme,string token,string data_type,vector<string>args_list,bool isFuncDecl,bool isFunc, bool isFuncParam, SymbolInfo* nextP)
{
    this->lexeme = lexeme;
    this->token = token;
    this->data_type = data_type;
    this->args_list = args_list;
    this->isFuncDecl = isFuncDecl;
    this->isFunc = isFunc;
    this->isFuncParam = isFuncParam;
    this->next = nextP;
    this->bkt = -1;
    this->bkt_pos = 0;
}

void SymbolInfo::setDataType(string data_type){
    this->data_type = data_type;
}