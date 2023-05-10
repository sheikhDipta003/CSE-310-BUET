#!/bin/bash

bison -d -y simplecalc.y
echo 'Generated the parser C file as well the header file'
g++ -w -c -o y.o y.tab.c
echo 'Generated the parser object file'
flex simplecalc.l
echo 'Generated the scanner C file'
g++ -fpermissive -w -c -o l.o lex.yy.c
# if the above command doesn't work try g++ -fpermissive -w -c -o l.o lex.yy.c
echo 'Generated the scanner object file'
g++ simplecalcAST.c -c
echo 'Generated the simplecalcAST object file'
g++ simplecalcAST.o y.o l.o -lfl -o simplecalc.out
echo 'All ready, running'
./simplecalc.out
