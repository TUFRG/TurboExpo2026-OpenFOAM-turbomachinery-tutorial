#!/bin/bash

set -e

# UP TO HERE
# Need to set up zero folder files
# (p, U, nut, nuTilda)
mkdir -p fullDomain/0
cp 0folderSetup/* fullDomain/0/
# Set BC details for moving and rotating walls and mixing planes
cd fullDomain
changeDictionary -dict system/changeDictionaryDict.fields

# Need to set up constant folder files
# (turbulenceProperties, transportProperties, MRFProperties)
cp ../constantFolderSetup/* constant/

# Parallel decomposition
decomposePar

# Run solver
mpirun -np 6 simpleFoam -parallel > simpleFoam.log 
