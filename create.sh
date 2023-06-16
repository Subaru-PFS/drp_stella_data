#!/usr/bin/env bash

usage() {
    # Display usage and quit
    echo "Create simulated images for the integration test." 1>&2
    echo "" 1>&2
    echo "Usage: $0 [-j NUMCORES] [-n] <PFS_DESIGN_ID>" 1>&2
    echo "" 1>&2
    echo "    -j <NUMCORES> : number of cores to use" 1>&2
    echo "    -d <OBJ_SPECTRA_DIR> : directory containing object spectra" 1>&2
    echo "    -n : don't actually run the simulator" 1>&2
    echo "    <PFS_DESIGN_ID> : pfsDesignId for base design" 1>&2
    echo "" 1>&2
    echo "The pfsDesign file for the provided pfsDesignId must exist in the" 1>&2
    echo "current directory." 1>&2
    echo "" 1>&2
    exit 1
}

# Parse command-line arguments
NUMCORES=1
DRYRUN=false
OBJ_SPECTRA_DIR=
while getopts "d:hj:n" opt; do
    case "${opt}" in
        d)
            OBJ_SPECTRA_DIR=${OPTARG}
            ;;
        j)
            NUMCORES=${OPTARG}
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
PFS_DESIGN_ID=$1; shift
if [[ -n "$1" || -z "$PFS_DESIGN_ID" ]]; then
    usage
fi

if [ -d "$OBJ_SPECTRA_DIR" ]; then
    echo "Reading object spectra from $OBJ_SPECTRA_DIR .."
else
    echo "$OBJ_SPECTRA_DIR does not exist."
    exit 1
fi

catConfig=$OBJ_SPECTRA_DIR/catalog_config.yaml
if [ -f "$catConfig" ]; then
    echo "Reading catalog config from $catConfig .."
else
    echo "$catConfig does not exist."
    exit 1
fi

# Make PfsDesigns
ALT_DESIGN_ID=$((PFS_DESIGN_ID + 1))  # Alternate design: shuffled w.r.t. base
ODD_DESIGN_ID=$((PFS_DESIGN_ID + 2))  # Odd fibers of base
EVEN_DESIGN_ID=$((PFS_DESIGN_ID + 3))  # Even fibers of base
( $DRYRUN ) || transmutePfsDesign $PFS_DESIGN_ID shuffle $ALT_DESIGN_ID
( $DRYRUN ) || transmutePfsDesign $PFS_DESIGN_ID odd $ODD_DESIGN_ID
( $DRYRUN ) || transmutePfsDesign $PFS_DESIGN_ID even $EVEN_DESIGN_ID

makeSimExposure() {
    for detector in r1 b1; do
        COMMANDS+=("$( ( $DRYRUN ) && echo "echo " )makeSim --detector $detector $([ $detector = "r1" ] && echo "--pfsConfig") $(echo "$@" | sed "s|@DETECTOR@|$detector|g")")
    done
}

COMMANDS=()
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 0 --visit 0 --visit 1 --visit 2 --visit 3 --visit 4 --type bias
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 900 --visit 5 --visit 6 --visit 7 --visit 8 --visit 9 --visit 10 --type dark
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 30 --visit 11 --visit 12 --type flat --xoffset 0
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 30 --visit 13 --visit 14 --type flat --xoffset 2000
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 30 --visit 15 --visit 16 --type flat --xoffset 4000
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 30 --visit 17 --visit 18 --visit 19 --type flat --xoffset -2000
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 30 --visit 20 --visit 21 --type flat --xoffset -4000
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 2 --visit 22 --type arc --lamps NE
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 5 --visit 23 --type arc --lamps HG
makeSimExposure --pfsDesignId $PFS_DESIGN_ID --exptime 900 --visit 24 --type object  --objSpectraDir $OBJ_SPECTRA_DIR
makeSimExposure --pfsDesignId $ALT_DESIGN_ID --exptime 900 --visit 25 --type object  --objSpectraDir $OBJ_SPECTRA_DIR
makeSimExposure --pfsDesignId $ODD_DESIGN_ID --exptime 30 --visit 26 --type flat --xoffset 0 --imagetyp flat_odd
makeSimExposure --pfsDesignId $EVEN_DESIGN_ID --exptime 30 --visit 27 --type flat --xoffset 0 --imagetyp flat_even

IFS=$'\n' printf '%s\n' "${COMMANDS[@]}" | xargs -d $'\n' -n 1 -P $NUMCORES --verbose sh -c
