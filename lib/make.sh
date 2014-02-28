#!/bin/bash

JJ=`which jags`
JP=${JJ%/*/*}
JI=${JP}/include/JAGS
JL=${JP}/lib

# libltdl is currently needed

g++ -Wall -shared -fPIC jags.cc -I ${JI} -L ${JL} -ljags -lltdl -o jags.so

echo const modpath = \"${JL}/JAGS/modules-3\" > ../src/modpath.jl
