% Motion_artifact_Demons.m

% This script is used to correct the artifacts caused by respiratory
% motion in the intravital movies acquired with 2-photon microscopy. 
% Here the non-rigid registration is done using Demons algorithm. 
% 
% This script depends on the bfmatlab tool box from OME:
% https://www.openmicroscopy.org/bio-formats/
% as well as the menuN function by Johan Winges:
% https://github.com/johwing/matlab_menu_gui
%
% Input format: This script will read the .czi file (ZEISS) directly. 
%               Ideally the image should be 16bit grayscale.
% Output format: The registered movies will be saved as multi-layer tiff.


% Jessica IH Wang, Jan. 2017, Uni. Tokyo, Japan.

%% User input 
% load bfmatlab
addpath([cd,'\bfmatlab\']);

% Select movie to process 
[FilePath,Folder] = uigetfile({'*.*'},'Select the movie to register',...
    'MultiSelect','off');
% Where the corrected movies should be saved
SaveFolder = uigetdir('','Select the folder to save outputs');

% Load .czi file
data = bfopen([Folder,FilePath]);
% Retrieve required metadata
Metadata = data{1, 4};
Ch = Metadata.getChannelCount(0);
T = Metadata.getPixelsSizeT(0).getValue();
PixX = Metadata.getPixelsSizeX(0).getValue();
PixY = Metadata.getPixelsSizeY(0).getValue();
bit = Metadata.getPixelsSignificantBits(0).getValue();

% Chose the Channel for refernece and to correct
for iCh = 1:Ch
    ChName{iCh} = char(Metadata.getChannelName(0,iCh-1));
end
mtitle = {'Channel selection',...
    'Chose the reference channel.'};
options = 'x';
for iCh = 1:Ch
    options = ...
        [options,'|',ChName{iCh}];
end
ref_select = menuN(mtitle, options);

ntitle = {'Channel selection',...
    'Chose the channel(s) to register.'};
reg_select = menuN(ntitle, options);

% Make subfolders for saving registered tiff images
for iCh = 1:size(reg_select,1)
    mkdir([SaveFolder,'\',ChName{reg_select(iCh)},'\']);
end

%% Extract images from .czi
Stk_struct = {};
for iChs = 1:Ch
    Stk = zeros(PixX,PixY,T);
    if bit == 16
        Stk = uint16(Stk);
    elseif bit == 8
        Stk = uint8(Stk);
    end
    for iT = 1:T
        Stk(:,:,iT) = data{1,1}{iChs+(iT-1)*Ch};
    end
    Stk_struct{iChs} = Stk;
    clear Stk
end

%% Start the processing
% Save the first frames into the save folder
for iCh = 1:size(reg_select,1)
    imwrite(Stk_struct{reg_select(iCh)}(:,:,1),...
        [SaveFolder,'\',ChName{reg_select(iCh)},'\t00.tif'],'tif'); 
end

%Scale the reference channel
ref_Stk = zeros(PixX,PixY,T);
if bit == 16
    ref_Stk = uint16(ref_Stk);
elseif bit == 8
    ref_Stk = uint8(ref_Stk);
end
imshow(Stk_struct{ref_select}(:,:,1))
hfig = imcontrast(gcf);
set(hfig,'CloseRequestFcn', @(s,e)getValues(s))
uiwait(hfig)
for iT = 1:T
    ref_Stk(:,:,iT) = imadjust(Stk_struct{ref_select}(:,:,iT),...
        [ref_min/65535;ref_max/65535],[0;1]);
end

% Start the waitbar
Count = 0;
screenSize = get(0, 'ScreenSize');
h = [screenSize(3)/3-275/3 screenSize(4)/2 275 60];
WaitBar = waitbar(0, 'Initializing waitbar...', 'Position', h);
tic;

% Loop through each frame in the reference channel to do the
% registration, and apply the deformation to other channels.
for iImg = 2:T
    % Registration
    D = imregdemons(ref_Stk(:,:,iImg), ref_Stk(:,:,1), [60 50 40]);
    % Apply deformation to selected channels
    for iCh = 1:size(reg_select,1)
%         Img = imhistmatch(Stk_struct{reg_select(iCh)}(:,:,iImg),...
%             Stk_struct{reg_select(iCh)}(:,:,4));
        Img = Stk_struct{reg_select(iCh)}(:,:,iImg);
        ImgReg = imwarp(Img, D);
        imwrite(ImgReg,[SaveFolder,'\',ChName{reg_select(iCh)},'\t',...
            sprintf('%02d',iImg-1),'.tif'],'tif');
    end
    
    %Here's the code for progress bar
    t = toc;
    Count = Count+1;
    Perc = Count/T;
    Trem = t/Perc-t; %Calculate the time remaining
    Hrs = floor(Trem/3600); Min=floor((Trem-Hrs*3600)/60);
    waitbar(Perc,WaitBar,['Frame ',num2str(iImg),'/',...
        num2str(T),' done, ' sprintf('%02.0f ',Min) ':'...
        sprintf('%02.0f',rem(Trem,60)) ' remaining']);
end
delete(WaitBar)

clear all
clc
display('   ')
display('Registration is done!')

%%%%%%% FUnctions %%%%%%%
% function for scaling
function getValues(hfig)
    window_min = str2double(get(findobj(hfig, 'tag', 'window min edit'), 'String'));
    window_max = str2double(get(findobj(hfig, 'tag', 'window max edit'), 'String'));
    assignin('base', 'ref_min', window_min);
    assignin('base', 'ref_max', window_max);
end


