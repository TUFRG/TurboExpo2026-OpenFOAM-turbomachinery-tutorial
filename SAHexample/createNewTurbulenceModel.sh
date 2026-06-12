#!/bin/bash

# by Jeff Defoe, June 2026
# checked against OpenFOAM v2412

set -e

# figure out where in the source code there are files for the SA model
find $FOAM_SRC -name SpalartAllmaras*
# see that much is in TurbulenceModels, with some other things in optimization
# filter out stuff there AFTER compilation (lnInclude directories)
find $FOAM_SRC/TurbulenceModels -name SpalartAllmaras* | grep -v lnInclude
# We see there are 3 places where files show up -- DES, RAS, and Base
# Not interested in using for DES so focus on RAS and Base
find $FOAM_SRC/TurbulenceModels -name SpalartAllmaras* | grep -v lnInclude | grep RAS
# the .H and .C files in this folder can be browsed to see what they contain:
less $FOAM_SRC/TurbulenceModels/turbulenceModels/RAS/SpalartAllmaras/SpalartAllmaras.H
less $FOAM_SRC/TurbulenceModels/turbulenceModels/RAS/SpalartAllmaras/SpalartAllmaras.C
# We can see these are just class definitions which don't have the details of the models. Nevertheless we will need these files. Let's copy them over to our local working folder.
mkdir -p turbulenceModels/RAS
cp -r $FOAM_SRC/TurbulenceModels/turbulenceModels/RAS/SpalartAllmaras turbulenceModels/RAS/
# Now let's check the "Base" files:
find $FOAM_SRC/TurbulenceModels -name SpalartAllmaras* | grep -v lnInclude | grep Base
# the .H and .C files in this folder can be browsed to see what they contain:
less $FOAM_SRC/TurbulenceModels/turbulenceModels/Base/SpalartAllmaras/SpalartAllmarasBase.H
less $FOAM_SRC/TurbulenceModels/turbulenceModels/Base/SpalartAllmaras/SpalartAllmarasBase.C
# Here we see the definition of the Stilda function
cat $FOAM_SRC/TurbulenceModels/turbulenceModels/Base/SpalartAllmaras/SpalartAllmarasBase.C | grep -A20 ::Stilda
# This is where we will need to change things. So copy these files over.
mkdir -p turbulenceModels/Base
cp -r $FOAM_SRC/TurbulenceModels/turbulenceModels/Base/SpalartAllmaras turbulenceModels/Base/
# Need to get transport/thermophysical fluid model files to update as well. We don't need to replicate everything here as we only want to add just the new turbulence model to our custom libraries, not everything.
# Start with incompressible. We're looking for things that tell it to create the SA model.
ls $FOAM_SRC/TurbulenceModels/incompressible
ls $FOAM_SRC/TurbulenceModels/incompressible/Make
# Check the files in here to see what we need
less $FOAM_SRC/TurbulenceModels/incompressible/Make/files
less $FOAM_SRC/TurbulenceModels/incompressible/Make/options
# Here we see a list of things to compile, and note that outside of the RAS subheading we see a "turbulentTransportModels.C" file referenced that we haven't copied over yet.
mkdir -p incompressible/turbulentTransportModels
mkdir -p incompressible/Make
cp $FOAM_SRC/TurbulenceModels/incompressible/Make/* incompressible/Make/
cp -r $FOAM_SRC/TurbulenceModels/incompressible/turbulentTransportModels/turbulentTransportModels.* incompressible/turbulentTransportModels/
# Now let's move on to the compressible version.
ls $FOAM_SRC/TurbulenceModels/compressible
ls $FOAM_SRC/TurbulenceModels/compressible/Make
# Check the files in here to see what we need
less $FOAM_SRC/TurbulenceModels/compressible/Make/files
less $FOAM_SRC/TurbulenceModels/compressible/Make/options
# We see that there are two things that it seems we need: compressibleTurbulenceModel.C and turbulentFluidThermoModels/turbulentFluidThermoModels.C.
# Looking at turbulentFluidThermoModels/turbulentFluidThermoModels.H we see it references another header file in this folder (makeTurbulenceModel.H), which we will need too.
mkdir -p compressible/turbulentFluidThermoModels
mkdir -p compressible/Make
cp $FOAM_SRC/TurbulenceModels/compressible/Make/* compressible/Make/
cp $FOAM_SRC/TurbulenceModels/compressible/compressibleTurbulenceModel.* compressible/
cp $FOAM_SRC/TurbulenceModels/compressible/turbulentFluidThermoModels/makeTurbulenceModel.H compressible/turbulentFluidThermoModels/
cp $FOAM_SRC/TurbulenceModels/compressible/turbulentFluidThermoModels/turbulentFluidThermoModels.* compressible/turbulentFluidThermoModels/
# Now we have all the files we need.
# We want to change some folder/file names and content to avoid anything in our new model having the same name as the "regular" SA model.
cp turbulenceModels/RAS
mv SpalartAllmaras SpalartAllmarasH
cd SpalartAllmarasH
mv SpalartAllmaras.H SpalartAllmarasH.H
mv SpalartAllmaras.C SpalartAllmarasH.C
# Replace all instances of "SpalartAllmaras" with "SpalartAllmarasH":
sed -i 's/SpalartAllmaras/SpalartAllmarasH/g' SpalartAllmarasH.H
sed -i 's/SpalartAllmaras/SpalartAllmarasH/g' SpalartAllmarasH.C
cd ../..
cd Base
mv SpalartAllmaras SpalartAllmarasH
cd SpalartAllmarasH
mv SpalartAllmarasBase.H SpalartAllmarasHBase.H
mv SpalartAllmarasBase.C SpalartAllmarasHBase.C
sed -i 's/SpalartAllmaras/SpalartAllmarasH/g' SpalartAllmarasHBase.H
sed -i 's/SpalartAllmaras/SpalartAllmarasH/g' SpalartAllmarasHBase.C
# OK now we've avoided naming conflicts. But we need to add the modified mathematics!
# In the header (H) file we need to add a field declaration for normalized helicity:
sed -i '/tmp<volScalarField> Omega/a \        tmp<volScalarField> h(const volVectorField& U) const;' SpalartAllmarasHBase.H
# In the main source (C) file we need to add a definition for the h field, and also modify the Stilda definition to use this.
# Add 8 lines to define new field:
sed -i '/tmp<volScalarField> SpalartAllmarasHBase<BasicEddyViscosityModel>::r/i\
tmp<volScalarField> SpalartAllmarasHBase<BasicEddyViscosityModel>::h \
( \
    const volVectorField& U \
) const \
{ \
    return (mag((U)&fvc::curl(U))/(max(mag(U)*mag(fvc::curl(U)),dimensionedScalar("small", dimensionSet(0, 1, -2, 0, 0,0),SMALL)))); \
} \
template<class BasicEddyViscosityModel>'  SpalartAllmarasHBase.C
# Add line: const volScalarField h(this->h(this->U_));
# After: const volScalarField Omega(this->Omega(gradU));
sed -i '/const volScalarField Omega(this->Omega(gradU));/a \        const volScalarField h(this->h(this->U_));' SpalartAllmarasHBase.C
# Replace:             Omega + fv2(chi, fv1)*nuTilda_/sqr(kappa_*dTilda),
# With:             (1.0+0.71*pow(h,0.6))*Omega + fv2(chi, fv1)*nuTilda_/sqr(kappa_*dTilda),
sed -i 's/Omega + fv2/(1.0+0.71*pow(h,0.6))*Omega + fv2/g' SpalartAllmarasHBase.C
# Now work with the version-specific files in the incompressible folder.
cd incompressible
cd turbulentTransportModels
mv turbulentTransportModels.H myTurbulentTransportModels.H
mv turbulentTransportModels.C myTurbulentTransportModels.C
# modify content of C file (no changes needed to H file):
sed -i 's/turbulentTransportModels.H/myTurbulentTransportModels.H/g' myTurbulentTransportModels.C
sed -i 's/SpalartAllmaras/SpalartAllmarasH/g' myTurbulentTransportModels.C
sed -i '/makeRASModel(SpalartAllmarasH);/q' myTurbulentTransportModels.C
tac myTurbulentTransportModels.C | sed '/Laminar/,+1d' | tac > tmp.C
mv tmp.C myTurbulentTransportModels.C
# Set up files in Make folder:
cd ../Make
sed -i 's/turbulentTransportModels.C/myTurbulentTransportModels.C/g' files
sed -i 's/FOAM_LIBBIN/FOAM_USER_LIBBIN/g' files
sed -i 's/libincompressibleTurbulenceModels/libSAHIncompressibleTurbulenceModel/g' files
cat files | grep my > tmp
cat files | grep LIB >> tmp
mv tmp files
sed -i 's/transportModels/transportModels \\/g' options
sed -i 's/TransportModels/TransportModels \\/g' options
sed -i '/transportModels/a \    -I$(LIB_SRC)\/TurbulenceModels\/turbulenceModels\/lnInclude \\ \
\    -I$(LIB_SRC)\/TurbulenceModels\/incompressible\/lnInclude' options
sed -i '/incompressibleTransportModels/a \    -lincompressibleTurbulenceModels' options
# Now do the equivalent work in the compressible folder.
cd ../../compressible/turbulentFluidThermoModels
mv turbulentFluidThermoModels.H myTurbulentFluidThermoModels.H
mv turbulentFluidThermoModels.C myTurbulentFluidThermoModels.C
# modify content of C file (no changes needed to H files):
sed -i 's/turbulentFluidThermoModels.H/myTurbulentFluidThermoModels.H/g' myTurbulentFluidThermoModels.C
sed -i 's/SpalartAllmaras/SpalartAllmarasH/g' myTurbulentFluidThermoModels.C
sed -i '/makeRASModel(SpalartAllmarasH);/q' myTurbulentFluidThermoModels.C
tac myTurbulentFluidThermoModels.C | sed '/Laminar/,+1d' | tac > tmp.C
mv tmp.C myTurbulentFluidThermoModels.C
cd ../..
# Set up files in Make folder:
sed -i 's/turbulentFluidThermoModels.C/myTurbulentFluidThermoModels.C/g' files
sed -i 's/FOAM_LIBBIN/FOAM_USER_LIBBIN/g' files
sed -i 's/libcompressibleTurbulenceModels/libSAHCompressibleTurbulenceModel/g' files
sed -i 's/thermophysicalProperties\/lnInclude/thermophysicalProperties\/lnInclude \\/g' options
sed -i '/thermophysicalProperties/a \    -I$(LIB_SRC)\/TurbulenceModels\/turbulenceModels\/lnInclude \\ \
    -I$(LIB_SRC)\/TurbulenceModels\/compressible\/lnInclude' options
sed -i 's/lspecie/lspecie \\/g' options
sed -i '/lspecie/a \    -lcompressibleTurbulenceModels' options

# Finally, compile both models:
cd incompressible
wclean
wmakeLnInclude -u ../turbulenceModels
wmake
cd ..
cd compressible
wclean
wmakeLnInclude -u ../turbulenceModels
wmake
cd ..
