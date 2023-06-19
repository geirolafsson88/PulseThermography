%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%           Pulse Thermography Class Example 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Create an instance of the class with thermal data and frame rate
thermaldata = double(data.data); % your thermal data as 3D array of images
frameRate = 383; % frame rate in frames per second
analysis = PulseThermography(thermaldata, frameRate);

% Set TSR setting
tsrOrder = 4;
analysis.setTSR(tsrOrder);

% Set Background Subtraction, choose how many images pre-flash to average
% to make 'low noise' reference image which is subtracted from the rest of
% the data
framestoaverage = 5;
analysis.setFramestoaverage(framestoaverage);

% Set PPT settings
pptWindowType = 'hamming'; % supports any built in window function in matlab
analysis.setPPT(pptWindowType,[],1); % window, zeropadding, truncation

% Define the desired processing sequence options:
% 'estimateflashframe','subtractreferenceframe', 'performTSR', 'performPPT' 'performPCT'

% Typical stack 
processingSequence = {'estimateflashframe','subtractreferenceframe','performTSR','performPPT'};
% Perform the analysis pipeline with the specified sequence
analysis.performAnalysis(processingSequence);

%% Visualise the data 
analysis.imshow(analysis.data(:,:,analysis.flashframe))





