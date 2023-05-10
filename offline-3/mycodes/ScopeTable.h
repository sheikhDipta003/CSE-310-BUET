#ifndef _SCOPETABLE_
#define _SCOPETABLE_

#include<bits/stdc++.h>
#include "SymbolInfo.h"
using namespace std;

struct ScopeTable
{
    int count;
    int size;
    ScopeTable* parent_scope;
    vector<SymbolInfo*> hashtable;

    ScopeTable(int table_size, ScopeTable* ps=NULL)
    {
        this->parent_scope = ps;
        if(!this->parent_scope) count = 1;
        else    this->count = parent_scope->count + 1;

        size = table_size;
        hashtable = vector<SymbolInfo*>(size);
    }

    ScopeTable(int table_size, ScopeTable *ps, int count)
    {
        this->parent_scope = ps;
        this->count = count;
        size = table_size;
        hashtable = vector<SymbolInfo*>(size);
    }

    ~ScopeTable();

    int hash(string lexeme);

    SymbolInfo* search(string lexeme);
    SymbolInfo* insert(SymbolInfo symObj);
    bool remove(string lexeme);

    void print(FILE* fp);
};

#endif


