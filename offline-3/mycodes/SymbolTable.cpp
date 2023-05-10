#include<bits/stdc++.h>
#include "ScopeTable.h"
#include "SymbolTable.h"
using namespace std;

SymbolTable::~SymbolTable()
{
    while (curr_scope) {
        ScopeTable *p = curr_scope->parent_scope;
        delete curr_scope;
        curr_scope = p;
    }
    num_bkt = 0;
}

void SymbolTable::enterScope()
{
    ScopeTable* p = new ScopeTable(num_bkt, curr_scope, max_count+1);
    curr_scope = p;
    max_count++;
}

void SymbolTable::exitScope()
{
    if (curr_scope) {
        if(curr_scope->count > 1){
            ScopeTable *p = curr_scope->parent_scope;
            delete curr_scope;
            curr_scope = p;
        }
    }
}

bool SymbolTable::_insert(SymbolInfo symObj)
{
    if (curr_scope == NULL) return false;

    SymbolInfo* temp = curr_scope->search(symObj.lexeme);
    if(temp != NULL) return false;

    SymbolInfo* ret = curr_scope->insert(symObj);
    return ret!=NULL ;
}

bool SymbolTable::_remove(string lexeme)
{
    if (curr_scope == NULL) return false;
    ScopeTable *p = curr_scope;
    if (p  && p->remove(lexeme)) return true;
    return false;
}

SymbolInfo* SymbolTable::_search(string lexeme)
{
    if (curr_scope == NULL) return NULL;
    ScopeTable *p = curr_scope;
    while(p != NULL)
    {
        SymbolInfo* ret = p->search(lexeme);
        if(ret != NULL) return ret;
        p = p->parent_scope;
    }
    return NULL;
}

void SymbolTable::_print(FILE* fp, char printType){
    if(printType == 'C'){
        curr_scope->print(fp);
    }
    else if(printType == 'A'){
        for (ScopeTable *p = curr_scope; p; p = p->parent_scope) {
            p->print(fp);
        }
    }
}



