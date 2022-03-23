function obj = slover_wrap(img_files, varargin)
% Wrapper function for slover routine with flexible input arguments
%__________________________________________________________________________

idefs.display.structural.name = {'structural', 'st', 'str', 's'};
idefs.display.structural.type = 'truecolour';
idefs.display.structural.cmap = gray;
idefs.display.truecolour.name = {'truecolour', 'tc'};
idefs.display.truecolour.type = 'truecolour';
idefs.display.truecolour.cmap = 'flow.lut';
idefs.display.blobs.name = {'blobs', 'bl', 'b'};
idefs.display.blobs.type = 'split';
idefs.display.blobs.cmap = 'hot';
idefs.display.blobs.prop = 1;
idefs.display.negative_blobs.name = {'negative_blobs', 'nbl', 'nb'};
idefs.display.negative_blobs.type = 'split';
idefs.display.negative_blobs.cmap = 'winter';
idefs.display.negative_blobs.prop = 1;
idefs.display.mask.name = {'mask', 'm'};
idefs.display.mask.type = 'split';
idefs.display.mask.cmap = [255 0 0];
idefs.display.mask.prop = 1;
idefs.display.contour.name = {'contour', 'c'};
idefs.display.contour.type = 'split';
idefs.display.contour.cmap = 'white';
idefs.display.contour.prop = 1;
idefs.display.other.name = {'other', 'o'};
idefs.display.other.type = 'split';
idefs.display.other.cmap = 'hot';
idefs.display.other.prop = 1;
idefs.planes.axial = -72:2:90; %-72:1:108
idefs.planes.coronal = -120:3:85; %-126:1:90
idefs.planes.sagittal = -75:2:75; %-90:1:90
idefs.cbar = 'off';
idefs.plane = 'axial';
idefs.def_display = 'blobs';
idefs.cmap = 'hot';

%% Parse input arguments
% =====================================================
% Note: a lot of input argument checking code below the inputParser is not
% strictly necessary as the inputParser already deals with it. The code
% however is kept in case the inputParser is not being used and is used as
% an exercise for efficient programming.

% Pre-parsing settings
planes_mapping = { {'axial',    {'axial', 'ax', 'transversal', 'tra'}}, ...
    {'sagittal', {'sagittal', 'sag'}}, ...
    {'coronal',  {'coronal', 'cor'}} ...
    };

valid_planes = cellfun(@(x) x{2}, planes_mapping, 'UniformOutput', false);
valid_planes = horzcat(valid_planes{:});


% all slover object fields without img
valid_slover_fields = fieldnames(slover)';
valid_slover_fields(ismember(valid_slover_fields, 'img')) = [];

% valid fields for img struct of slover object, see slover.m
valid_img_fields = {'type','vol','cmap','nancol','prop','func','range','outofrange','hold','background','linespec','contours','linewidth'};


% Parser setup
p = inputParser;
addRequired(p, 'img_files', @(x)validateattributes(x,{'cell','char'},{}));
addParameter(p, 'plane', {}, @(x) ischar(validatestring(x, valid_planes)));
addParameter(p, 'display', {}, @(x)validateattributes(x,{'cell','char'},{}));
addParameter(p, 'ov', struct, @(x)validateattributes(x,{'struct'},{}));
addParameter(p, 'defs', struct, @(x)validateattributes(x,{'struct'},{}));
addParameter(p, 'title', '', @(x)validateattributes(x,{'char'},{}));
addParameter(p, 'cbar', '', @(x) any(validatestring(x,{'on', 'off'})));
addParameter(p, 'slover', struct, @(x)validateattributes(x,{'struct'},{}));
parse(p, img_files, varargin{:});

% First update the internal defaults structure with input argument
% use provided update_struct or mars_struct from slover
idefs = update_struct(idefs, p.Results.defs, 0, 1);

% Post-parsing settings

% Extract valid displays = values of idefs.display.(type).name, fieldname if missing
% Skip invalid inputs
display_fields = fieldnames(idefs.display);
displays_mapping = {};
for i = 1:numel(display_fields)
    if isfield(idefs.display.(display_fields{i}), 'name')
        names = cellify(idefs.display.(display_fields{i}).name);
        valid_names = cellfun(@(x) ischar(x), names);
        names = names(valid_names);
    else
        names = display_fields{i};
    end
    displays_mapping = horzcat(displays_mapping, {{display_fields{i}, names}});
end
valid_displays = cellfun(@(x) x{2}, displays_mapping, 'UniformOutput', false);
valid_displays = horzcat(valid_displays{:});

%% Check img_files
% =====================================================
img_files = cellify(img_files);
validationFunc = @(x) validateattributes( x, { 'char' }, { }, mfilename, 'input images');
cellfun( validationFunc, img_files);
if isempty(img_files)
    obj = [];
    return
end

%% Check plane
% =====================================================
% At least the default value must be OK, bail out if wrong
if ~ismember(idefs.plane, valid_planes)
    error('Default plane value is invalid, bailing out!');
end

if ~isempty(p.Results.plane)
    plane = p.Results.plane;
else
    plane = idefs.plane;
end

plane = inverse_map({idefs.plane, plane}, planes_mapping);
plane=plane(~cellfun('isempty',plane));
plane=plane{end};

%% Check colour bar display
% =====================================================
% At least the default value must be OK, bail out if wrong
cbar_check = strcmp({'on', 'off'}, idefs.cbar);

if ~any(cbar_check)
    error('Default colour bar value is invalid, bailing out!');
end
cbar = [];
%cbar = cbar_check(1);

if ~isempty(p.Results.cbar)
    cbar_check = strcmp({'on', 'off'}, p.Results.cbar);
    if ~any(cbar_check)
        warning('SLOVER_BATCH: Plane input is invalid, setting default value %s', idefs.cbar);
    else
        cbar = cbar_check(1);
    end
end

%% Check displays
% =====================================================
% if display is missing: first image is always structural
% if #displays < #images: use idefs.type for missing display

% At least the default value must be OK, bail out if wrong
if ~ismember(idefs.def_display, valid_displays)
    error('Default display value is invalid, bailing out!');
end

% Check validity of provided displays
idisplay = {};
if ~isempty(p.Results.display)
    idisplay = cellify(p.Results.display);
    res = cellfun(@(x) ismember(x, valid_displays), idisplay) ;
    if ~all(res)
        error('One or more of the provided displays is invalid, bailing out!');
    end
end

% Handle missing or absent displays
% if empty, the first one is always the structural
if isempty(idisplay)
    idisplay{1} = 'structural';
end

% Fill missing displays with default display
nr_missing = numel(img_files) - numel(idisplay);
if nr_missing > 0
    idisplay = horzcat(idisplay, repmat({idefs.def_display}, 1, nr_missing));
end

% Convert to fieldname
idisplay = inverse_map(idisplay, displays_mapping);

%% Check overrides
% =====================================================
override = struct;
override = p.Results.ov;
validateattributes( override, { 'struct' }, { }, mfilename, 'override values');

%% Preparations to data processing
% =====================================================
% Initialize slover object
obj = slover;

% Override slover object attributes with provided ones
slover_ov = p.Results.slover;
if ~isempty(slover_ov)
    obj_struct = mars_struct('split', slover_ov, valid_slover_fields);
    
    if ~isempty(obj_struct)
        % Copy slover object fields if provided
        fnames = fieldnames(obj_struct);
        for j=1:numel(fnames)
            fname = fnames{j};
            obj.(fname) = obj_struct.(fname);
        end
    end
end

cbar_list = [];

% Set some basic variables
cscale = [];
drange = [];

%% Loop over images
% =====================================================
for i = 1:numel(img_files)
    
    % Read image
    img_file = img_files{i};
    vol = spm_vol(img_file);
    
    % Calculate range
    [mx,mn] = slover('volmaxmin', vol);
    
    % Process display type
    display_type = idisplay{i};
    switch display_type
        case 'structural'
            drange = [mn mx];
            cscale = [cscale i];
            
        case 'truecolour'
            drange = [mn mx];
            cscale = [cscale i];
            cbar_list = [cbar_list i];
            
        case 'blobs'
            drange = [eps mx];
            cbar_list = [cbar_list i];
            
        case 'negative_blobs'
            drange = [-eps mn];
            cbar_list = [cbar_list i];
            
        case 'mask'
            drange = [mx-eps mx];
            cbar_list = [cbar_list i];
            
        case 'contour'
            drange = [mx-eps mx];
            
        otherwise
            drange = [mn mx];
    end
 
    % Filter on fields being used in slover img struct
    img_struct = mars_struct('split', idefs.display.(display_type), valid_img_fields);
    img_struct.vol = vol;
    if isfield(idefs.display.(display_type), 'range')
        img_struct.range = idefs.display.(display_type).range;
    else
        img_struct.range = drange;
    end
    
    % Handle overrides, only when one is available
    if ~isempty(override) && i <= numel(override)
        % Get only fields being used in slover
        or = mars_struct('split', override(i), valid_img_fields);
        % Merge structs and overwrite where applicable
        img_struct = mars_struct('ffillmerge', img_struct, or);
    end
    
    % Copy image struct to slover object (assign does not work as the
    % slover object is not yet complete
    fnames = fieldnames(img_struct);
    for j=1:numel(fnames)
        fname = fnames{j};
        obj.img(i).(fname) = img_struct.(fname);
    end
    
    % Read colormap
    if ischar(obj.img(i).cmap)
        obj.img(i).cmap = slover('getcmap', obj.img(i).cmap);
    end
end

%% Final preparation for display
% Process proportion (overrides previous matlainputs)
ncmaps=length(cscale);
if ncmaps == 1
    obj.img(cscale).prop = 1;
else
    remcol=1;
    for i = 1:ncmaps
        ino = cscale(i);
        obj.img(ino).prop = remcol/(ncmaps-i+1);
        remcol = remcol - obj.img(ino).prop;
    end
end

% Colorbar display
if ~isempty(cbar) && cbar
    obj.cbar = cbar_list;
else
    if ~isempty(slover_ov) && isfield(slover_ov, 'cbar') && ~isempty(slover_ov.cbar)
        obj.cbar = slover_ov.cbar(slover_ov.cbar <= numel(img_files));
    end
end

% Plane and slices to display
obj.transform = plane;
obj.slices = idefs.planes.(plane);

% Use SPM figure window
obj.figure = spm_figure('GetWin', 'Graphics');

% Fill missing values
obj = fill_defaults(obj);

% Paint everything
obj = paint(obj);
end



