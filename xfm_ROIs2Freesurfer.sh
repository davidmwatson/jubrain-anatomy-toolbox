#!/usr/bin/env bash

# Transform ROIs to Freesurfer labels on fsaverage surface.
# Requires that xfm_ROIs2FSL.sh has been run

source /etc/freesurfer/6.0/freesurfer.sh

set -eu


### Key vars ###

basedir=./JuBrain_ROIs/
indir=$basedir/FSL_1mm/
outbase=$basedir/freesurfer/

fsaverages=(fsaverage fsaverage6 fsaverage5 fsaverage4)

non_surf_ROIs=(Amygdala Cerebellum Hippocampus Bforebrain Cingulum)


### Begin ###

# Loop fsaverage subjects
for fsaverage in ${fsaverages[@]}; do
    echo -e "\n$fsaverage"

    # Set outdir
    outdir=$outbase/$fsaverage/
    mkdir -p $outdir

    ## Full prob maps
    echo -e "\tFull probability maps..."

    for hemi in lh rh; do
        mri_vol2surf --mov $indir/FullProb.nii.gz --trgsubject $fsaverage \
            --hemi $hemi --mni152reg --projfrac-avg 0 1 0.1 \
            --interp trilinear --o $outdir/FullProb.${hemi}.mgz &> /dev/null
    done

    cp $indir/ROI_names.txt $outdir/


    ## Max prob maps
    echo -e "\tMax probability maps..."

    # Glob & loop ROIs
    infiles=$(find $indir/ -maxdepth 1 -type f -name *.nii.gz -not -name FullProb.nii.gz | sort)
    for infile in $infiles; do
        ROI=$(basename $infile .nii.gz)

        isOkay=1
        for non_surf_ROI in ${non_surf_ROIs[@]}; do
            if [[ $ROI == *"$non_surf_ROI"* ]]; then
                isOkay=0
            fi
        done

        if [[ $isOkay -ne 1 ]]; then
            continue
        fi

        echo -e "\t\t$ROI"

        # Work out some details
        FSL_hemi=$(echo $ROI | cut -d "_" -f 1)
        ROI_sans_hemi=$(echo $ROI | cut -d "_" -f 2-)

        if [[ $FSL_hemi == "Left" ]]; then
            FS_hemi=lh
        elif [[ $FSL_hemi == "Right" ]]; then
            FS_hemi=rh
        fi

        # First, transform from vol to surface, output to temporary file
        tmp=$(mktemp --suffix=.mgz)
        mri_vol2surf --mov $infile --trgsubject $fsaverage --hemi $FS_hemi \
            --mni152reg --projfrac-max 0 1 0.1 --interp nearest \
            --o $tmp &> /dev/null

        # Now convert surface to label file. Sometimes this errors (e.g. if
        # not enough vertices) so include some error handling
        { mri_cor2label --i $tmp --id 1 --surf $fsaverage $FS_hemi white \
            --l $outdir/${FS_hemi}.${ROI_sans_hemi}.label &> /dev/null
        } || {
            echo -e "\t\tConversion to label failed!"
        }

        # Clean up temporary surface file
        rm $tmp

    done
done

echo -e "\nDone\n"

