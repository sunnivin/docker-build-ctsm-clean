#!/bin/bash

#===============================================================================
# CTSM create_newcase template for docker container
#===============================================================================

#----------------------------------------------------------------------------------
# RUN SPECIFIC SETUP - USER TO MODIFY
#----------------------------------------------------------------------------------
# Set a descriptive name for the case to be run
export DESCNAME=ctsm-1x1brazil-sunnivin

# Set debugging option on or off
#export DEBUGGING=FALSE
export DEBUGGING=TRUE

# Set the desired compset - use query_config and/or query_testlist for compset names
# export COMPSET=I2000Clm50BgcCrop
#export COMPSET=I2000Clm50BgcCro
export COMPSET=I2000Clm50SpRs
#export COMPSET=I1850Clm50Sp
#export COMPSET=I2000Clm50SpGs


# Set the resolution
export RESOLUTION=1x1_brazil

# Match the output and input directories to the docker run -v volume mount option
export CASEDIR=/output          # /output is default
export INPUTDIR=/inputdata      # /inputdata is default

#----------------------------------------------------------------------------------
# DOCKER MACHINE SPECIFIC ARGUMENTS - DO NOT CHANGE
#----------------------------------------------------------------------------------
export CATEGORY=fates          # For descriptive use in the casename
export COMPILER=gnu            # Currently only gcc compilers supported
export MODEL_SOURCE=/CTSM      # Location of ctsm hlm
export MACH=${HOSTNAME}        # This is set via --hostname=docker option

#----------------------------------------------------------------------------------
# SETUP DIRECTORY - USER SHOULD NOT NEED TO CHANGE THESE
#----------------------------------------------------------------------------------
# Switch to host land model
echo "Running with CTSM location: "${MODEL_SOURCE}
cd ${MODEL_SOURCE}/cime/scripts

# Setup githash to append to test directory name for reproducability
export CLMHASH=`cd ../../;git log -n 1 --format=%h`
export FATESHASH=`(cd ../../src/fates;git log -n 1 --format=%h)`
export GITHASH="C"${CLMHASH}"-F"${FATESHASH}
export date_var=$(date +"%Y-%m-%d_%H-%M-%S") # auto info tag

# Setup build, run and output directory name
export CASENAME=${CASEDIR}/${DESCNAME}.${CATEGORY}.${MACH}.${GITHASH}.${date_var}

#----------------------------------------------------------------------------------
# CREATE THE CASE
#----------------------------------------------------------------------------------
echo "Calling create_newcase"
rm -rf ${CASENAME} # given the datetime this case dir should be unique

echo "*** start: ${date_var} "
echo "*** Building CASE: ${CASENAME} "
./create_newcase --case=${CASENAME} --res=${RESOLUTION} --compset=${COMPSET} --mach=${MACH} --compiler=${COMPILER} --run-unsupported

# Change to the created case directory
echo "Changing to case directory: " ${CASENAME}
cd ${CASENAME}

#----------------------------------------------------------------------------------
# UPDATE CASE CONFIGURATION - user to update or add as necessary
#----------------------------------------------------------------------------------
echo "Calling xmlchange"

# Change the run time settings
./xmlchange STOP_N=2
./xmlchange STOP_OPTION=nyears

# Change the debugging setup to match above argument
./xmlchange DEBUG=${DEBUGGING}

# Override the .cime configuration default to match the above argument for dir locations
./xmlchange CIME_OUTPUT_ROOT=${CASEDIR}
./xmlchange DIN_LOC_ROOT=${INPUTDIR}
./xmlchange DIN_LOC_ROOT_CLMFORC=${INPUTDIR}/atm/datm7

# Change the output dir for short term archives (i.e. the run logs) - do not change
./xmlchange DOUT_S_ROOT=${CASENAME}/run


echo "Set namelists for production."
# # Switch off cold start
./xmlchange CLM_FORCE_COLDSTART="off"
./xmlchange CONTINUE_RUN="FALSE"
./xmlchange CLM_ACCELERATED_SPINUP="off"

./xmlchange CLM_NML_USE_CASE="2000_control"
./xmlchange RUN_TYPE=startup
./xmlchange DATM_CLMNCEP_YR_ALIGN=2000
./xmlchange DATM_CLMNCEP_YR_START="2000"
./xmlchange DATM_CLMNCEP_YR_END="2010"
./xmlchange DATM_PRESAERO="clim_2000"
./xmlchange CCSM_CO2_PPMV="369."

./xmlchange STOP_OPTION="nyears"
./xmlchange RUN_REFDATE="2000-01-01"
./xmlchange RUN_STARTDATE="2000-01-01"

./xmlchange STOP_N=4
# Frequency of restart files (1/4 of STOP_N)
./xmlchange REST_N=1

# Optimize PE layout for run  - we may need to be careful here
# so as to make this run on a wide range of machines
# Adding in more CPUs may crash some machines
./xmlchange NTASKS_ATM=1,ROOTPE_ATM=0,NTHRDS_ATM=1
./xmlchange NTASKS_CPL=1,ROOTPE_CPL=1,NTHRDS_CPL=1
./xmlchange NTASKS_LND=1,ROOTPE_LND=3,NTHRDS_LND=1
./xmlchange NTASKS_OCN=1,ROOTPE_OCN=1,NTHRDS_OCN=1
./xmlchange NTASKS_ICE=1,ROOTPE_ICE=1,NTHRDS_ICE=1
./xmlchange NTASKS_GLC=1,ROOTPE_GLC=1,NTHRDS_GLC=1
./xmlchange NTASKS_ROF=1,ROOTPE_ROF=1,NTHRDS_ROF=1
./xmlchange NTASKS_WAV=1,ROOTPE_WAV=1,NTHRDS_WAV=1
./xmlchange NTASKS_ESP=1,ROOTPE_ESP=1,NTHRDS_ESP=1

# Set run location to case dir
./xmlchange --file env_build.xml --id CIME_OUTPUT_ROOT --val ${CASENAME}


# set MPILIB to mpi-serial so that you can run interactively
 ./xmlchange MPILIB=mpi-serial

#----------------------------------------------------------------------------------
# SETUP AND BUILD THE CASE
#----------------------------------------------------------------------------------
echo "Setting up case"
./case.setup
./preview_namelists

echo "Building case"
./case.build

#echo "*** Finished building new case in CASE: ${CASENAME} ***"
echo " "
echo " "
echo " "

# MANUALLY SUBMIT CASE
echo "*****************************************************************************************************"
echo "If you built this case interactively then:"
echo "To submit the case change directory to ${CASENAME} and run ./case.submit"
echo " "
echo " "
echo "If you built this case non-interactively then change your Docker run command to:"
echo " "
echo 'docker run -t -i --hostname=docker --user $(id -u):$(id -g) --volume /path/to/host/inputs:/inputdata \
--volume /path/to/host/outputs:/output docker_image_tag' "/bin/sh -c 'cd ${CASENAME} && ./case.submit'"
echo " "
echo "Where: "
echo "/path/to/host/inputs is your host input path, such as /Volumes/data/Model_Data/cesm_input_datasets"
echo "/path/to/host/outputs is your host output path, such as ~/scratch/ctsm_fates"
echo "/path/to/host/outputs is the docker image tag on your host machine, e.g. ngeetropics/fates-ctsm-gcc650:latest"
echo " "

#eof
