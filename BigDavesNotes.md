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
   
NOTE: These will be in MNI 1mm space, and actually don't quite seem to be
masks (values are floats that are close to, but not exactly, 1). Bit more
processing needed to properly binarise them and convert them to 2 mm space
