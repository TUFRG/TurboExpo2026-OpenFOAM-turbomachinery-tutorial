#!/bin/bash

set -e

# Create case dirs for each region
mkdir -p upstream
mkdir -p rotor
mkdir -p stator
mkdir -p downstream
# Copy files for mesh setup
cp -r meshSetup/system upstream/
cp -r meshSetup/constant_upstream upstream/constant
cp -r meshSetup/system rotor/
cp rotor19_level1.msh rotor/rotor.msh
cp -r meshSetup/system stator/
cp stator36_shortForOF_level1.msh stator/stator.msh
cp -r meshSetup/system downstream/

# 1. Generate upstream mesh
cd upstream
blockMesh -dict system/blockMeshDictUpstream # generate structured mesh for inlet region

# 2. Set up rotor mesh
cd ..
cd rotor
fluent3DMeshToFoam rotor.msh
# Need to rotate this mesh to align with the machine axis
#transformPoints -rotate '((1 0 0) (0 0 1))'
mergeOrSplitBaffles -overwrite # gets rid of internal walls between INBLOCK / PASSAGE
# Combine patches on hub and shroud in rotor passage to a single patch each
# Combine the "side" patches to create cyclic (periodic) patches, renames inlet/outlet patches, and removes any empty patches left over from previous operations
createPatch -overwrite -dict system/createPatchDict4rotor

# 3. Set up stator mesh
cd ..
cd stator
fluent3DMeshToFoam stator.msh
mergeOrSplitBaffles -overwrite # gets rid of internal walls between INBLOCK / PASSAGE
# Combine patches on hub and shroud in stator passage to a single patch each
# Combine the "side" patches to create cyclic (periodic) patches, renames inlet/outlet patches, and removes any empty patches left over from previous operations
createPatch -overwrite -dict system/createPatchDict4stator
# Remove cellZones (specifically "passage") so that "passage" is only rotor cells for MRF definition
rm constant/polyMesh/cellZones

# 4. Generate downstream mesh
cd ..
cd downstream
blockMesh -dict system/blockMeshDictNozzle # generate structured mesh for downstream nozzle region

# 5. Combine regions one by one
cd ..
mergeMeshes -overwrite upstream rotor
rm -rf rotor
mergeMeshes -overwrite upstream stator
rm -rf stator
mergeMeshes -overwrite upstream downstream
rm -rf downstream
mv upstream fullDomain

# 6. Define patch types and topology
cd fullDomain
topoSet # This will create the cellZone for the MRF
        # (reads from topoSetDict; zone is created from existing cellSet)
renumberMesh -overwrite
checkMesh
touch LSFsinglePassage.foam
