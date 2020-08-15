
% GET_IMGS  Loads nth image specified in the image reference structure (img_ref)
% Author:   Timothy Sipkens, 2019-07-04
%=========================================================================%

function [Imgs,img_raw] = get_imgs(Imgs, n)

%-- Parse inputs ---------------------------------------------------------%
if ~exist('Imgs','var'); Imgs = tools.get_imgs_ref; end

if ~exist('n','var'); n = []; end
if isempty(n); n = 1:length(Imgs); end
    % if image number not specified, use the first one

%-- Read in image --------------------------------------------------------%
for ii=length(n):-1:1
    Imgs(ii).raw = imread([Imgs(ii).dir,Imgs(ii).fname]);
end

img_raw = Imgs(1).raw;

end

