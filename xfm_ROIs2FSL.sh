#!/usr/bin/env bash

# Takes ROIs in SPM's 1mm MNI space (manually exported from SPM) and transforms
# them to FSL MNI space (1mm and 2mm)

source /etc/fsl/5.0/fsl.sh

set -eu

### Key vars ###

basedir=./JuBrain_ROIs/
indir=$basedir/SPM_1mm
outdir1=$basedir/FSL_1mm
outdir2=$basedir/FSL_2mm


### Begin ###

# Make outdirs?
mkdir -p $outdir1
mkdir -p $outdir2

## Convert full prob maps
echo -e "\nFull probability maps..."
# Convert SPM -> FSL 1mm space (really just needs to change matrix size)
# I stole this from:
# * https://neuroimaging-core-docs.readthedocs.io/en/latest/pages/image_processing_tips.html
# * https://bitbucket.org/dpat/tools/raw/master/LIBRARY/spm2fsl.sh
flirt -in $indir/FullProb.nii.gz -ref $FSLDIR/data/standard/MNI152_T1_1mm.nii.gz \
    -applyxfm -usesqform -noresampblur -interp trilinear \
    -out $outdir1/FullProb.nii.gz

cp $indir/ROI_names.txt $outdir1/

# Convert FSL 1mm -> 2mm
flirt -in $outdir1/FullProb.nii.gz -ref $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz \
    -applyxfm -noresampblur -init $FSLDIR/etc/flirtsch/ident.mat \
    -interp nearestneighbour -out $outdir2/FullProb.nii.gz

cp $indir/ROI_names.txt $outdir2/


## Convert max prob maps
echo -e "\nMax probability maps..."

# Glob & loop ROIs
infiles=$(find $indir/ -maxdepth 1 -type f -name *.nii.gz -not -name FullProb.nii.gz | sort)
for infile in $infiles; do
    ROI=$(basename $infile)
    echo -e "\t$ROI"

    # Convert SPM -> FSL 1mm space (really just needs to change matrix size)
    flirt -in $infile -ref $FSLDIR/data/standard/MNI152_T1_1mm.nii.gz \
        -applyxfm -usesqform -noresampblur -interp nearestneighbour \
        -out $outdir1/$ROI -datatype char

    # Convert FSL 1mm -> 2mm
    flirt -in $outdir1/$ROI -ref $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz \
        -applyxfm -noresampblur -init $FSLDIR/etc/flirtsch/ident.mat \
        -interp nearestneighbour -out $outdir2/$ROI -datatype char
done

echo -e "\nDone\n"

