
#ifndef _SYMBOLTAB_
#define _SYMBOLTAB_

#include<bits/stdc++.h>
#include "ScopeTable.h"
using namespace std;

class SymbolTable
{
    ScopeTable* curr_scope;
    int num_bkt;
    int max_count;

public:
    SymbolTable(int num_bkt)
    {
        this->max_count = 1;
        this->num_bkt = num_bkt;
        curr_scope = new ScopeTable(num_bkt);
    }

    ~SymbolTable();

    void enterScope();
    void exitScope();

    bool _insert(SymbolInfo symObj);
    bool _remove(string lexeme);
    SymbolInfo* _search(string lexeme);

    void _print(FILE* out, char printType);
};

#endif // _SYMBOLTAB_
