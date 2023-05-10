#ifndef _SYMINFO_
#define _SYMINFO_

#include<bits/stdc++.h>
using namespace std;

struct SymbolInfo
{
    string lexeme;
	string token;
    string data_type;
    vector<string> args_list;
    bool isFuncDecl;
    bool isFunc;
    bool isFuncParam;
    int bkt;
    int bkt_pos;

    SymbolInfo* next;

    SymbolInfo();
    SymbolInfo(SymbolInfo* nextP);
	SymbolInfo(string lexeme, string token, SymbolInfo* nextP=NULL);
    SymbolInfo(string lexeme,string token,string data_type,vector<string> args_list,bool isFuncDecl,bool isFunc, bool isFuncParam, SymbolInfo* nextP=NULL);

    void setDataType(string data_type);
};

#endif
