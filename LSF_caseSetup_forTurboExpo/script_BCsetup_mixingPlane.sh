#!/bin/bash

set -e

cp mixingPlaneSetup/system/* fullDomain/system/
cp mixingPlaneSetup/setBatchMixingPlane fullDomain/

cd fullDomain
# Change interface patch names
createPatch -dict system/createPatch.interfaces -overwrite
# Create sets corresponding to each interface, required for making zones
setSet -batch setBatchMixingPlane
# Create zones from sets, required for mixing planes
setsToZones -noFlipMap
# Set up details of mixing planes in constant/polyMesh/boundary
changeDictionary -noZero -constant -dict system/changeDictionaryDict.boundary


# Note decomposePar contains special setup

# Note fvSolution contains special setup

# Note fvSchemes contains special setup

