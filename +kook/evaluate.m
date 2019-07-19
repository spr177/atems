
% EVALUATE  Original Kook function, modified only to be incorporated into a function.
% Automatic primary particle finder v1.2 (works on Matlab 2012a or higher + 
% Image Processing Toolbox)
% The code implements pre-processing (Median Filter and unsharp masking), 
% Canny edge detection, and  Circular Hough Transform.
%
% Original code written by Qing Nian Chan on 18 Sep 2014
% Modified by Sanghoon Kook for diesel soot applications on 27 Sep 2014
% Last update by original authors on 19 Dec 2014 by Sanghoon Kook
% 
% Modifications by UBC: 
% 1. TEMscale -> pixsize (using tools. getfooterscale)
% 2. Included references to img
% 3. Updates to commenting
% 4. Update to output (dpdist is original output)
% 5. Added option as to whether of not to generate plots
%=========================================================================%

function [dp,dpdist] = evaluate(imgs,bool_plot)
%-------------------------------------------------------------------------%
% Inputs:
%   img_ref Image struct to be analyzed
%   dpdist  Primary particle size disitrbution of aggregate
%-------------------------------------------------------------------------%


%-- Parse inputs and load image ------------------------------------------%
if ~exist('bool_plot','var'); bool_plot = []; end
if isempty(bool_plot); bool_plot = 0; end


pixsize = imgs(1).pixsize;

II1 = imgs(1).Cropped;


%-- Set relevant parameter values ----------------------------------------%
maxImgCount = 255; % Maximum image count for 8-bit image
SelfSubt = 0.8; % Self-subtraction level
mf = 1; % Median filter [x x] if needed
alpha = 0.1; % Shape of the negative Laplacian �unsharp� filter 0?1
rmax = 30; % Maximum radius in pixel
rmin = 4; % Minimun radius in pixel
sens_val = 0.75; % the sensitivity (0->1) for the circular Hough transform

OriginalImg = II1;



%== Pre-processing =======================================================% 
%-- Step 1: Invert image greyscale ---------------------------------------%
if size(OriginalImg,1) > 900
	II1(950:size(II1,1), 1:250) = 0;% ignore scale bar in the TEM image x 1-250 pixel and y 950-max pixel
end

II1_bg=SelfSubt*II1; % Self-subtration from the original image
II1=maxImgCount-II1;
II1=II1-II1_bg;
II1(II1<0)=0;
if bool_plot; figure();imshow(II1, []);title('Step 1: Inversion and self-subtraction'); end

%-- Step 2: median filter to remove noise --------------------------------%
II1_mf=medfilt2(II1, [mf mf]);
if bool_plot; figure();imshow(II1_mf, []);title('Step 2: Median filter'); end

%-- Step 3: Unsharp filter------------------------------------------------%
f = fspecial('unsharp', alpha);
II1_lt = imfilter(II1_mf, f);
if bool_plot; figure();imshow(II1_lt, []);title('Step 3: Unsharp filter'); end

%-- Step 4: Canny edge detection -----------------------------------------%
BWCED = edge(II1_lt,'canny'); % perfrom Canny edge detection
if bool_plot; figure();imshow(BWCED);title('Step 4: Canny edge detection'); end



%== Main processing steps ================================================%
%-- Find circles within soot aggregates ----------------------------------%
[centers, radii] = imfindcircles(BWCED,[rmin rmax],...
    'objectpolarity', 'bright', 'sensitivity', sens_val, 'method', 'TwoStage');
% - draw circles
if bool_plot
    figure();imshow(OriginalImg,[]);hold;
    h = viscircles(centers, radii, 'EdgeColor','r');
    title('Step 5: Parimary particles overlaid on the original TEM image');
end


%-- Check the circle finder ----------------------------------------------%
%-- Overlaying the CHT boundaries on the original image. 
if bool_plot
    R = imfuse(BWCED, OriginalImg,'blend');
    figure();imshow(R,[],'InitialMagnification',500);hold;h = viscircles(centers, radii, 'EdgeColor','r');
    title('Step 6: Primary particles overlaid on the Canny edges and the original TEM image');
end


%== Generate outputs =====================================================%
dp.method = 'kook';
dp.centers = centers; % output in px
dp.radii = radii; % output in px
dp.diameters = radii*pixsize*2; % output in nm

dpdist = radii*pixsize*2;


end
