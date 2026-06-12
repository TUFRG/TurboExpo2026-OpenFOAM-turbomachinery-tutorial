#!/bin/bash

set -e

# uncompress files that are compressed to minimize size of repository
unxz rotor19_level1.msh.xz
unxz stator36_shortForOF_level1.msh.xz
cd meshSetup/constant_upstream/geometry
unxz hub.stl.xz
unxz mPer.stl.xz
unxz outlet.stl.xz
cd ../../..
