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

# Glob & loop ROIs
for infile in $(find $indir/ -maxdepth 1 -type f -name *.nii.gz | sort); do
    ROI=$(basename $infile)
    echo $ROI
    
    # Convert SPM -> FSL 1mm space (really just needs to change matrix size)
    # I stole this from:
    # * https://neuroimaging-core-docs.readthedocs.io/en/latest/pages/image_processing_tips.html
    # * https://bitbucket.org/dpat/tools/raw/master/LIBRARY/spm2fsl.sh
    flirt -in $infile -ref $FSLDIR/data/standard/MNI152_T1_1mm.nii.gz \
        -applyxfm -usesqform -noresampblur -interp nearestneighbour \
        -out $outdir1/$ROI -datatype short
        
    # Convert FSL 1mm -> 2mm
    flirt -in $outdir1/$ROI -ref $FSLDIR/data/standard/MNI152_T1_2mm.nii.gz \
        -applyxfm -noresampblur -init $FSLDIR/etc/flirtsch/ident.mat \
        -interp nearestneighbour -out $outdir2/$ROI -datatype short
        
done

echo -e "\nDone\n"

#flirt -in Left_AIPS_IP1.nii.gz -ref /usr/share/fsl-5.0/data/standard/MNI152_T1_1mm -applyxfm -usesqform -noresampblur -interp nearestneighbour -out foo_short.nii.gz -datatype short

#flirt -in /home/d/dw545/git-repos/jubrain-anatomy-toolbox/JuBrain_ROIs/1mm/Left_AIPS_IP1.nii.gz -applyxfm -init /usr/share/fsl-5.0/etc/flirtsch/ident.mat -out /home/d/dw545/git-repos/jubrain-anatomy-toolbox/JuBrain_ROIs/2mm/Left_AIPS_IP1.nii.gz -paddingsize 0.0 -interp trilinear -ref /usr/share/fsl/data/standard/MNI152_T1_2mm.nii.gz

