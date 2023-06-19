classdef PulseThermography < handle
    properties
        data
        frameRate
        flashframe
        framestoaverage = 5
        tsrOrder = 5
        tsrTemperature
        tsrDiff
        tsrDiff2
        pptWindowType = 'hamming'
        pptN = []
        pptIn
        pptTruncation = 1
        pptFrequencies
        pptPhase
        pctIn = 'raw'
        pctOutput
        usercolormap = 'jet'

    end

    methods
        %          ####### Setup Functions #######

        % Initialise class and set camera frame rate 
        function obj = PulseThermography(data, frameRate)  
            % Check the use put something sensible for thermal data 
            if ~isnumeric(data) || ndims(data) ~= 3
                error('First argument, thermal data, should be a 3D array.');
            end
            
            % Check the framerate is set correctly 
            if ~isnumeric(frameRate) || ~isscalar(frameRate) || frameRate ~= round(frameRate)
                error('Second argument, camera framerate, should be a single integer.');
            end
            
            % Check if the variables are the wrong way around 
            if ndims(frameRate) == 3  
                error(['You might have swapped the arguments. ' ...
                    '\nPlease provide the 3D array of thermal data (3rd dim is time) as the first argument\n ' ...
                    'and the single integer for the camera framerate as the second argument.']);
            end

            % If all looks good the capture the input arguements within the
            % class
            obj.data = data;
            obj.frameRate = frameRate;
        end

        % Set TSR processing settings 
        function setTSR(obj, tsrOrder)
            % Check the inputs 
            if ~isnumeric(tsrOrder) || ~isscalar(tsrOrder) || tsrOrder ~= round(tsrOrder)
                error('tsr should be a single integer.');
            end

            if 8>tsrOrder || tsrOrder>3
                warning('TSR polynomial order should typically be between 4 and 7\n consider changing the specified order')
            end

            obj.tsrOrder = tsrOrder;
        end

        % Set PPT processing settings 
        function setPPT(obj, pptWindowType, pptN, pptTruncation)
            obj.pptWindowType = pptWindowType;
            obj.pptN = pptN;
            obj.pptTruncation = pptTruncation;
        end

        % Set the flash frame manually 
        function setFlashFrame(obj, flashframe)
            % Check the input 
            if ~isnumeric(flashframe) || ~isscalar(flashframe) || flashframe ~= round(flashframe)
                error('Flashframe should be a single integer.');
            end

            obj.flashframe = flashframe;
        end

        % Set number of frames to average for reference frame subtraction 
        function setFramestoaverage(obj,framestoaverage)
            % Check the input
            if ~isnumeric(framestoaverage) || ~isscalar(framestoaverage) || framestoaverage ~= round(framestoaverage)
                error('Number of frames should be a single integer.');
            end

            obj.framestoaverage = framestoaverage;
        end


        %          ####### Data Processing Functions #######
        function estimateflashframe(obj)
            assert(~isempty(obj.data), 'Temperature data is not set.');
            flash = find(mean(mean(obj.data, 1), 2) == max(mean(mean(obj.data, 1), 2)));
            fprintf('Estimated Flash Frame: %d\n', flash);
            obj.setFlashFrame(flash);
            
        end

        function subtractreferenceframe(obj)
            obj.opening();
            fprintf('Background Subtraction (Frames: %d)\nProcessing...\n',obj.framestoaverage)
            % Build an average of first 'frames' frames
            Ref = mean(obj.data(:, :, 1:obj.framestoaverage), 3);

            % Subtract reference frame from raw thermal data 
            obj.data = obj.data - Ref;

            % Print complete
            obj.closing();

        end

        function performPCT(obj)
            % Perform PCT processing
            obj.opening();
            fprintf('Principal Component Thermography\nProcessing...')

            assert(~isempty(obj.data), 'Temperature data is not set.');
            assert(~isempty(obj.flashframe), 'Flash frame is not set.');


            pctdata = pickdata(obj,obj.pctIn);

            % pctdata = obj.data(:,:,obj.flashframe:end);
            [rows, cols, frames] = size(pctdata);
            els = numel(pctdata(:,:,1));

            % Initialise
            A = zeros(els,frames);

            % Convert each frame into a vector and store as column vector in 2D array (n x m)
            for i = 1:frames

                A(:,i)= reshape(pctdata(:,:,i),1,[]);

            end

            % Store in new variable just in case... this wastes ram, so can
            % be changed if necessary 
            N = A.*0;

            % Perform PCT on the reshaped data
            for i = 1:size(N,2)
                N(:,i) = (A(:,i)-mean(A(:,i)))/std(A(:,i));

            end

            [~, score, ~] = pca(N);

            % Reshape the PCT score back to the original size
            pctOut = pctdata.*0;
            for i = 1:frames
                pctOut(:,:,i)= reshape(score(:,i),rows,cols);
            end

            % Save it to the class
            obj.pctOutput = pctOut;

            % Print complete
            obj.closing();

        end

        function performTSR(obj)
            % Perform TSR processing
            obj.opening();

            % Error handling 
            fprintf('TSR Processing (Order: %d, Frame Rate: %d FPS)\n', obj.tsrOrder, obj.frameRate);
            assert(~isempty(obj.data), 'Temperature data is not set.');
            assert(~isempty(obj.flashframe), 'Flash frame is not set.');
            assert(~isempty(obj.tsrOrder), 'TSR order is not set.');
            assert(~isempty(obj.frameRate), 'FPS is not set.');

            % Polynomial order sanity check
            if obj.tsrOrder > 8
                fprintf('Suggest lowering polynomial order below 8')
            elseif obj.tsrOrder < 4
                fprintf('Suggest increasing polynomial order above 4')
            else
                % fprintf(['Polynomial Order = ',num2str(obj.tsrOrder),'\n'])
            end

            fprintf('Processing...\n')
            
            % Take natural log of the temporal thermal data 
            tsrln = log(obj.data(:,:,obj.flashframe+1:end-1)); 

            % Build logarythmic time variable
            tsrTime = log((1:size(tsrln,3))/obj.frameRate);
            
            % Initialise Variables 
            coefs = zeros(size(tsrln,1),size(tsrln,2),(obj.tsrOrder+1));
            q = zeros(size(tsrln,1),size(tsrln,2),size(tsrln,3));
            
            % Fit polynomial in log domain 
            for i = 1:size(tsrln,1)
                for j = 1:size(tsrln,2)

                    tmp = polyfit(tsrTime,reshape(tsrln(i,j,:),1,size(tsrln,3)),obj.tsrOrder);
                    q(i,j,:) = polyval(tmp,tsrTime);
                    coefs(i,j,:) = tmp;
                
                end
            end
            
            % Calculate derivatives 
            fprintf('Calculating derivatives...\n');
            obj.tsrDiff=diff(q,1,3); % more efficient version
            obj.tsrDiff2 = -diff(q,2,3);

            % Reconstruct the signal by converting back to linear scale
            fprintf('Reconstructing thermal data...\n');
            obj.tsrTemperature = exp(q);

            % Print complete 
            obj.closing();

        end

        function performPPT(obj)
            obj.opening();
                        
            % Error handling 
            assert(~isempty(obj.data), 'Temperature data is not set.');
            assert(~isempty(obj.flashframe), 'Flash frame is not set.');
            assert(~isempty(obj.pptTruncation), 'PPT truncation is not set.');
            
            
            % Select the input data 
            % 
            % Check if TSR has been done, and that make sure the user has
            % not defined a specific variable to process instead. If so,
            % use the TSR data as the input to PPT.
            if ~isempty(obj.tsrTemperature) && isempty(obj.pptIn)
                obj.pptIn = 'tsr';
                [pptdata, flash]= obj.pickdata(obj.pptIn);
                
            % if the user has selected something different as input, use
            % that
            elseif ~isempty(obj.pptIn)
                [pptdata,flash]= obj.pickdata(obj.pptIn);
                
            % if nothing is set, and tsr does not look like its been done,
            % then just use the raw data. 
            else
                obj.pptIn = 'raw';
                [pptdata,flash] = obj.pickdata(obj.pptIn);
                
            end
            
            fprintf('PPT processing using %s data\n(Window Type: %s, Pad: %i, Trunc: %i)\n', ...
                obj.pptIn,obj.pptWindowType,obj.pptN,obj.pptTruncation);
            fprintf('Processing...\n')
            % Truncate the data
            dataTruncated = pptdata(:, :, flash + obj.pptTruncation:end);
            
            % Create a windowing functin 
            window = feval(obj.pptWindowType, size(dataTruncated, 3));
            
            % Window the data 
            windowedData = bsxfun(@times, dataTruncated, reshape(window, 1, 1, []));
            
            % Pad the data for psuedo improved frequency resolution 
            inputPadded = padarray(windowedData, [0, 0, obj.pptN - size(windowedData, 3)], 'post');
            
            % Apply FFT 
            output = fft(inputPadded, obj.pptN, 3);
            
            % Calculate the phase, only output half the spectrum (FFT output is
            % mirrored about Nyquist frequency) 
            obj.pptPhase = angle(output(:, :, 1:(round(size(output, 3)/2))));
            
            % Calculate the frequenices for each frequency bin 
            obj.pptFrequencies = (0:size(obj.pptPhase,3)-1).*(obj.frameRate/size(obj.pptPhase,3));

            % Print complete 
            obj.closing();

        end

        function performAnalysis(obj, processingSequence)
            obj.opening();
            fprintf('Starting Thermal Analysis Pipeline\n')
            
            % Perform the analysis based on the specified sequence
            for i = 1:numel(processingSequence)
                switch processingSequence{i}
                    case 'estimateflashframe'
                        obj.estimateflashframe();
                    case 'subtractreferenceframe'
                        obj.subtractreferenceframe();
                    case 'performPCT'
                        obj.performPCT();
                    case 'performTSR'
                        obj.performTSR();
                    case 'performPPT'
                        obj.performPPT();
                end
            end

            % Print complete
            obj.opening();
            fprintf('All processing in pipeline complete')
            obj.opening();

        end
        
        %          ####### Data Visualisation Functions #######
        function imshow(obj,data)
            % Plot data with default styles 
            figure 
            imagesc(data)
            axis image 
            axis('off')
            colorbar
            colormap(obj.usercolormap)
            set(gca,'fontsize',14)

        end

    end % Public methods 

    methods(Access = private)
        function opening(obj)
            fprintf('\n-------------------------------------------------------\n')
        end

        % Similar, but for the end of functions
        function closing(obj)
            fprintf('Complete')
            obj.opening();
        end

        function [input_data,flash] = pickdata(obj,selected_data)
            switch selected_data
                case 'tsr'
                    input_data = obj.tsrTemperature;
                    flash = 1;
%                     fprintf('tsr')
                case 'ppt'
                    input_data = obj.pptPhase;
                    flash = 1;
%                     fprintf('ppt')
                otherwise 
                    input_data = obj.data;
                    flash = obj.flashframe;
%                     fprintf('obj')
            end % switch
        end % pickdata

    end % private methods 


%          ####### Static Methods #######
    % methods(Static)
        % Decoration for printing to command window

    % end

end % class 
