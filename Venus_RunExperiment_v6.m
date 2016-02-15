% Version 5 has fMRI and psychophysics experiments combined in a single file
% The parameter called "scanner" controls which parts of the code will be executed
% Version 2 uses 10 bit gamma table. This provides finer luminance steps
% when presenting low-contrast gratings
% Version 3: 19 Apr 2013, Arman
% Implemented changing probabilities when staying or switching L/R stimulus presentation sides
% after success or failure on the previous trial. The probabilities are passed on as arguments:
% failSwitchProbability, succeedStayProbability
% Version 6: 04 Mar 2015, arman
% implemented 1 or 0 sec before stimulus presentation to be able to
% account for 2 second TR. This randomly assigned jitter helps to
% sample signal which is at 2 sec to become sampled at 1 sec (at the expense of SNR)

% Commands to issue for different conditions:
% To induce fail/stay bias: Venus_RunExperiment_v5('subjectID=s001','age=38', 'gender=M', 'intensities=[0.004, 0.006, 0.009, 0.012, 0.03]','trialsPerIntensity=60', 'succeedStayProbability=0.5', 'failSwitchProbability=0.2')
% To induce fail/switch bias: Venus_RunExperiment_v5('subjectID=s001','age=38', 'gender=M', 'intensities=[0.004, 0.006, 0.009, 0.012, 0.03]','trialsPerIntensity=60', 'succeedStayProbability=0.5', 'failSwitchProbability=0.8')
% To induce success/switch bias: Venus_RunExperiment_v5('subjectID=s001','age=38', 'gender=M', 'intensities=[0.004, 0.006, 0.009, 0.012, 0.03]','trialsPerIntensity=60', 'succeedStayProbability=0.2', 'failSwitchProbability=0.5')
% To induce success/stay bias: Venus_RunExperiment_v5('subjectID=s001','age=38', 'gender=M', 'intensities=[0.004, 0.006, 0.009, 0.012, 0.03]','trialsPerIntensity=60', 'succeedStayProbability=0.8', 'failSwitchProbability=0.5')

% if there is a problem with MGL finding screen parameters on the computer in the
% psychophysics room, use this hack:
% mglSetParam('screenParamsFilename','/Users/yuko/.mglScreenParams.mat',1);

function success = Venus_RunExperiment_v6(varargin)

% Declare the stimulus variable to be global
clear global stimulus;
global stimulus;

% Parse input parameters. Assign defaults to parameters that haven't been
% assigned through varargin
[success, stimulus] = parseArgs(varargin);
if ~success, ErrorBeep; disp('(Venus_RunExperiment) Cannot parse input arguments. Please check and re-run'); return; end;

% Initialise mGL
expScreen = initScreen(stimulus);

% first phase of the task is to have a start delay.
% This is more needed for the fMRI experiment
task{1}.waitForBacktick = 0;
task{1}.seglen = [stimulus.run.startDelay 0.1];
task{1}.numTrials = 1;
task{1}.parameter.strength = 0;
task{1}.synchToVol = [0];

if stimulus.run.scanner == 1
    % Setup to run the task inside the scanner
    % Setup task to present the grating
    % The segments here are as follows:
    % 1. Stimulus presentation
    % 2. Response
    % 3. Feedback
    % 4. ITI - inter trial interval
    % 5. preStimulus jitter of either 0 or 1 sec. Used for whole-brain scan with TR=2 to achieve sampling at 1 sec by jittering the timing. 
    task{2}.seglenPrecompute = 1;   % Set this to precompute length of the experiment even if it trials are randomized
    task{2}.seglenPrecomputeSettings.framePeriod = 1.28;
    task{2}.numTrials = stimulus.run.nTrials;
    
    
    % Introduce 1 or 0 sec jitter right before the stimulus presentation
    % when using 2 sec TR. Helps to achieve 1 sec signal resolution.
    if stimulus.run.preStimJitter == 1 %  
        task{2}.segmin = [0.5 3 1.5 0.2 0 ];
        task{2}.segmax = [0.5 3 1.5 11.8 1];
        task{2}.segquant = [0 0 0 0 1];
        task{2}.synchToVol = [0 0 0 0 1];
    else % Do not add jitter. Used with faster (shorter) TR. 
        task{2}.segmin = [0.5 3 1.5 0.2];
        task{2}.segmax = [0.5 3 1.5 11.8];
        task{2}.synchToVol = [0 0 0 1];
    end
    % keyboard;
    task{2}.getResponse = [0 2 1];
    task{2}.parameter.intensities = stimulus.run.intensities;
    task{2}.randVars.calculated.contrast = nan;
    task{2}.randVars.calculated.side = nan;
    task{2}.randVars.calculated.contrast = nan;
    task{2}.randVars.calculated.signedContrast = nan;
    task{2}.randVars.calculated.side = nan;
    task{2}.randVars.calculated.signedSide = nan;
    % Switch on parameters that control synchronisation of the stimulus
    % with volume acquisition in the scanner
    % task{2}.synchToVol = [0 0 0 1];
    task{2}.waitForBacktick = 1;
else
    % Setup task to run outside the scanner - psychophysics only
    task{2}.numTrials = stimulus.run.nTrials;
    task{2}.segmin = [1 .5 4];
    task{2}.segmax = [2 .5 4];
    task{2}.getResponse = [0 0 1];
    task{2}.parameter.intensities = stimulus.run.intensities;
    % Switch off parameters that are only needed when in the scanner
    task{2}.synchToVol = [0 0 0 0];
    task{2}.waitForBacktick = 0;
end


% Setup colors that will be used in the experiment
SetupColors(expScreen);
% Setup drifting gratings
SetupGratingTextures(expScreen, task);
% Generate a random sequence for stimulus presentation
% and drifts
StimulusPresentationOrder(task);

% Custom random order of presentation
task{2}.randVars.stimRandomOrder = stimulus.run.stimRandomOrder;

% Set the color of front and back buffers to background
mglClearScreen(stimulus.colors.midGratingIndex);
mglFlush;
mglClearScreen(stimulus.colors.midGratingIndex);
mglFlush;

% Initiliase the task
[task{1} expScreen] = initTask(task{1},expScreen,@StartSegmentCallback,@UpdateScreenCallback,@ResponseCallback);
[task{2} expScreen] = initTask(task{2},expScreen,@StartSegmentCallback,@UpdateScreenCallback,@ResponseCallback);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% run the eye calibration
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
expScreen = eyeCalibDisp(expScreen);


% Main display loop
phaseNum = 1;
while (phaseNum <= length(task)) && ~expScreen.userHitEsc
    % Update trial and stimulus parameters
    [task expScreen phaseNum] = updateTask(task,expScreen,phaseNum);
    % Flip the screen to display the stimulus
    expScreen = tickScreen(expScreen,task);
end

% Print out stats about switching/staying when failing or succeeding
% Calculate proportion of trials presented on the same side after a success
vars = getTaskParameters(expScreen, task);
vars = cellArray(vars);
nTrials = vars{1}(2).nTrials;
responses = reshape(vars{1}(2).response, nTrials, 1);
ixSuccess = find(task{2}.randVars.stimRandomOrder(1:nTrials,2) == responses);
% Check if ixSuccess is empty (no successful responses were registered)
if ~isempty(ixSuccess)
    % If last trial is also success, remove it
    if ixSuccess(end) == nTrials
        ixSuccess = ixSuccess(1:end-1);
    end
    ixSuccessStay = find(task{2}.randVars.stimRandomOrder(ixSuccess,2) == task{2}.randVars.stimRandomOrder(ixSuccess+1,2));
    ixSuccessSwitch = find(task{2}.randVars.stimRandomOrder(ixSuccess,2) ~= task{2}.randVars.stimRandomOrder(ixSuccess+1,2));
    % Compute proportion of "success stay" and "success switch" trials
    pcIxSuccessStay =  length(ixSuccessStay) / (length(ixSuccessStay) + length(ixSuccessSwitch));
    pcIxSuccessSwitch = length(ixSuccessSwitch) / (length(ixSuccessStay) + length(ixSuccessSwitch));
    disp(sprintf('Percent success and staying = %3.1f', pcIxSuccessStay*100));
    disp(sprintf('Percent success and switching = %3.1f', pcIxSuccessSwitch*100));
else
    disp(sprintf('No success responses were found'));
end

% Now same computations for when subjects failed
ixFail = find(task{2}.randVars.stimRandomOrder(1:nTrials,2) ~= responses);
% Check if ixFail is empty (no failures were registered)
if ~isempty(ixFail)
    % If last trial is also success, remove it
    if ixFail(end) == nTrials
        ixFail = ixFail(1:end-1);
    end
    ixFailStay = find(task{2}.randVars.stimRandomOrder(ixFail,2) == task{2}.randVars.stimRandomOrder(ixFail+1,2));
    ixFailSwitch = find(task{2}.randVars.stimRandomOrder(ixFail,2) ~= task{2}.randVars.stimRandomOrder(ixFail+1,2));
    % Compute proportion of "success stay" and "success switch" trials
    pcIxFailStay =  length(ixFailStay) / (length(ixFailStay) + length(ixFailSwitch));
    pcIxFailSwitch = length(ixFailSwitch) / (length(ixFailStay) + length(ixFailSwitch));
    disp(sprintf('Percent fail and staying = %3.1f', pcIxFailStay*100));
    disp(sprintf('Percent fail and switching = %3.1f', pcIxFailSwitch*100));
else
    disp(sprintf('No failure responses were found'));
end

% Clean up the screen, and get ready to start quitting
mglClearScreen(stimulus.colors.midGratingIndex);
mglFlush;
% End the experiment and save the results
expScreen = endTask(expScreen,task); %%%%%%%%%%%%%%%% UNCOMMENT THIS LATER

end % Venus_RunExperiment


%*******************************************************
% function that gets called at the start of each segment
function [task myscreen] = StartSegmentCallback(task, myscreen)

global stimulus;
% The first task (task{1} is just a delay for the scanner. None of the code
% below will be executed and the screen will only show the background
% colour.

% Display contrast intensity presented on this trial
%if task.taskID == 2 && task.thistrial.thisseg == 2
if (task.taskID == 2 && task.thistrial.thisseg == 2 && stimulus.run.scanner == 0) | (task.taskID == 2 && task.thistrial.thisseg == 1 && stimulus.run.scanner == 1)
    intensity = task.randVars.stimRandomOrder(task.trialnum, 1);
    disp(sprintf('Contrast = %3.4f', stimulus.run.intensities(intensity)));
    task.thistrial.contrast = stimulus.run.intensities(intensity);
    visualField = task.randVars.stimRandomOrder(task.trialnum, 2);
    % Assign parameters that will be used for the fMRI data analysis
    if visualField == 1
        task.thistrial.signedContrast = -stimulus.run.intensities(intensity);
        task.thistrial.side = 1;
        task.thistrial.signedSide = -1;
    else
        task.thistrial.signedContrast = stimulus.run.intensities(intensity);
        task.thistrial.side = 2;
        task.thistrial.signedSide = 1;
    end
    
end

end % startSegmentCallback


%*******************************************************
% Handles updating the screen during each frame refresh
function [task myscreen] = UpdateScreenCallback(task, myscreen)

global stimulus;
% Clear screen to background color
mglClearScreen(stimulus.colors.midGratingIndex);

% if in scanner, show text to warn the subject to get ready
if stimulus.run.scanner == 1
    if task.taskID == 1 && task.thistrial.thisseg == 1
        intensity = 1;
        SetGammaTableForMaxContrast(stimulus.run.intensities(intensity));
        mglFixationCross(2, 3, stimulus.colors.reservedColor(2));
        mglTextSet('Helvetica',64, stimulus.colors.reservedColor(2));
        mglTextDraw('Please get ready', [0 +5]);
        mglTextDraw('The first stimulus will appear fast in about 5 sec', [0 -5]);
    end
    
    if task.taskID == 1 && task.thistrial.thisseg == 2
        intensity = 1;
        SetGammaTableForMaxContrast(stimulus.run.intensities(intensity));
        mglFixationCross(2, 3, stimulus.colors.reservedColor(2));
    end
end

% Draw just a fixation cross (task 2, segment 1) when we are out of the scanner
if task.taskID == 2 && task.thistrial.thisseg == 1 && stimulus.run.scanner == 0
    intensity = task.randVars.stimRandomOrder(task.trialnum, 1);
    % Utilise the 10 bit gamma by setting the maximum contrast level to the contrast level of the grating
    % to be presented
    SetGammaTableForMaxContrast(stimulus.run.intensities(intensity));
    mglFixationCross(2, 3, stimulus.colors.reservedColor(2));
end

% Draw fixation & the grating
if (task.taskID == 2 && task.thistrial.thisseg == 2 && stimulus.run.scanner == 0) | (task.taskID == 2 && task.thistrial.thisseg == 1 && stimulus.run.scanner == 1)
    intensity = task.randVars.stimRandomOrder(task.trialnum, 1);
    SetGammaTableForMaxContrast(stimulus.run.intensities(intensity));
    mglFixationCross(2, 3, stimulus.colors.reservedColor(2));
    % Present a drifting grating either in the left or right visual field
    % The random order of the grating intensity, visual field and and drift
    % orientation is stored in task.randVars.stimRandomOrder. It is a
    % ntrials by 3 array, where first element is intensity, second visual
    % field and the third element determines the drift orientation
    intensity = task.randVars.stimRandomOrder(task.trialnum, 1);
    visualField = task.randVars.stimRandomOrder(task.trialnum, 2);
    drift = task.randVars.stimRandomOrder(task.trialnum, 3);
    if visualField == 1
        coordinates = stimulus.run.leftVFCoord;
    else
        coordinates = stimulus.run.rightVFCoord;
    end
    % Compute which phase of the drifting grating to be displayed
    %gratingPhase = mglGetSecs(task.thistrial.segstart) /
    thisPhase = floor(mglGetSecs(task.thistrial.segstart) / myscreen.frametime);
    % Ensure thisPhase doesn't go beyond precomputed number of
    % phase-shifted gratings
    if thisPhase < stimulus.grating.nPhaseShifts
        if drift == 1 % drift to the left
            gratingPhaseToShow = stimulus.grating.nPhaseShifts - thisPhase;
        else
            gratingPhaseToShow = stimulus.grating.nPhaseShifts + thisPhase;
        end
        % Texture to graphics card. When using 10 bit gamma, "intensity"
        % variable below has no meaning because all textures are generated to
        % be at the highest possible contrast. The contrast clamping occurs on
        % the gamma level with the SetGammaTableForMaxContrast function used
        % above
        mglBltTexture(stimulus.grating.textures{intensity, gratingPhaseToShow}, coordinates);
        % Draw two annuli in the left and right visual field where stimulus is presented to reduce spatial uncertainty
        % draw reference points
        % mglLines2(stimulus.grating.refLines.x1,stimulus.grating.refLines.y1,stimulus.grating.refLines.x2,stimulus.grating.refLines.y2,1,stimulus.colors.reservedColor(2));
        % mglLines2(-6*stimulus.grating.refLines.x1,stimulus.grating.refLines.y1,-6*stimulus.grating.refLines.x2,stimulus.grating.refLines.y2,1,stimulus.colors.reservedColor(2));
        
        % mglGluAnnulus(stimulus.run.leftVFCoord(1), stimulus.run.leftVFCoord(2), 3.5, 3.54, [stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2)], 160, 2);
        % mglGluAnnulus(stimulus.run.rightVFCoord(1), stimulus.run.rightVFCoord(2), 3.5, 3.54, [stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2)], 160, 2);
        
        annulusRadius = stimulus.grating.width / 2 + 0.5; % Get the radius of stimulus and make it a little bigger so that Gabor is comfortably displayed inside
        mglGluAnnulus(stimulus.run.leftVFCoord(1), stimulus.run.leftVFCoord(2), annulusRadius, annulusRadius+0.04, [stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2)], 160, 2);
        mglGluAnnulus(stimulus.run.rightVFCoord(1), stimulus.run.rightVFCoord(2), annulusRadius, annulusRadius+0.04, [stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2) stimulus.colors.reservedColor(2)], 160, 2);
        
    end
    % disp(sprintf('(Venus_RunExperiment) grating display for trial number %i', task.trialnum));
end

% If in scanner, give visual feedback to the subject. Outside of the scanner, the feedback is only auditory
% Feedback segment
if task.taskID == 2 && task.thistrial.thisseg == 3 && stimulus.run.scanner == 1
    % Find out if the response was correct or incorrect
    % If correct, then display green fixation cross
    % If incorrect, display red fixation cross
    % If response correct, set fixation cross to green
    % Did the participant correclty detect the stimulus position
    % Did participant respond at all?
    if task.thistrial.gotResponse
        if stimulus.run.stimRandomOrder(task.trialnum, 2) == task.thistrial.whichButton
            mglFixationCross(2, 3, stimulus.colors.reservedColor(5));
        else
            mglFixationCross(2, 3, stimulus.colors.reservedColor(4));
        end
    else
        mglFixationCross(2, 3, stimulus.colors.reservedColor(4));
    end
end


if (task.taskID == 2 && task.thistrial.thisseg == 3 && stimulus.run.scanner == 0) | (task.taskID == 2 && task.thistrial.thisseg == 2 && stimulus.run.scanner == 1)
    mglFixationCross(2, 3, stimulus.colors.reservedColor(3));
end

% When in scanner, change the fixation to white color during the last segment when waiting for synchToVol
if task.taskID == 2 && task.thistrial.thisseg == 4 && stimulus.run.scanner == 1
    mglFixationCross(2, 3, stimulus.colors.reservedColor(2));
end

end % updateScreenCallback

%*******************************************************
%  Function that gets called when subject responds
function [task myscreen] = ResponseCallback(task,myscreen)

global stimulus

% TODO: add the code you want to use to process subject response

% make sure the response is a 1 or a 2
if (or(task.thistrial.whichButton == 1,task.thistrial.whichButton == 2))
    % here, we just check whether this is the first time we got a response
    % this trial and display what the subject's response was and the reaction time
    if task.thistrial.gotResponse < 1
        disp(sprintf('Subject response: %i Reaction time: %0.2fs', task.thistrial.whichButton, task.thistrial.reactionTime));
    end
    % Did the participant correclty detect the stimulus position
    if stimulus.run.stimRandomOrder(task.trialnum, 2) == task.thistrial.whichButton
        mglPlaySound(stimulus.run.correctSound);
        %keyboard;
        % Stay on the same side with the probability provided by succeedStayProbability
        % Switching will occur at the rate of 1-succeedStayProbability
        % If we are one trial before the last trial, or p of succeed stay & fail switch = 0.5
        % don't change order of trials because they are already shuffled with that probability
        if task.trialnum <= task.numTrials - 2
            if rand <= stimulus.run.succeedStayProbability  % if true, let's present next stimulus on the same side
                disp('*** SUCCESS: want to STAY');
                % Proceed only if the next trial is not scheduled to be presented on the same side already
                if stimulus.run.stimRandomOrder(task.trialnum, 2) ~= stimulus.run.stimRandomOrder(task.trialnum + 1, 2)
                    % if not, then find one forthcoming trial that is presented on the same side
                    ixSameSideTrials = find(stimulus.run.stimRandomOrder(task.trialnum+2:task.numTrials, 2) == stimulus.run.stimRandomOrder(task.trialnum, 2));
                    % If there are no more trials that can be presented on the same side, do nothing
                    % This can happen when we are close to the end of the session
                    if ~isempty(ixSameSideTrials)
                        % exchange next trial with the first subsequent trial that has the same presentation side as the current trial
                        tmp = stimulus.run.stimRandomOrder(task.trialnum + 1 + ixSameSideTrials(1), :);
                        stimulus.run.stimRandomOrder(task.trialnum + 1 + ixSameSideTrials(1), :) = stimulus.run.stimRandomOrder(task.trialnum + 1, :);
                        stimulus.run.stimRandomOrder(task.trialnum + 1, :) = tmp;
                        % Copy the new trial order to randVar
                        task.randVars.stimRandomOrder = stimulus.run.stimRandomOrder;
                        disp('*** Success: staying ***');
                    else
                        disp('*** SUCCESS BUT CANNOT STAY: NO MORE TRIALS ON SAME SIDE REMAIN ***');
                    end
                else
                    disp('*** Success: staying ***');
                end
            else % next trial should not be presented on the same side. If it is not, swap it with another one that's presented on opposite side
                disp('*** SUCCESS: want to SWITCH');
                if stimulus.run.stimRandomOrder(task.trialnum, 2) == stimulus.run.stimRandomOrder(task.trialnum + 1, 2)
                    % if not, then find one forthcoming trial that is presented on the same side
                    ixOtherSideTrials = find(stimulus.run.stimRandomOrder(task.trialnum+2:task.numTrials, 2) ~= stimulus.run.stimRandomOrder(task.trialnum, 2));
                    % If there are no more trials that can be presented on the same side, do nothing
                    % This can happen when we are close to the end of the session
                    if ~isempty(ixOtherSideTrials)
                        % exchange next trial with the first subsequent trial that has the same presentation side as the current trial
                        tmp = stimulus.run.stimRandomOrder(task.trialnum + 1 + ixOtherSideTrials(1), :);
                        stimulus.run.stimRandomOrder(task.trialnum + 1 + ixOtherSideTrials(1), :) = stimulus.run.stimRandomOrder(task.trialnum + 1, :);
                        stimulus.run.stimRandomOrder(task.trialnum + 1, :) = tmp;
                        % Copy the new trial order to randVar
                        task.randVars.stimRandomOrder = stimulus.run.stimRandomOrder;
                        disp('*** Success: switching ***');
                    else
                        disp('*** SUCCESS BUT CANNOT SWITCH: NO MORE TRIALS FOR SWITCHING REMAIN ***');
                    end
                else
                    disp('*** Success: switching ***');
                end
            end
        end
        % stimulus.run.succeedStayProbability = succeedStayProbability;
        % stimulus.run.failSwitchProbability = failSwitchProbability;
        
    else % Process failed responses
        mglPlaySound(stimulus.run.incorrectSound);
        disp('**************** INCORRECT RESPONSE **********************');
        % If we are one trial before the last trial, do nothing
        if task.trialnum <= task.numTrials - 2
            if rand > stimulus.run.failSwitchProbability  % if true, let's present next stimulus on the same side. If not, switch the side
                disp('*** FAILURE: want to STAY');
                % Proceed only if the next trial is not scheduled to be presented on the same side already
                if stimulus.run.stimRandomOrder(task.trialnum, 2) ~= stimulus.run.stimRandomOrder(task.trialnum + 1, 2)
                    % if not, then find one forthcoming trial that is presented on the same side
                    ixSameSideTrials = find(stimulus.run.stimRandomOrder(task.trialnum+2:task.numTrials, 2) == stimulus.run.stimRandomOrder(task.trialnum, 2));
                    % If there are no more trials that can be presented on the same side, do nothing
                    % This can happen when we are close to the end of the session
                    if ~isempty(ixSameSideTrials)
                        % exchange next trial with the first subsequent trial that has the same presentation side as the current trial
                        tmp = stimulus.run.stimRandomOrder(task.trialnum + 1 + ixSameSideTrials(1), :);
                        stimulus.run.stimRandomOrder(task.trialnum + 1 + ixSameSideTrials(1), :) = stimulus.run.stimRandomOrder(task.trialnum + 1, :);
                        stimulus.run.stimRandomOrder(task.trialnum + 1, :) = tmp;
                        % Copy the new trial order to randVar
                        task.randVars.stimRandomOrder = stimulus.run.stimRandomOrder;
                        disp('*** Failure: staying ***');
                    else
                        disp('*** FAILURE BUT CANNOT STAY: NO MORE TRIALS FOR STAYING LEFT ***');
                    end
                else
                    disp('*** Failure: staying ***');
                end
            else % next trial should not be presented on the same side. If it is not, swap it with another one that's presented on opposite side
                disp('*** Failure: want to SWITCH');
                if stimulus.run.stimRandomOrder(task.trialnum, 2) == stimulus.run.stimRandomOrder(task.trialnum + 1, 2)
                    % if not, then find one forthcoming trial that is presented on the same side
                    ixOtherSideTrials = find(stimulus.run.stimRandomOrder(task.trialnum+2:task.numTrials, 2) ~= stimulus.run.stimRandomOrder(task.trialnum, 2));
                    % If there are no more trials that can be presented on the same side, do nothing
                    % This can happen when we are close to the end of the session
                    if ~isempty(ixOtherSideTrials)
                        % exchange next trial with the first subsequent trial that has the same presentation side as the current trial
                        tmp = stimulus.run.stimRandomOrder(task.trialnum + 1 + ixOtherSideTrials(1), :);
                        stimulus.run.stimRandomOrder(task.trialnum + 1 + ixOtherSideTrials(1), :) = stimulus.run.stimRandomOrder(task.trialnum + 1, :);
                        stimulus.run.stimRandomOrder(task.trialnum + 1, :) = tmp;
                        % Copy the new trial order to randVar
                        task.randVars.stimRandomOrder = stimulus.run.stimRandomOrder;
                        disp('*** Failure: switching ***');
                    else
                        disp('*** Failure BUT CANNOT SWITCH: NO MORE TRIALS FOR SWITCHING LEFT ***');
                    end
                else
                    disp('*** Failure: switching ***');
                end
            end
        end
    end
    % when a correct key is pressed, move to the next segment
    task = jumpSegment(task);
end

end % ResponseCallback


%*******************************************************
% Setup color range used in the experiment
function SetupColors(expScreen)

global stimulus;
% set maximum color index (for 24 bit color we have 8 bits per channel, so 255)
maxIndex = 255;
% get gamma table
if ~isfield(expScreen,'gammaTable')
    stimulus.linearizedGammaTable = mglGetGammaTable;
    disp(sprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'));
    disp(sprintf('(taskTemplateContrast10bit:initGratings) No gamma table found in myscreen. Contrast'));
    disp(sprintf('         displays like this should be run with a valid calibration made by moncalib'));
    disp(sprintf('         for this monitor.'));
    disp(sprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'));
end
stimulus.linearizedGammaTable = expScreen.initScreenGammaTable;
% these are the reserved colors, if you need them later
% you can display them by setting your color to the appropriate
% index in stimulus.colors.reservedColor e.g. to get the
% second color, in this case white, you would do
% mglClearScreen(stimulus.colors.reservedColor(2));
stimulus.colors.reservedColors = [0 0 0; 1 1 1; 0 1 1; 1 0 0; 0 1 0];
% calculate some colors information
%  number of reserved colors
stimulus.colors.nReservedColors = size(stimulus.colors.reservedColors,1);
% number of colors possible for gratings, make sure that we
% have an odd number
stimulus.colors.nGratingColors = maxIndex+1-stimulus.colors.nReservedColors;
if iseven(stimulus.colors.nGratingColors)
    stimulus.colors.nGratingColors = stimulus.colors.nGratingColors-1;
end
% min, mid and max index of gratings colors (index values are 0 based)
stimulus.colors.minGratingIndex = maxIndex+1-stimulus.colors.nGratingColors;
stimulus.colors.midGratingIndex = stimulus.colors.minGratingIndex+floor(stimulus.colors.nGratingColors/2);
stimulus.colors.maxGratingIndex = maxIndex;
% number of contrasts we can display (not including 0 contrast)
stimulus.colors.nDisplayContrasts = floor(stimulus.colors.nGratingColors/2);
% get the color value for gray (i.e. the number between 0 and 1 that corresponds to the midGratingIndex)
stimulus.colors.grayColor = stimulus.colors.midGratingIndex/maxIndex;
% set the reserved colors - this gives a convenient value between 0 and 1 to use the reserved colors with
for i = 1:stimulus.colors.nReservedColors
    stimulus.colors.reservedColor(i) = (i-1)/maxIndex;
end

end % SetColors


%*********************************************************
% Generate textures for gratings of different intensities
% as welll as surrogate textures to generate leftward and
% rightward drifts
function SetupGratingTextures(expScreen, task)

%%%%% ***** NOTE *****
% This function generates a multiple of textures as it is a legacy code
% which had to generate textures of different contrast intensities. After
% implement 10 bit gamma table, all textures are generated at the
% maximum intensity and only the gamma table is adjusted to have a maximum
% level as per requested contrast intensity
global stimulus;
disppercent(-inf,'Creating grating textures');
% Phase shift step size to achieve requested temporal frequency
stimulus.grating.phaseShiftPerFrame = 360 * stimulus.grating.temporalFrequency / expScreen.framesPerSecond;
% Total number of phase shifts to fit into stimulus duration
stimulus.grating.nPhaseShifts = round(task{2}.segmin(2) / expScreen.frametime);
% stimulus.grating.phaseStep = stimulus.grating.totalPhaseShift / (stimulus.grating.nPhaseShifts - 1);
% Prepare grating textures for intensities that will be presented. Make it
% twice longer so that the grating can move to both left and right
gratingTextures = cellArray(stimulus.run.intensities, 2 * stimulus.grating.nPhaseShifts - 1);
% Prepare grating texture for all intensities
for ixGrating = 1:stimulus.run.nIntensities
    for ixPhase = 1:stimulus.grating.nPhaseShifts * 2 - 1;
        grating = mglMakeGrating(stimulus.grating.width, ...
            stimulus.grating.height, ...
            stimulus.grating.spatialFrequency, ...
            stimulus.grating.orientation, ...
            stimulus.grating.phase - (ixPhase - stimulus.grating.nPhaseShifts) * stimulus.grating.phaseShiftPerFrame);
        gaussianSD = stimulus.grating.width/6;  % A simple approch to adjusting the width of the gaussian
        gaussian = mglMakeGaussian(stimulus.grating.width, stimulus.grating.width, gaussianSD, gaussianSD);
        % Apply either gabor window or a circular window
        if strcmp(stimulus.grating.gratingWindowType,'gabor')
            % a gaussian window
            win = gaussian;
        else
            % a simple window limited to 1 standard deviation of Gaussian
            win = gaussian > exp(-1/2);
        end
        gabor = grating.*win;
        % Make grating backgound to match the background colour and apply contrast (contrast is not applied, but gamma table is altered elsewhere)
        gabor = stimulus.colors.midGratingIndex + round(stimulus.colors.nDisplayContrasts .* gabor);
        gratingTextures{ixGrating, ixPhase} = mglCreateTexture(gabor);
    end
    %     % For debugging purposes, display leftward drifting Gabor
    %     for ixPhase = 1:stimulus.grating.nPhaseShifts
    %         mglBltTexture(gratingTextures{ixGrating, stimulus.grating.nPhaseShifts - ixPhase + 1}, [6 6]);
    %         mglFlush;
    %         stimulus.grating.nPhaseShifts - ixPhase + 1
    %     end
    %     % For debugging purposes, display rightward drifting Gabor
    %     for ixPhase = 1:stimulus.grating.nPhaseShifts
    %         mglBltTexture(gratingTextures{ixGrating, stimulus.grating.nPhaseShifts + ixPhase - 1}, [6 6]);
    %         mglFlush;
    %     end
    disppercent(ixGrating/stimulus.run.nIntensities);
end
% save in "stimulus" global variable
stimulus.grating.textures = gratingTextures;
disppercent(Inf);

% set up reference lines
stimulus.grating.refLines.x1 = [];
stimulus.grating.refLines.y1 = [];
stimulus.grating.refLines.x2 = [];
stimulus.grating.refLines.y2 = [];
% Setup circular rings where stimulus to be presented
centerX = stimulus.grating.radius*cos(pi/180);
centerY = stimulus.grating.radius*sin(pi/180);
% get radius
radius = sqrt(((stimulus.grating.width/2)^2)+((stimulus.grating.height/2)^2))-0.5;
% get left/right top/bottom;
left = centerX-stimulus.grating.width/2;
right = centerX+stimulus.grating.width/2;
top = centerY-stimulus.grating.height/2;
bottom = centerY+stimulus.grating.height/2;
% circular reference lines
d = 0:1:360;
for dIndex = 1:length(d)-1
    stimulus.grating.refLines.x1 = [stimulus.grating.refLines.x1 centerX+radius*cos(d2r(d(dIndex)))];
    stimulus.grating.refLines.y1 = [stimulus.grating.refLines.y1 centerY+radius*sin(d2r(d(dIndex)))];
    stimulus.grating.refLines.x2 = [stimulus.grating.refLines.x2 centerX+radius*cos(d2r(d(dIndex+1)))];
    stimulus.grating.refLines.y2 = [stimulus.grating.refLines.y2 centerY+radius*sin(d2r(d(dIndex+1)))];
end

end %SetupGratingTextures

%*******************************************************
% Generate stimulus presentation order. Both left/right
% visual field and left right grating drift are randomi12sed
% in counterbalanced manner
function StimulusPresentationOrder(task)

global stimulus;
% Variable to store stimulus intensity, visual field (left or right) and
% drifting direction
stimRandomOrder = zeros(stimulus.run.nTrials, 3);
% Randomise left & right visual fields (VF) and generate equal number of
% left and right oriented drifts for each VF
for ixIntensity = 1:stimulus.run.nIntensities
    leftRightVFOrder = [repmat(1, 1, stimulus.run.trialsPerIntensity/2) repmat(2, 1, stimulus.run.trialsPerIntensity/2)]; % Left VF is coded as 1, and right VF as 2
    driftOrientation = repmat([1 2], 1, stimulus.run.trialsPerIntensity/2); % Left drift is 1, right drift is 2
    % Shuffle the order of left/right VF and corresponding drift orientations
    [leftRightVFOrder, shuffledIndex] = Shuffle(leftRightVFOrder);
    driftOrientation = driftOrientation(shuffledIndex);
    % Store the randomised order as intensity index, visual field, and
    % drift orientation in the variable stimRandomOrder
    indices = stimulus.run.trialsPerIntensity * (ixIntensity - 1) + 1:stimulus.run.trialsPerIntensity * ixIntensity;
    stimRandomOrder(indices, 1) = ixIntensity;
    stimRandomOrder(indices, 2) = transpose(leftRightVFOrder);
    stimRandomOrder(indices, 3) = transpose(driftOrientation);
    % TODO: reduce the probability of more than 3 successive stimulus presentations on the same side. A simple way would be
    % to find all 111 and 222 sequences using findstr and swap indexes of
    % trials that appear in the middle of 111 and 222 sequences. That is,
    % 111 and 222 will become 121 and 212.
end
% Shuffle again to randomise intensities
[tmp, ixRnd] = Shuffle(stimRandomOrder(:, 1));
stimRandomOrder = stimRandomOrder(ixRnd, 1:3);
% Store the shuffling results in the
stimulus.run.stimRandomOrder = stimRandomOrder;

end % StimulusRandomOrder

%**************************
%    getContrastIndex
function contrastIndex = getContrastIndex(desiredContrast,verbose)

if nargin < 2,verbose = 0;end

global stimulus;
if desiredContrast < 0, desiredContrast = 0;end

% now find closest matching contrast we can display with this gamma table
contrastIndex = min(round(stimulus.colors.nDisplayContrasts*desiredContrast/stimulus.currentMaxContrast),stimulus.colors.nDisplayContrasts);

% display the desired and actual contrast values if verbose is set
if verbose
    actualContrast = stimulus.currentMaxContrast*(contrastIndex/stimulus.colors.nDisplayContrasts);
    disp(sprintf('(getContrastIndex) Desired contrast: %0.4f Actual contrast: %0.4f Difference: %0.4f',desiredContrast,actualContrast,desiredContrast-actualContrast));
end

% out of range check
if round(stimulus.colors.nDisplayContrasts*desiredContrast/stimulus.currentMaxContrast)>stimulus.colors.nDisplayContrasts
    disp(sprintf('(getContrastIndex) Desired contrast (%0.9f) out of range max contrast : %0.9f',desiredContrast,stimulus.currentMaxContrast));
    keyboard
end

% 1 based indexes (0th index is gray, nDisplayContrasts+1 is full contrast)
contrastIndex = contrastIndex+1;

end % GetContrastIndex

%**********************************************************************************
% Sets the gamma table so that we can have
% finest possible control over the stimulus contrast.
%
% stimulus.reservedColors should be set to the reserved colors (for cue colors, etc).
% maxContrast is the maximum contrast you want to be able to display.
function SetGammaTableForMaxContrast(maxContrast)

global stimulus;
% if you just want to show gray, that's ok, but to make the
% code work properly we act as if you want to display a range of contrasts
if maxContrast <= 0,maxContrast = 0.01;end
% set the reserved colors
gammaTable(1:size(stimulus.colors.reservedColors,1),1:size(stimulus.colors.reservedColors,2))=stimulus.colors.reservedColors;
% set the gamma table
if maxContrast > 0
    % create the rest of the gamma table
    cmax = 0.5+maxContrast/2;cmin = 0.5-maxContrast/2;
    luminanceVals = cmin:((cmax-cmin)/(stimulus.colors.nGratingColors-1)):cmax;
    % now get the linearized range
    redLinearized = interp1(0:1/255:1,stimulus.linearizedGammaTable.redTable,luminanceVals,'linear');
    greenLinearized = interp1(0:1/255:1,stimulus.linearizedGammaTable.greenTable,luminanceVals,'linear');
    blueLinearized = interp1(0:1/255:1,stimulus.linearizedGammaTable.blueTable,luminanceVals,'linear');
    % add these values to the table
    gammaTable((stimulus.colors.minGratingIndex:stimulus.colors.maxGratingIndex)+1,:)=[redLinearized;greenLinearized;blueLinearized]';
else
    % if we are asked for 0 contrast then simply set all the values to gray
    gammaTable((stimulus.colors.minGratingIndex:stimulus.colors.maxGratingIndex)+1,1)=interp1(0:1/255:1,stimulus.linearizedGammaTable.redTable,0.5,'linear');
    gammaTable((stimulus.colors.minGratingIndex:stimulus.colors.maxGratingIndex)+1,2)=interp1(0:1/255:1,stimulus.linearizedGammaTable.greenTable,0.5,'linear');
    gammaTable((stimulus.colors.minGratingIndex:stimulus.colors.maxGratingIndex)+1,3)=interp1(0:1/255:1,stimulus.linearizedGammaTable.blueTable,0.5,'linear');
end
% set the gamma table
mglSetGammaTable(gammaTable);

end % SetGammaTableForMaxContrast

%********************************************
% parseArgs
function [success, stimulus] = parseArgs(args)

success = 1;
% Set arguments based on passed parameters. The rest will be set to defaults.
getArgs(args,{ ...
    'subjectID=TempVenus'...                % Default subject name
    'gender=NA'...                          % Subject's gender
    'age=NA'...                             % Subject's age
    'vision=NA'...                          % Subject's vision
    'dominantEye=NA'...                     % Subject's dominant eye
    'width=6', ...                          % grating width in degrees of visual angle
    'height=6', ...                         % grating height in degrees of visual angle
    'orientation=90', ...                   % grating orientation
    'spatialFrequency=1', ...               % grating spatial frequency in cycles per pixel
    'temporalFrequency=0.5', ...            % temporal frequency of the grating
    'gratingPhase=0', ...                   % grating's sinewave phase
    'gratingWindowType=gabor', ...          % Can be either gabor or threshold
    'radius=6', ...                         % Grating radius. Currently unused
    'leftVFCoord=[-12 0]',...                % Position of the stimulus in the left visual field
    'rightVFCoord=[12 0]', ...               % Position of the stimulus in the right visual field
    'intensities=[0.03, 0.02, 0.015, 0.01, 0.008, 0.005]', ...             % contrast intensities to test
    'nIntensities=[]', ...                  % Number of intensities
    'trialsPerIntensity=20', ...             % stim repetitions per contrast. SHOULD BE EVEN NUMBER
    'nTrials=[]'...                         % Total number of trials
    'stimDurationInFrames=4' ...            % stimulus length in number of frames. THIS IS CURRENTLY OBSOLETE
    'failSwitchProbability=0.5' ...         % Probability of presenting stimulus on the opposite side after a failure
    'succeedStayProbability=0.5'...         % Probability of presenting the stimulus on the same side after a success
    'firstIntervalButton=LeftShift' ...     % response button for the first interval CURRENTLY OBSOLETE
    'secondIntervalButton=RightShift' ...   % response button for the second interval CURRENTLY OBSOLETE
    'feedback=1'...                         % feedback to participant
    'soundStim=~/proj/grustim/sounds'...    % where feedback sounds are
    'correctSound=Pop'...                   % Sound feedback to correct responses
    'incorrectSound=Basso'...               % Sound feedback to incorrect responses
    'waitForBacktick=0' ...                 % Parameter used for scanner
    'preStimJitter=0' ...                   % if set to 1, means introduce 0 or 1 sec jitter right before the stimulus presentation. This is for slow TR to be able to sample signal at higher temporal frequency. 
    'scanner=0'...                          % Are we in the scanner?
    'startDelay=[]'
    });

% Subject parameters
stimulus.subjectID = subjectID;
stimulus.subject.gender = gender;
stimulus.subject.age = age;
stimulus.subject.vision = vision;
stimulus.subject.dominantEye = dominantEye;
% Grating parameters
stimulus.grating.width = width;
stimulus.grating.height = height;
stimulus.grating.orientation = orientation;
stimulus.grating.spatialFrequency = spatialFrequency;
stimulus.grating.temporalFrequency = temporalFrequency;
stimulus.grating.phase = gratingPhase;
stimulus.grating.radius = radius;
stimulus.grating.gratingWindowType = gratingWindowType;
% Set the startDelay duration depending we are in scanner or not
if scanner
    if isempty(waitForBacktick),waitForBacktick = 1;end
    if isempty(startDelay),startDelay = 10;end
else
    if isempty(waitForBacktick),waitForBacktick = 0;end
    if isempty(startDelay),startDelay = 0.1;end
end
% Set run parameters
stimulus.run.scanner = scanner;
stimulus.run.intensities = intensities;
stimulus.run.nIntensities = length(intensities);
stimulus.run.trialsPerIntensity = trialsPerIntensity;
stimulus.run.nTrials = length(intensities) * trialsPerIntensity;
stimulus.run.stimDurationInFrames = stimDurationInFrames;
stimulus.run.feedback = feedback;
stimulus.run.firstIntervalButton = firstIntervalButton;
stimulus.run.secondIntervalButton = secondIntervalButton;
stimulus.run.soundStim = soundStim;
stimulus.run.correctSound = correctSound;
stimulus.run.incorrectSound = incorrectSound;
stimulus.run.waitForBacktick = waitForBacktick;
stimulus.run.preStimJitter = preStimJitter; 
stimulus.run.startDelay = startDelay;
stimulus.run.leftVFCoord = leftVFCoord;
stimulus.run.rightVFCoord = rightVFCoord;
stimulus.run.succeedStayProbability = succeedStayProbability;
stimulus.run.failSwitchProbability = failSwitchProbability;

end % parseArgs
