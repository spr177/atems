
# ATEMS

**(*A*nalysis tools for *TEM* images of *S*oot)**

[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://lbesson.mit-license.org/)
[![Version](https://img.shields.io/badge/Version-0.4+-blue.svg)]()

This codebase contains Matlab code for several methods of characterizing soot aggregates in TEM images. This includes methods for evaluating the aggregate projected area, perimeter, and primary particle diameter. Methods include Otsu thresholding, the pair correlation method (PCM), Hough circle transform (following [Kook](kook)), and tools to aid in manual analysis. The program is primarily composed of two analysis packages, which will be discussed later in the README: 

1. **+agg** - which performs aggregate-level segmentation to output a binary image, and 
2. **+pp** - which determines the primarily particle, often from the binary image generated by the methods in the `agg` package noted above. 

Functions in these packages are called by prefacing the function name with the package name, e.g. PCM can be called used `pp.pcm`. 

### Getting started

#### Load images

The first step in the image analysis process is to import images. Images can be handled in one of two ways. The first is as a Matlab structure, with one entry in the structure for each image loaded. To generate this structure by loading the sample images provided with the program, one can run:

```Matlab
Imgs = tools.load_imgs('images'); % load the images
```

The output structure contains the image file name and directory; the image itself, with the footer cropped; and the pixel size, read from the image footer. The latter two operations make use of the get_footer_scale function, which requires a certain style footer that is consistent with TEM images taken at the University of British Columbia and applies optical character recognition to determine the pixel size (stored in the `pixsize` field). One can also generate by selecting files in a file explorer by omitting the string input: 

```Matlab
Imgs = tools.load_imgs; % load the images
```

The second way images can be handled is using a cell array of cropped images and pixel sizes. These are secondary outputs to the load_imgs function: 

```Matlab
[Imgs, imgs, pixsizes] = tools.load_imgs; % load the images
```

The images and pixel sizes can also be extracted from the `Imgs` structure using:

```Matlab
imgs = {Imgs.cropped}; % copy variables locally
pixsize = [Imgs.pixsize]; % pixel size for each image
fname = {Imgs.fname};
```

#### Aggregate-level segmentation

The next step is to evaluate binaries that separate parts of the image that are part of the background and parts that are aggregate. This is done using the functions in the agg package. For example, *k*-means segmentation can be performed using:

```Matlab
imgs_binary = agg.seg_kmeans6(imgs, pixsize, opts);
    % segment aggregates
```

The result, `imgs_binary`, is either a single binary image (if one image is given as an input) or a cellular array of image binaries (if multiple images are given as an input), with `1` if a pixel is considered part of the aggregate and `0` if it is not. Other approaches are also available and are discussed in Section 1 below. 

Having segmented the image, aggregate characteristics can be determined by passing this binary image to an analysis function:

```Matlab
Aggs = agg.analyze_binary(...
    imgs_binary,imgs,pixsize,fname);
        % determine aggregate properties
```

The output data itself, `Aggs`, is a MATLAB structured array with one entry per aggregate, containing properties like the location of the aggregate, perimeter, and projected-area. This data can then be exported to a JSON file using :

```Matlab
tools.write_json(Aggs, fname);
```

or an Excel spreadsheet using: 

```Matlab
tools.write_excel(Aggs, fname);
```

to be analyzed in other software and languages, where `fname` is the filename of the file to write to. The `Aggs` structure can also be visualized as an overlay on top of the TEM image using

```Matlab
figure(1);
tools.imshow_agg(Aggs);
```

The resultant image highlights pixels that are part of the aggregate, and plots a circle that corresponds to the radius of gyration. This output is similar to that shown in images above for the *k*-means and the manual slider methods above. 

#### Determining the primary particle size

Primary particle size information can finally be determined using functions in the `pp` package. The original pair correlation method (PCM), for example, can be applied by using the `Aggs` output from the `agg.analyze_binary` function as

```Matlab
Aggs_pcm = pp.pcm(Aggs); % apply PCM
```

The output is an updated `Aggs` structure that also contains an estimate of the primary particle size for each aggregate. Having done this, the primary particle size can be visualized along with the radius of gyration noted above by passing the updates `Aggs` structure to the `tools.plot_aggregates` function:

```Matlab
figure(1);
tools.imshow_agg(Aggs_pcm);
```

The inner circle now indicates the primary particle size from PCM, and the number indicating the index used by the program to identify each aggregate. 

## 1. Aggregate segmentation package (+agg)

This package contains an expanding library of functions aimed at performing semantic segmentation of the TEM images into aggregate and background areas. 

### 1.1 agg.seg* functions

Functions implementing different methods of aggregate-level semantic segmentation have filenames starting with `agg.seg*`. In each case, the output primarily consists of binary images of the same size as the original image but where pixels taken on logical values: `1` for pixels identified as part of the aggregate `0` for pixels identified as part of the background. The functions take `imgs` as a common input, which is either a single image or cellular array of images of the aggregates (after any footer or additional information have been removed). Several methods also take `pixsize`, which denotes the size of each pixel in the image. Other arguments depend on the function and are available in the header information. 

The available methods are summarized below. Multiple of these methods make use of the *rolling ball transformation*, applied using the `agg.rolling_ball` function included with this package. This transform fills in gaps inside aggregates, acting as a kind of noise filter. This is accomplished by way iterative morphological opening and closing. 

#### seg

This is a general, multipurpose wrapper function that tries several of the other methods listed here in sequence, prompting the user after each attempt. This allow for refinement of the output from the *k*-means and Otsu-based methods discussed below.

#### seg_kmeans6

This function applies a *k*-means segmentation approach using three feature layers, which include (*i*) a denoised version of the image, (*ii*) a measure of texture in the image, and (*iii*) an Otsu-like threshold, adjusted upwards. Compiling these different feature layers results in segmentation that effectively consider colour images, if each of the layers are assigned a colour. For example, compilation of these feature layers could be visualized as: 

![fcolour](docs/fcolour.png)

Applying Matlab's `imsegkmeans` function will then result in segmentations as follows: 

![kmeans](docs/kmeans.png)

While this may be adequate for many users, this technique occasionally fails, particularly if the function does not adequately remove the background. 

#### seg_otsu_rb*

This method applies Otsu thresholding followed by a rolling ball transformation. Two versions of this function are included: 

1. **seg_otsu_rb_orig** - Remains more true to the original code of [Dastanpour et al. (2016)][dastanpour2016]. 
2. **seg_otsu_rb** - Updates the above implementation by (*i*) not immediately removing boundary aggregates, (*ii*) adding a background subtraction step using the `agg.bg_subtract` function, and (*iii*) adding a denoising step. 

The latter function generally performs better. 

#### seg_slider

This is a GUI-based method with a slider for adaptive, manual thresholding of the image (*adaptive* in that small sections of the image can be cropped and with an independently-selected threshold). Gaussian denoising is first performed on the image to reduce the noise in the output binary image. Then, a slider is used to manually adjust the level of the threshold in the cropped region of the image. This can result in segmentations like:

![kmeans](docs/manual.png)

It is worth noting that the manual nature of this approach will resulting in variability and subjectiveness between users. However, the human input often greatly improves the quality of the segmentations and, while more time-intensive, can act as a reference in considering the appropriateness of the other segmentation methods. 

Several sub-functions are included within the main file. This is a variant of the method included with the distribution of the PCM code by [Dastanpour et al. (2016)][dastanpour2016]. 

> We note that this code saw important bug updates since the original code by [Dastanpour et al. (2016)][dastanpour2016]. This includes fixing how the original code would repeatedly apply a Gaussian filter every time the user interacted with the slider in the GUI (which may cause some backward compatibility issues), a reduction in the use of global variables, memory savings, and other performance improvements. 

### 1.2 analyze_binary

This function analyzes the binary image output from any of the `agg.seg_*` functions. The output is a MATLAB structured array
containing information about the aggregate, such as area in pixels, radius of gyration, area-equivalent diameter, aspect ratio
etc., in an `Aggs` structured array. The array has one entry for each aggregate found in the image, defined as independent groupings of pixels. The function itself takes a binary image, the original image, and the pixel size as inputs, generating an `Aggs` structure by

```Matlab
Aggs = agg.analyze_binary(imgs_binary,imgs,pixsize,fname);
```

The `fname` argument is optional and adds this tag to the information in the output `Aggs` structure. 


## 2. Primary particle analysis package (+pp)

The +pp package contains multiple methods for determining the primary particle size of the aggregates of interest. Often this requires a binary mask of the image that can be generated using the +agg package methods.

#### pcm

The University of British Columbia's pair correlation method (PCM) MATLAB code for processing TEM images of soot to determine morphological properties. This package contains a significant update to the previous code provided with [Dastanpour et al. (2016)][dastanpour2016].

#### kook

This method contains a copy of the code provided by [Kook et al. (2015)][kook], with minor modifications to match in the input/output of some of the other packages. The method is based on using the Hough transform on a pre-processed image.

#### kook_yl

This method contains a University of British Columbia-modified version of the method proposed by [Kook et al. (2015)][kook].

#### manual

Code to be used in the manual sizing of soot primary particles developed at the University of British Columbia. The current method uses crosshairs to select the length and width of the particle. This is converted to various quantities, such as the mean primary particle diameter. The manual code is a heavily modified version of the code associated with [Dastanpour and Rogak (2014)][dastanpour2014].


## 3. Additional tools package (+tools)

This package contains a series of functions that help in visualizing or analyzing the aggregates.

### 3.1 Functions to show images (tools.imshow*)

These functions aid in visualizing the results. For example, 

```Matlab
tools.imshow_binary(img, img_binary)
```

will plot the image, given in `img`, and overlay labels for the aggregates in a corresponding binary image, given in `img_binary`.  Appending an `opts` structure to the function allows for the control of the appearance of the overlay, including the label alpha and colour. For example, 

```Matlab
opts.cmap = [0.92,0.16,0.49];
tools.imshow_binary(img, img_binary, opts);
```

will plot the overlays in a red, while 

```Matlab
opts.cmap = [0.99,0.86,0.37];
tools.imshow_binary(img, img_binary, opts);
```

will plot the overlays in a yellow.

--------------------------------------------------------------------------

#### License

This software is licensed under an MIT license (see the corresponding file for details).


#### Contributors and acknowledgements

This code was primarily compiled by Timothy A. Sipkens while at the University of British Columbia (UBC), who can be contacted at [tsipkens@mail.ubc.ca](mailto:tsipkens@mail.ubc.ca). Pieces of this code were adapted from various sources and features snippets written by several individuals at UBC, including Ramin Dastanpour, [Una Trivanovic](https://github.com/unatriva), Yiling Kang, Yeshun (Samuel) Ma, and Steven Rogak, among others.

This program contains very significantly modified versions of the code distributed with [Dastanpour et al. (2016)][dastanpour2016]. The most recent version of the Dastanpour et al. code prior to this overhaul is available at https://github.com/unatriva/UBC-PCM (which itself presents a minor update from the original). That code forms the basis for some of the methods underlying the manual processing and the PCM method used in this code, as noted in the README above. However, significant optimizations have improved code legibility, performance, and maintainability (e.g., the code no longer uses global variables). 

Also included with this program is the Matlab code of [Kook et al. (2015)][kook], modified to accommodate the expected inputs and outputs common to the other functions.

Finally, this code contains an adaptation of the Euclidean distance mapping-surface based scale analysis presented by Bescond et al. Modifications to allow the method to work directly on binary images (rather than a custom output from ImageJ) and to integrate the method into the Matlab environment may present some minor compatibility issues, but allows use of the aggregate segmentation methods given in the `agg` package. . 

#### References

1. [Kook et al., SAE Int. J. Engines (2015).][kook]
2. [Dastanpour et al., J. Powder Tech. (2016).][dastanpour2016]
3. [Dastanpour and Rogak, Aerosol Sci. Technol. (2014).][dastanpour2014]

[kook]: https://doi.org/10.4271/2015-01-1991
[dastanpour2016]: https://doi.org/10.1016/j.powtec.2016.03.027
[dastanpour2014]: https://doi.org/10.1080/02786826.2014.955565
