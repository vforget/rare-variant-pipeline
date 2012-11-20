#!/bin/bash

chrom=$1
genfile=$2
db=~/tempdata/polyphen/polyphen-2.2.2-whess-2011_12.sqlite

while read chrpos nt1 nt2
do
    sqlite3 -column $db "SELECT chrom||':'||chrpos AS chrpos,refa,txname||strand AS txname,gene,nt1,nt2,acc,pos,aa1,aa2,hdiv_prediction,hdiv_prob,hvar_prediction,hvar_prob FROM features JOIN scores USING(id) WHERE chrom=\"chr$chrom\" AND chrpos=$chrpos AND nt1=\"$nt1\" AND nt2=\"$nt2\";"
done < <(cut -f 3,4,5 -d ' ' $genfile)

