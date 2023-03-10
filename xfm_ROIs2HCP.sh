#!/usr/bin/env bash

# Transform ROIs to CIFTI files on HCP fsLR32k surface
#
# Requires S1200 group average surfaces, downloadable from ConnectomeDB; path
# is hardcoded in script - update this as necessary.
#
# Saves out a single dlabel containing all ROIs. To export a specific ROI:
# > wb_command -cifti-label-to-roi /path/to/JuBrain_ROIs.dlabel.nii \
# >     /path/to/output.dscalar.nii -name <ROI_name>

set -eu

### Key vars ###

basedir=./JuBrain_ROIs/
indir=$basedir/SPM_1mm/
outdir=$basedir/HCP/fsLR32k
HCP_anatdir=/groups/labs/facelab/Datasets/HCP/HCP_S1200_GroupAvg_v1/

non_surf_ROIs=(Amygdala Cerebellum Hippocampus Bforebrain Cingulum)


### Begin ###

# Make outdir
mkdir -p $outdir

# Make temporary output directory for storing intermediate results
tmpoutdir=$(mktemp -d)

# Set path to HCP MNI volume
HCP_vol=$HCP_anatdir/S1200_AverageT1w_restore.nii.gz


### Full probability maps
echo -e "\nFull probability maps..."

# Resample to HCP MNI volume
# (wb_command -volume-resample <infile> <ref_vol> <method> <outfile>
wb_command -volume-resample $indir/FullProb.nii.gz $HCP_vol TRILINEAR \
    $tmpoutdir/FullProb.nii.gz

# Transform vol -> surf GIFTIs for each hemisphere
# (wb_command -volume-to-surface-mapping <infile> <surface> <outfile> \
#  -ribbon-constrained <inner-surf> <outer-surf>)
for HCP_hemi in L R; do
    HCP_mid_surf=$HCP_anatdir/S1200.${HCP_hemi}.midthickness_MSMAll.32k_fs_LR.surf.gii
    HCP_inner_surf=$HCP_anatdir/S1200.${HCP_hemi}.white_MSMAll.32k_fs_LR.surf.gii
    HCP_outer_surf=$HCP_anatdir/S1200.${HCP_hemi}.pial_MSMAll.32k_fs_LR.surf.gii

    wb_command -volume-to-surface-mapping \
        $tmpoutdir/FullProb.nii.gz $HCP_mid_surf \
        $tmpoutdir/${HCP_hemi}.FullProb.func.gii \
        -ribbon-constrained $HCP_inner_surf $HCP_outer_surf
done

# Merge GIFTIs over hemis to CIFTI, add ROI names from file
# (wb_command -cifti-create-dense-scalar <outfile> \
#  -left-metric <left-input> -right-metric <right-input>)
wb_command -cifti-create-dense-scalar $outdir/FullProb.dscalar.nii \
    -left-metric $tmpoutdir/L.FullProb.func.gii \
    -right-metric $tmpoutdir/R.FullProb.func.gii \
    -name-file $indir/ROI_names.txt



### Max prob maps
echo -e "\nMaxprobability maps..."

# Get list of all surface ROIs (excluding hemi) by globbing files
ROIs=()
for infile in $(find $indir/ -maxdepth 1 -type f -name "Left*.nii.gz" | sort); do
    ROI=$(echo $(basename $infile .nii.gz) | cut -d "_" -f 2-)

    isOkay=1
    for non_surf_ROI in ${non_surf_ROIs[@]}; do
        if [[ $ROI == *"$non_surf_ROI"* ]]; then
            isOkay=0
        fi
    done

    if [[ $isOkay -eq 1 ]]; then
        ROIs+=($ROI)
    fi
done


## Transfrom vol ROIs to surface GIFTIs
echo -en "\tTransforming to surface... "

# Loop ROIs * hemis
for ROI in ${ROIs[@]}; do
    for FSL_hemi in Left Right; do
        echo -n "${FSL_hemi}_${ROI} "

        # Set some details
        if [[ $FSL_hemi == "Left" ]]; then
            HCP_hemi=L
        elif [[ $FSL_hemi == "Right" ]]; then
            HCP_hemi=R
        fi

        infile=$indir/${FSL_hemi}_${ROI}.nii.gz
        HCP_mid_surf=$HCP_anatdir/S1200.${HCP_hemi}.midthickness_MSMAll.32k_fs_LR.surf.gii
        tmpout_base=$tmpoutdir/${HCP_hemi}.${ROI}

        # Resample to HCP MNI volume
        # (wb_command -volume-resample <infile> <ref_vol> <method> <outfile>
        wb_command -volume-resample $infile $HCP_vol ENCLOSING_VOXEL ${tmpout_base}.nii.gz

        # Transform vol -> surf GIFTI
        # (wb_command -volume-to-surface-mapping <infile> <surface> <outfile> [method])
        wb_command -volume-to-surface-mapping \
            ${tmpout_base}.nii.gz $HCP_mid_surf ${tmpout_base}.shape.gii -enclosing
    done
done

echo ""


## Concatenate GIFTIs over hemis and ROIs into single CIFTI dlabel
echo -en "\n\tMerging surface ROIs to CIFTI... "

# Concat GIFTIs over hemis for each ROI and convert to temporary dscalars,
# weighted by ROI number
for ((i=0; i < ${#ROIs[@]}; i++)); do
    ROI=${ROIs[$i]}
    echo -n "$ROI "

    outfile=$tmpoutdir/${ROI}.dscalar.nii

    # (wb_command -cifti-create-dense-scalar <outfile> \
    #  -left-metric <left-input> -right-metric <right-input>)
    wb_command -cifti-create-dense-scalar $outfile \
        -left-metric $tmpoutdir/L.${ROI}.shape.gii \
        -right-metric $tmpoutdir/R.${ROI}.shape.gii

    # (wb_command -cifti-math <expr> <outfile> -var <varname> <infile>)
    wb_command -cifti-math "x * (1 + $i)" $outfile -var x $outfile &> /dev/null
done

echo -e "\n\n\tCreating final label file..."

# Concat ROIs along "time" dim
# (wb_command -cifti-merge <outfile> -cifti <infile1> -cifti <infile2> ...)
mergestr=$(printf -- "-cifti $tmpoutdir/%s.dscalar.nii " ${ROIs[@]})
wb_command -cifti-merge $tmpoutdir/all_ROIs.dscalar.nii $mergestr

# Reduce to 3D by taking max along "time" dim - this properly handles any
# overlap between ROIs introduced during interpolation (should be minor)
# (wb_command -cifti-reduce <infile> <operation> <outfile>
wb_command -cifti-reduce $tmpoutdir/all_ROIs.dscalar.nii MAX \
    $tmpoutdir/all_ROIs.dscalar.nii

# Finally, convert to label and save to final output. Trick for auto-generating
# colours: create label with default label names and colours, then export
# table and edit label names, then recreate label with correct names
# (wb_command -cifti-label-import <infile> <optional:lookup_file> <outfile>)
# (wb_command -cifti-label-export-table <infile> <map_idx> <outfile>)
# (wb_command -set-map-names <infile> -map <map_idx> <newname>)
wb_command -cifti-label-import $tmpoutdir/all_ROIs.dscalar.nii "" \
    $tmpoutdir/all_ROIs.dlabel.nii

wb_command -cifti-label-export-table $tmpoutdir/all_ROIs.dlabel.nii 1 \
    $tmpoutdir/lookup.txt

for ((i=0; i < ${#ROIs[@]}; i++)); do
    labelN=$((i+1))
    sed -i "s/^LABEL_${labelN}$/${ROIs[$i]}/g" $tmpoutdir/lookup.txt
done

wb_command -cifti-label-import $tmpoutdir/all_ROIs.dscalar.nii \
    $tmpoutdir/lookup.txt $outdir/JuBrain_ROIs.dlabel.nii
wb_command -set-map-names $outdir/JuBrain_ROIs.dlabel.nii -map 1 JuBrain_ROIs



### Finish up
# Remove temp directory
rm -r $tmpoutdir

# Done
echo -e "\nDone\n"

