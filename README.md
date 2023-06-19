# PulseThermography

**Author:** Geir Olafsson 

**Affiliation:** University of Bristol 

**Platform:** 
The code is written for Matlab, using version 2023a, other versions should work but functions in Matlab can and do change over time so universal compatibility cannot be guaranteed. 

**Description:**
The class is used to process and visualise pulse thermography inpsection data. The code is designed to run several processing functions in sequence, layering processing on top of previous processing. 

**Usage:** 
The first step is to inialise the class, it needs 2 variables to do this, the thermal data you want to process, and the framerate of the camera used to acquire the data. For example lets say we have imported our data into matlab and stored it in a variable called `thermal_data` and we know our frame rate was 383. 
```matlab
analysis = PulseThermography(thermal_data,383);
```
This will inialise the class with all required settings you need to run an analysis. Note you do not have to name your class intance analysis, it can be whatever you want, but make sure you use whatever name you choose in place of `analysis` in the below examples. 


# Functions

## estimateflashframe()
This function assumes you acquired some images before applying the pulse heating. It will search for the frame with the highest peak temperatures, and assumes this is the moment at which the flash was activated. 

**Usage:**
```matlab
analysis.estimateflashframe();
```

The flash frame is stored in the class instance, you can access it using:
```matlab
analysis.flashframe 
```

## subtractreferenceframe()
This function also assumes you acquired some images before applying the pulse heating. It will take several images from the start of your data, average them to get one 'low noise' reference frame. This is then subtracted from the whole dataset, and the mean of the reference image is added to restore real temperature values. This is a useful function if you have environmental artifacts in your data, e.g. narcasistic effects from cooled photon detector. 

**Usage:**
```matlab
frames = 5; % optional
analysis.setFramestoaverage(frames); % optional 
analysis.subtractreferenceframe(); % can be run on its own, 5 frames from start of data will be used
```

where frames is how many frames you want to average. You do not have to call the `setFramestoaverage`, if you do not, the default of 5 frames will be used. 

 
## performPCT()
This function implements Principal Component Thermography, a method developed by Nik Rajic. It looks for statistical variations in the data using principal component analysis. The processing is applied to the raw data by default, but you can specify that the TSR data is used instead by setting
`pctIn = 'tsr'`.

**Usage:**
```matlab
analysis.performPCT();
```

The output data is stored in `analysis.pctOutput` as a 3D array, you will normally be interested in frames 2-8 or so, beyond that is normally noise.


## performTSR()
This function performs thermal signal reconstruction developed by Stepehen Sheppard. This method exploits the fact that thermal decay after pulse heating should be exponential in theory. Therefore, the temperature measured by each pixel is moved to logarithmic domain, and a low order polynomial fit is made to the data, and then the signal is moved back to linear scale by taking exponential of the fit. This processing is effective at minimising noise in the data while retaining information that relates to damage/defects. It is important to pick a low order for the polynomial fit, however its often necessary to alter the order for a specific test. This is achieved either using: 
```matlab
analysis.setTSR(order)
```

where order is normally an integer between 4 and 8, if this line is not used, the default value of 5 will be used. The processing can then be run using: 
```matlab
analysis.performTSR()
```
Several outputs are generated, `analysis.tsrTemperature` is the reconstructed temperature data (smoothed), there are also `analysis.tsrDiff` and `analysis.tsrDiff2` which are 
differentiated signals, this is possible because the data is so smooth after TSR. Diff2 is second derivative. These are nice as they often increase contrast 
making defects clearer. 

## performPPT()
This function performs Pulse Phase Thermogrpahy as developed by Maldague and Marinetti. This function uses a Fast Fourier Transform (FFT) to move the  temporal thermal data to the frequency domain. The FFT will decompose the temporal signal into the constituent frequency components, returning the magnitude and phase of the response at each frequency. Normally the phase is most interesting as it is less affected by heating non-uniformity and environmental effects. There are several optional settings that can improve the results (see G. Ólafsson, R. C. Tighe, and J. M. Dulieu-Barton, “Improving the probing depth of thermographic inspections of polymer composite materials,” Meas. Sci. Technol., vol. 30, no. 2, p. 025601, Feb. 2019, doi: 10.1088/1361-6501/aaed15.)

The simplest usage of this function is simply: 

```matlab
analysis.performPPT();
```

This will use the raw thermal data as the input to PPT, unless TSR has already been performed, in which case TSR smoothed thermal data will be used. If you want to specify the data input use `analysis.pptIn = 'tsr'`, or `'raw'`. The other settings you can set is you can window the data before processing. This helps to reduce what is known as spectral leakage which is a limitation of FFT processing. Windows reduce spectral leakage, but at the cost of smearing the data a bit in the frequency domain. The code supports all matlab built in windowing functions, they are specified using the matlab syntax, e.g. a rectangular window is called using `'rectwin'`. A rectangular window is equivilant to no window, and therefore has the highest leakage, and the highest frequency resolution. A flattop window almost elminates spectral leakage, but results in the lowest frequency resolution. Hamming funciton is a nice middle ground and is therefore the default. 

Other options, the number of samples in the input data determine how many frequencies the FFT will seperate out, known as frequency bins. The more frequency bins, the closer the spacing between bins. One way of cheating here is to add zeros to the end of your input signal. This is similar to interpolation, as the zeros do not actually have any information which contributes to the analysis. This process is called zero padding and you can set the size of the signal you want using `analysis.pptN = 3000;` The syntax is the number you specify will be the final length of each signal, i.e. your signal plus concantenated with the zeros will end up being 3000 samples long in this example. 

In PPT it can also be problematic that the respsonse just at the flash can cause effects that make FFT less effective. Namely, FFT does not work well with transient signals, by chopping some of the start of the signal off before running the FFT, we can often make the signal less transient and easier to process. This is known as truncation, and can be set using e.g. `analysis.pptTruncation = 30;` which would trim 30 frames from the start of the signal. 

All these settings can be set in one go if you prefer using: 
```matlab
analysis.setPPT(window,N,truncation)
```

Then use:
```matlab
analysis.performPPT();
```
The data is stored in `analysis.pptPhase` as 3D array, where third dimension is frequency, and the first two dimensions are phase images. Normally the lower frequencies correspond to deeper damage/defects and higher frequencies to information closer to the surface. The lower frequency data is slightly blurrier, due to lateral diffusion at these frequencies, higher frequencies give you sharper details. You can see what frequencies corrospond to what frames by looking at the `analysis.pptFrequencies` variable. 


## performAnalysis()
This function allows you set the analysis sequence as a processing pipeline all in one line, instead of as shown in the previous examples. This is really nice for running a quick analysis. The input argument is simply a cell array of the processing functions you want to run. You can setup any specific parameters, e.g. TSR order or input variables to various functions before you call this function, and then: 
```matlab
analysis.performAnalysis({'estimateflashframe','removeBackground','performTSR','performPPT','performPCT'});
```
In such a scenario, it is possible to run an entire analysis in as few as two lines (using the default settings) e.g. 
```matlab
analysis = PulseThermography(data,framerate);
analysis.performAnalysis({'estimateflashframe','removeBackground','performTSR','performPPT','performPCT'});
```

## imshow()
This function plots data as an image, this uses the built in function imagesc, the only real difference is a few of the visualisation settings are pre-defined to make plotting a bit more efficient. You can still use all the normal matlab calls to modify this figure. This function can be used with any of the data outputs from above, TSR, PCT and PPT as well as the raw thermal data. 

e.g. to look at the phase image in third frequency bin 
```matlab
analysis.imshow(analysis.pptPhase(:,:,3));
```
You could add a title with the frequency of this bin if you wanted using 
```
title(['Frequency = ',num2str(analysis.pptFrequencies(3))])
```

# Class Properties

Class Properties

The class has some properties that store important information about your thermal data and the analysis settings. Here's what each property means:

data: This is where you store your thermal data, which should be a three-dimensional array.

frameRate: This property holds the frame rate at which the thermal data was captured, integer.

flashframe: It represents the frame number where the flash occurred, integer.

famestoaverage: You can set the number of frames to be used for reference frame subtraction, integer.

tsrOrder: This property defines the order of the polynomial used for Temperature Signal Reconstruction (TSR), integer >4 and <8 .

tsrTemperature: After performing TSR processing, this property holds the resulting temperature data, 3D array.

tsrDiff and tsrDiff2: These properties store the first and second derivatives of the TSR temperature data, respectively, 3D array.

pptWindowType: Represents the type of window used for Pulse Phase Thermography (PPT) processing, string.

pptN: This property defines the number of points used for padding during PPT processing, integer.

pptIn: You can set the input data used for Pulse Phase Thermography (PPT) processing, string ('raw' or 'tsr').

pptTruncation: It determines the number of frames to truncate during PPT processing.

pptPhase: After performing PPT processing, this property stores the phase data.

pctIn:  Set data input you want to use for Principal Component Thermography, string ('raw' or 'tsr')

pctOutput: Stores output from Principal Component Thermography (PCT) processing.

usercolormap: You can specify the colormap used for data visualization.

