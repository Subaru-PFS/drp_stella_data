#!/usr/bin/env bash

usage() {
    # Display usage and quit
    echo "Create simulated images for the integration test." 1>&2
    echo "" 1>&2
    echo "Usage: $0 [-f FIBERS] [-j NUMCORES] [-n]" 1>&2
    echo "" 1>&2
    echo "    -j <NUMCORES> : number of cores to use" 1>&2
    echo "    -s : seed for makePfsDesign file generation (None for no seed)" 1>&2
    echo "    -n : don't actually run the simulator" 1>&2
    echo "" 1>&2
    exit 1
}

# Parse command-line arguments
NUMCORES=1
DRYRUN=false
# By default, use a fixed seed for reproducability
SEED=123
while getopts "hf:j:s:n" opt; do
    case "${opt}" in
        j)
            NUMCORES=${OPTARG}
            ;;
        s)
            SEED=${OPTARG}
            ;;
        n)
            DRYRUN=true
            ;;
        h | *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
if [ -n "$1" ]; then
    usage
fi

# Handle situation where user 
# explicitly requests no fixed seed
if [ "$SEED" = "None" ] || [ "$SEED" = "none" ]; then
  echo "Assigning a non-deterministic RNG seed."
  seedstr=""
else
  seedstr="--seed=${SEED}"
fi

set -e

# Make PfsDesign
# 1: Base design: 20% sky, 10% fluxstd, rest galaxies
# 2: Shuffled w.r.t. 1
# 3: Odd fibers of 1
# 4: Even fibers of 1
# Yabe-san likes having objId = 0x12, 0x37, 0x69 (18,55,105) in the set
( $DRYRUN ) || makePfsDesign --fibers fifteen --pfsDesignId 1 --scienceCatId 1 --fracSky 0.35 --fracFluxStd 0.2 --scienceObjId "18 55 71 76 93 94 105" ${seedstr}
( $DRYRUN ) || transmutePfsDesign 1 shuffle 2
( $DRYRUN ) || transmutePfsDesign 1 odd 3
( $DRYRUN ) || transmutePfsDesign 1 even 4

makeSimExposure() {
    for detector in r1 b1; do
        COMMANDS+=("$( ( $DRYRUN ) && echo "echo " )makeSim --detector $detector $([ $detector = "r1" ] && echo "--pfsConfig") $(echo "$@" | sed "s|@DETECTOR@|$detector|g")")
    done
}

COMMANDS=()
makeSimExposure --pfsDesignId 1 --exptime 0 --visit 0 --visit 1 --visit 2 --visit 3 --visit 4 --type bias
makeSimExposure --pfsDesignId 1 --exptime 900 --visit 5 --visit 6 --visit 7 --visit 8 --visit 9 --visit 10 --type dark
makeSimExposure --pfsDesignId 1 --exptime 30 --visit 11 --visit 12 --type flat --xoffset 0
makeSimExposure --pfsDesignId 1 --exptime 30 --visit 13 --visit 14 --type flat --xoffset 2000
makeSimExposure --pfsDesignId 1 --exptime 30 --visit 15 --visit 16 --type flat --xoffset 4000
makeSimExposure --pfsDesignId 1 --exptime 30 --visit 17 --visit 18 --visit 19 --type flat --xoffset -2000
makeSimExposure --pfsDesignId 1 --exptime 30 --visit 20 --visit 21 --type flat --xoffset -4000
makeSimExposure --pfsDesignId 1 --exptime 2 --visit 22 --type arc --lamps NE
makeSimExposure --pfsDesignId 1 --exptime 5 --visit 23 --type arc --lamps HG
makeSimExposure --pfsDesignId 1 --exptime 900 --visit 24 --type object
makeSimExposure --pfsDesignId 2 --exptime 900 --visit 25 --type object
makeSimExposure --pfsDesignId 3 --exptime 30 --visit 26 --type flat --xoffset 0 --imagetyp flat_odd
makeSimExposure --pfsDesignId 4 --exptime 30 --visit 27 --type flat --xoffset 0 --imagetyp flat_even

IFS=$'\n' printf '%s\n' "${COMMANDS[@]}" | xargs -d $'\n' -n 1 -P $NUMCORES --verbose sh -c
