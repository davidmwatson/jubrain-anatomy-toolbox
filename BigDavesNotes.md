To extract ROIs:

1) I couldn't work out how to get this to work with YNiC's install of SPM, so I
   ended up downloading SPM12 myself. Add this to the matlab path.

2) Extract the `JuBrain_Data_v30.mat` file from the zip directory

3) Copy this repository into the spm12/toolbox/ directory and rename it as
   `Anatomy`

4) Launch SPM, select `fMRI`, then select `Anatomy` from the dropdown toolbox
   menu.

5) Click `ROI Tool` and select the `JuBrain_Data_v30.mat` file

6) Click `Select all` then click `Create individual ROIs`. This will unpack
   every ROI as a separate mask image into a directory named `JuBrain_ROIs`
   within the current directory.
   
> NOTE 1: These will be in SPM's MNI 1mm space, which is a little bit different
> to FSL's MNI 1mm space. Further processing is needed to convert to FSL space
> and to resample to 2mm MNI space (see `xfm_ROIs2FSL.sh` script).

> NOTE 2: PGp region used as ROI for caudal inferior parietal lobule (cIPL),
> e.g. Baldassano et al. (2013), Neuroimage.
