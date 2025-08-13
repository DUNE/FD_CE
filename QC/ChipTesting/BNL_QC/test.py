import sys
import numpy as np
import copy
import os

####### Input test information #######
#Red = '\033[91m'
#Green = '\033[92m'
#Blue = '\033[94m'
#Cyan = '\033[96m'
#White = '\033[97m'
#Yellow = '\033[93m'
#Magenta = '\033[95m'
#Grey = '\033[90m'
#Black = '\033[90m'
#Default = '\033[99m'
index_f = "./kk.csv"

env = "RT"

tmps = []
with open(index_f, 'r') as fp:
    for cl in fp:
        tmp = cl.split(",")
        if "env" in tmp[0]:
            tmp[1] = env
        cln=','.join(tmp)
        tmps.append(cln)

with open(index_f, 'w') as fp:
    for cl in tmps:
        fp.write(cl)
