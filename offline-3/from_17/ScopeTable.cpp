
/*
 *
 * Hash Table : Separate Chaining Method
 *
 * - Md. Zarif Ul Alam
 * Staring at : 16 November 2020 6:10pm
 *
 * */


/* Which of the favors of your Lord will you deny ? */

#include<bits/stdc++.h>
#include <string>
#include "SymbolInfo.h"
#include "ScopeTable.h"
using namespace std;

ScopeTable::~ScopeTable() /// destructor
{
//    cout<<"ScopeTable memory deallocated"<<endl;

    for(int i=0; i<ht.size(); i++)
    {
        SymbolInfo* now = ht[i];

        while(now != NULL)
        {
            SymbolInfo* tmp = now->nxt;
            delete now;
            now = tmp;
        }
    }
}

string ScopeTable::get_id()
{
    return id;
}
void ScopeTable::set_id(string id)
{
    this->id = id;
}

int ScopeTable::get_counter()
{
    return counter;
}
void ScopeTable::set_counter(int counter)
{
    this->counter = counter;
}

void ScopeTable::increase_counter()
{
    counter++;
}

int ScopeTable::hash(string key)
{
    int ret = (hashValue(key) % M);
    return ret;
}

SymbolInfo* ScopeTable::search(string key)
{
    int bucket = hash(key);
    int bucket_pos = 0;

    SymbolInfo* now = ht[bucket];

    while(now != NULL)
    {
        if(now->key == key)
        {
            now->bucket_pos = bucket_pos;
            return now;
        }

        now = now->nxt;
        bucket_pos++;
    }

    return NULL; /*not found*/
}

SymbolInfo* ScopeTable::insert(SymbolInfo si)
{
    string key = si.key;
    string val = si.val;
    string var_type = si.var_type;
    vector<string>param_v = si.param_v;
    bool isFunctionDeclaration = si.isFunctionDeclaration;
    bool isFunction = si.isFunction;

    int bucket = hash(key);

    SymbolInfo* to_insert = new SymbolInfo(key,val,var_type,param_v,isFunctionDeclaration,isFunction,NULL);
    to_insert->bucket = bucket;

    assert(bucket<M);

    if(ht[bucket] == NULL) ht[bucket] = to_insert , to_insert->bucket_pos = 0;
    else
    {
        SymbolInfo* now = ht[bucket];
        if(now->key == key) return NULL; /*already exists*/

        int bucket_pos = 1;

        while(now->nxt != NULL)
        {
            if(now->key == key)
                return NULL; /*already exists*/

            now = now->nxt;
            bucket_pos++;
        }

        to_insert->bucket_pos = bucket_pos;
        now->nxt = to_insert;
    }

    return to_insert;
}

bool ScopeTable::erase(string key)
{
    int idx = hash(key);

    SymbolInfo* prv = NULL;
    SymbolInfo* now = ht[idx];

    while(now != NULL)
    {
        if(now->key == key)
        {
            if(prv) prv->nxt = now->nxt;
            else  ht[idx] = now->nxt;

            delete (now);
            return true;
        }

        prv = now;
        now = now->nxt;
    }

    return false;
}

void ScopeTable::print(FILE *out)
{
    fprintf(out, "ScopeTable # %s\n", id.data());

    for(int i=0; i<M; i++)
    {
        SymbolInfo* now = ht[i];

        if(now == NULL) continue;

        fprintf(out, "%d --> ", i);
        
        while(now != NULL)
        {
            fprintf(out, "< %s , %s >", (now->key).data(), (now->val).data());
            // cout<<"< "<<now->key <<" , "<<now->val<<" > ("<<now->var_type<<")";
            now = now->nxt;
        }
        fprintf(out, "\n");
    }
    fprintf(out, "\n");
}

void ScopeTable::printChainLengths()
{
    for(int i=0; i<M; i++)
    {
        int cnt = 0;

        SymbolInfo* now = ht[i];
        while(now != NULL) now = now->nxt, cnt++;
        cout<<endl;

        cout<<"Chain "<<i<<" : "<<cnt<<endl;
    }
}

