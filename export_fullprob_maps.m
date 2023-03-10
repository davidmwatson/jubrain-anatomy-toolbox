%% Export full probability maps from atlas

clearvars;

%% Key vars
infile = './JuBrain_Data_v30.mat';
template_nii = './JuBrain_Map_v30.nii';
outdir = './JuBrain_ROIs/SPM_1mm';

%% Begin

% Make outdir?
if ~isfolder(outdir), mkdir(outdir); end

% Load mat
fprintf(1, 'Loading...\n');
load(infile, 'JuBrain');

% Create brain mask from index
nMaps = size(JuBrain.PMap, 1);
mask = repmat(JuBrain.Index > 0, [1 1 1 nMaps]);

% Pre-allocate volume
fpl_maps = zeros(size(mask), 'single');

% Allocate maps (need to convert PMap sparse -> dense for indexing to work)
% Convert proportion -> percentage while we're on with it
fpl_maps(mask) = 100 * full(JuBrain.PMap)';

% Load metadata from template and update for output
metadata = niftiinfo(template_nii);
metadata.ImageSize = size(fpl_maps);
metadata.PixelDimensions = ones(1, ndims(fpl_maps));
metadata.Datatype = 'single';
metadata.BitsPerPixel = 32;
metadata.MultiplicativeScaling = 1;
metadata.raw.dim(2:5) = size(fpl_maps);
metadata.raw.pixdim(2:5) = ones(1, ndims(fpl_maps));
metadata.raw.scl_slope = 1;
metadata.raw.cal_min = 0;
metadata.raw.cal_max = 100;

% Write to compressed NIFTI
fprintf(1, 'Saving...\n');
niftiwrite(fpl_maps, fullfile(outdir, 'FullProb'), metadata, 'compressed', true);

% Export ROI names as text
writecell(JuBrain.Namen, fullfile(outdir, 'ROI_names.txt'));

% Finish
fprintf(1, '\nDone\n');

