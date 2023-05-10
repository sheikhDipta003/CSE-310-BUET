#include<bits/stdc++.h>
#include <string>
#include "SymbolInfo.h"
#include "ScopeTable.h"
using namespace std;

ScopeTable::~ScopeTable()
{
    for(int i=0; i<hashtable.size(); i++)
    {
        SymbolInfo* sym = hashtable[i];

        while(sym != NULL)
        {
            SymbolInfo* tmp = sym->next;
            delete sym;
            sym = tmp;
        }
    }
    this->count = -1;
	this->parent_scope = NULL;
}

int ScopeTable::hash(string lexeme)
{
    int h = 0;
    for(int i=0;i<(int)lexeme.size();i++)
    {
        h = (h + lexeme[i]);
    }
    h = (h % size);
    return h;
}

SymbolInfo* ScopeTable::search(string lexeme)
{
    int bkt = hash(lexeme);
    int bkt_pos = 0;

    SymbolInfo* sym = hashtable[bkt];

    while(sym != NULL)
    {
        if(sym->lexeme == lexeme)
        {
            sym->bkt_pos = bkt_pos;
            return sym;
        }

        sym = sym->next;
        bkt_pos++;
    }

    return NULL;
}

SymbolInfo* ScopeTable::insert(SymbolInfo symObj)
{
    string lexeme = symObj.lexeme;
    string token = symObj.token;
    string data_type = symObj.data_type;
    vector<string>args_list = symObj.args_list;
    bool isFuncDecl = symObj.isFuncDecl;
    bool isFunc = symObj.isFunc;
    bool isFuncParam = symObj.isFuncParam;

    int bkt = hash(lexeme);

    SymbolInfo* _new = new SymbolInfo(lexeme,token,data_type,args_list,isFuncDecl,isFunc,isFuncParam,NULL);
    _new->bkt = bkt;

    if(hashtable[bkt] == NULL) {
        hashtable[bkt] = _new;
        _new->bkt_pos = 0;
    }
    else
    {
        SymbolInfo* sym = hashtable[bkt];
        if(sym->lexeme == lexeme) return NULL;

        int bkt_pos = 1;

        while(sym->next != NULL)
        {
            if(sym->lexeme == lexeme)
                return NULL;

            sym = sym->next;
            bkt_pos++;
        }

        _new->bkt_pos = bkt_pos;
        sym->next = _new;
    }

    return _new;
}

bool ScopeTable::remove(string lexeme)
{
    int pos = hash(lexeme);

    SymbolInfo* prev = NULL;
    SymbolInfo* sym = hashtable[pos];

    while(sym != NULL)
    {
        if(sym->lexeme == lexeme)
        {
            if(prev) prev->next = sym->next;
            else  hashtable[pos] = sym->next;

            delete sym;
            return true;
        }

        prev = sym;
        sym = sym->next;
    }

    return false;
}

void ScopeTable::print(FILE *fp)
{
    fprintf(fp, "\tScopeTable# %d\n", this->count);

    for(int i=0; i<size; i++)
    {
        SymbolInfo* sym = hashtable[i];
        if(sym == NULL) continue;

        fprintf(fp, "\t%d--> ", (i+1));
        
        while(sym != NULL)
        {
            if(!sym->isFunc) fprintf(fp, "<%s,%s> ", sym->lexeme.data(), sym->token.data());
            else    fprintf(fp, "<%s,%s,%s> ", sym->lexeme.data(), sym->token.data(),sym->data_type.data());
            sym = sym->next;
        }
        fprintf(fp, "\n");
    }
}

