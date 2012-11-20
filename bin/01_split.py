#!/usr/bin/python

import sys

byName = {}
regionfile = sys.argv[1]

for line in open(regionfile):
    f = line.strip().split()
    name = f[3]
    if name in byName:
        byName[name] += line
    else:
        byName[name] = line

for name in byName:
    fh = open("%s.txt" % (name), 'w')
    print >> fh, byName[name],
    fh.close()

    
