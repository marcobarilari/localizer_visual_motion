%% Visual hMT localizer using translational motion in four directions 
%  (up- down- left and right-ward)

% by Mohamed Rezk 2018
% adapted by MarcoB 2020

clc;




% Different duratons for different number of repetitions (may add a few TRs to this number just for safety)
% Cfg.numRepetitions=7, Duration: 345.77 secs (5.76 mins), collect 139 + 4 Triggers = 143 TRs at least per run 
% Cfg.numRepetitions=6, Duration: 297.86 secs (4.96 mins), collect 120 + 4 Triggers = 124 TRs at least per run 
% Cfg.numRepetitions=5, Duration: 249.91 secs (4.17 mins), collect 100 + 4 Triggers = 104 TRs at least per run 
% Cfg.numRepetitions=4, Duration: 201.91 secs (3.37 mins), collect 81 + 4 Triggers  = 85  TRs at least per run 









numTriggers = 4;

%% Setting
Cfg.experimentType = 'Dots';   % Visual modality is in RDKs
Cfg.possibleDirections = [-1 1];            % 1 motion , -1 static
Cfg.names = {'static','motion'};           
%Cfg.numRepetitions         = 6 ;
Cfg.speedEvent             = 4  ;           % speed in visual angles 
Cfg.numEventsPerBlock      = 12 ;           % Number of events per block (should not be changed)
Cfg.maxNumFixationTargetPerBlock = 2 ;      
Cfg.eventDuration          = 1.2 ;       
Cfg.interstimulus_interval = 0.1 ;                   % time between events in secs
Cfg.interBlock_interval    = 8 ;
Cfg.fixationChangeDuration = 0.15;                    % in secs

onsetDelay = 5;                                      % number of seconds before the motion stimuli are presented
endDelay = 5;                                        % number of seconds after the end all the stimuli before ending the run

%% Parameters for monitor setting
monitor_width  	 = 42;                            % Monitor Width in cm
screen_distance  = 134;                           % Distance from the screen in cm
diameter_aperture= 8;                             % diameter/length of side of aperture in Visual angles

Cfg.coh = 1;                                      % Coherence Level (0-1)
dotSize = 0.12;                                   % dot Size (dot width) in visual angles.
Cfg.maxDotsPerFrame = 300;                        % Maximum number dots per frame (Number must be divisible by 3)
Cfg.dotLifeTime = 0.2;                            % Dot life time in seconds
Cfg.dontclear = 0;
Cfg.dotSize = 0.1;

% manual displacement of the fixation cross
xDisplacementFixCross = 0 ;
yDisplacementFixCross = 0 ;

if mod(Cfg.maxDotsPerFrame,3) ~= 0
    error('Number of dots should be divisible by 3.')
end

%% Fixation Cross parameters
% Used Pixels here since it really small and can be adjusted during the experiment
Cfg.fixCrossDimPix = 10;                            % Set the length of the lines (in Pixels) of the fixation cross
Cfg.lineWidthPix = 4;                               % Set the line width (in Pixels) for our fixation cross

%% Color Parameters
White = [255 255 255];
Black = [ 0   0   0 ];
Grey  = mean([Black;White]);

Cfg.textColor           = White ;
Cfg.Background_color    = Black  ;
Cfg.fixationCross_color = White ;
Cfg.dotColor            = White ;

% Get Subject Name and run number
subjectName = input('Enter Subject Name: ','s');
if isempty(subjectName)
    subjectName = 'trial';
end

HideCursor;

if exist(fullfile('logfiles',[subjectName,'.mat']),'file')>0
    error('This file is already present in your logfiles. Delete the old file or rename your run!!')
end

%%  Experiment

try % safety loop: close the screen if code crashes
    
    AssertOpenGL;
    
    % any preliminary stuff
    %%%%%%%%%%%%%%%%%%%%%%%%%
    % Select screen with maximum id for output window:
    screenid = max(Screen('Screens'));
    % Open a fullscreen, onscreen window with gray background. Enable 32bpc
    % floating point framebuffer via imaging pipeline on it.
    PsychImaging('PrepareConfiguration');
    %PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
    
    Screen('Preference','SkipSyncTests', 1);
    
    if Cfg.TestingSmallScreen
        [Cfg.win, Cfg.winRect] = PsychImaging('OpenWindow', screenid, Cfg.Background_color,  [0,0, 480, 270]);
    else
        [Cfg.win, Cfg.winRect] = PsychImaging('OpenWindow', screenid, Cfg.Background_color);
    end
    
    % Get the Center of the Screen
    Cfg.center = [Cfg.winRect(3), Cfg.winRect(4)]/2;
    
    %% Fixation Cross
    xCoords = [-Cfg.fixCrossDimPix Cfg.fixCrossDimPix 0 0] + xDisplacementFixCross;
    yCoords = [0 0 -Cfg.fixCrossDimPix Cfg.fixCrossDimPix] + yDisplacementFixCross;
    Cfg.allCoords = [xCoords; yCoords];
    
    % Query frame duration
    Cfg.ifi = Screen('GetFlipInterval', Cfg.win);
    Cfg.monRefresh = 1/Cfg.ifi;
    
    % monitor distance
    Cfg.mon_horizontal_cm  	= monitor_width;                         % Width of the monitor in cm
    Cfg.view_dist_cm 		= screen_distance;                       % Distance from viewing screen in cm
    Cfg.apD = diameter_aperture;                                     % diameter/length of side of aperture in Visual angles
    
    
    % Everything is initially in coordinates of visual degrees, convert to pixels
    % (pix/screen) * (screen/rad) * rad/deg
    V = 2* (180 * (atan(Cfg.mon_horizontal_cm/(2*Cfg.view_dist_cm)) / pi));
    Cfg.ppd = Cfg.winRect(3) / V ;
    
    Cfg.d_ppd = floor(Cfg.apD * Cfg.ppd);                            % Covert the aperture diameter to pixels
    Cfg.dotSize = floor (Cfg.ppd * Cfg.dotSize);                          % Covert the dot Size to pixels
    
    %%
    % Enable alpha-blending, set it to a blend equation useable for linear
    % superposition with alpha-weighted source.
    Screen('BlendFunction', Cfg.win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % Initially sync us to VBL at start of animation loop.
    
    vbl = Screen('Flip', Cfg.win);
    
    % Text options/
    % Select specific text font, style and size:
    Screen('TextFont',Cfg.win, 'Courier New');
    Screen('TextSize',Cfg.win, 18);
    Screen('TextStyle', Cfg.win, 1);
    
    directions=[];
    speeds=[];
    fixationTargets=[];
    
    [directions, speeds, fixationTargets, names] = experimentalDesign(Cfg);
    
    numBlocks = size(directions,1);
    
    %%%%%%%%%%%%%%%%%%%%%%
    % experiment
    %%%%%%%%%%%%%%%%%%%%%%
    %Instructions
    DrawFormattedText(Cfg.win,'1-Detect the RED fixation cross\n \n\n',...
        'center', 'center', Cfg.textColor);
    Screen('Flip', Cfg.win);
    
    KbWait();
    KeyIsDown=1;
    while KeyIsDown>0
        [KeyIsDown, ~, ~]=KbCheck(-1);
    end
    
    %% Empty vectors and matrices for speed
    blockNames     = cell(numBlocks,1);
    blockOnsets    = zeros(numBlocks,1);
    blockEnds      = zeros(numBlocks,1);
    blockDurations = zeros(numBlocks,1);
    
    eventOnsets    = zeros(numBlocks,Cfg.numEventsPerBlock);
    eventEnds      = zeros(numBlocks,Cfg.numEventsPerBlock);
    eventDurations = zeros(numBlocks,Cfg.numEventsPerBlock);
    
    allResponses = [] ;
    %% Wait for Trigger from Scanner
    % open Serial Port "SerPor" - COM1 (BAUD RATE: 11520)
    
    if strcmp(Cfg.Device,'PC')
        DrawFormattedText(Cfg.win,'Waiting For Trigger',...
            'center', 'center', Cfg.textColor);
        Screen('Flip', Cfg.win);
        
        %%
        triggerCounter=0;
        %fprintf('Waiting for trigger \n');
        while triggerCounter < numTriggers
            [keyIsDown, ~, keyCode, ~] = KbCheck(-1);
            if strcmp(KbName(keyCode),Cfg.triggerKey)
                triggerCounter = triggerCounter+1 ;
                fprintf('Trigger %s \n', num2str(triggerCounter));
                DrawFormattedText(Cfg.win,['Trigger ',num2str(triggerCounter)],'center', 'center', Cfg.textColor);
                Screen('Flip', Cfg.win);
                
                while keyIsDown
                    [keyIsDown, ~, keyCode, ~] = KbCheck(-1);
                end
            end
        end

    end
    
    Screen('DrawLines', Cfg.win, Cfg.allCoords,Cfg.lineWidthPix, [255 255 255] , [Cfg.center(1) Cfg.center(2)], 1);
    Screen('Flip',Cfg.win);
    
    %% txt logfiles
    if ~exist('logfiles','dir')
        mkdir('logfiles')
    end
    
    BlockTxtLogFile = fopen(fullfile('logfiles',[subjectName,'_Blocks.txt']),'w');
    fprintf(BlockTxtLogFile,'%12s  %12s %12s %12s %12s \n',...
        'BlockNumber','Condition','Onset','End','Duration');
    
    EventTxtLogFile = fopen(fullfile('logfiles',[subjectName,'_Events.txt']),'w');
    fprintf(EventTxtLogFile,'%12s %12s %12s %18s %12s %12s %12s %12s \n',...
        'BlockNumber','EventNumber','Direction', 'IsFixationTarget','Speed','Onset','End','Duration');
    
    ResponsesTxtLogFile = fopen(fullfile('logfiles',[subjectName,'_Responses.txt']),'w');
    fprintf(ResponsesTxtLogFile,'%12s \n','Responses');
    
    %% Experiment Start
    Cfg.Experiment_start = GetSecs;
    
    WaitSecs(onsetDelay);
    
    %% For Each Block
    for iBlock = 1:numBlocks
        
        fprintf('Running Block %.0f \n',iBlock)
        
        blockOnsets(iBlock,1)= GetSecs-Cfg.Experiment_start;
        
        % For each event in the block
        for iEventsPerBlock = 1:Cfg.numEventsPerBlock
            
            iEventDirection = directions(iBlock,iEventsPerBlock);       % Direction of that event
            iEventSpeed = speeds(iBlock,iEventsPerBlock);               % Speed of that event
            iEventDuration = Cfg.eventDuration ;                        % Duration of normal events
            iEventIsFixationTarget = fixationTargets(iBlock,iEventsPerBlock);
            
            % Event Onset
            eventOnsets(iBlock,iEventsPerBlock) = GetSecs-Cfg.Experiment_start;
            
            % play the dots
            responseTimeWithinEvent = DoDotMo( Cfg, iEventDirection, iEventSpeed, iEventDuration, iEventIsFixationTarget);
            
            %% logfile for responses
            if ~isempty(responseTimeWithinEvent)
                fprintf(ResponsesTxtLogFile,'%8.6f \n',responseTimeWithinEvent);
            end
            
            %% Event End and Duration
            eventEnds(iBlock,iEventsPerBlock) = GetSecs-Cfg.Experiment_start;
            eventDurations(iBlock,iEventsPerBlock) = eventEnds(iBlock,iEventsPerBlock) - eventOnsets(iBlock,iEventsPerBlock);
            
            % concatenate the new event responses with the old responses vector
            allResponses = [allResponses responseTimeWithinEvent] ;
            
            Screen('DrawLines', Cfg.win, Cfg.allCoords,Cfg.lineWidthPix, [255 255 255] , [Cfg.center(1) Cfg.center(2)], 1);
            Screen('Flip',Cfg.win);
            
            
            %% Event txt_Logfile
            fprintf(EventTxtLogFile,'%12.0f %12.0f %12.0f %18.0f %12.2f %12.5f %12.5f %12.5f \n',...
                iBlock,iEventsPerBlock,iEventDirection,iEventIsFixationTarget,iEventSpeed,eventOnsets(iBlock,iEventsPerBlock),eventEnds(iBlock,iEventsPerBlock),eventDurations(iBlock,iEventsPerBlock));
            
            % wait for the inter-stimulus interval
            WaitSecs(Cfg.interstimulus_interval);
        end
        
        blockEnds(iBlock,1)= GetSecs-Cfg.Experiment_start;          % End of the block Time
        blockDurations(iBlock,1)= blockEnds(iBlock,1) - blockOnsets(iBlock,1); % Block Duration
        
        %Screen('DrawTexture',Cfg.win,imagesTex.Event(1));
        Screen('DrawLines', Cfg.win, Cfg.allCoords,Cfg.lineWidthPix, [255 255 255] , [Cfg.center(1) Cfg.center(2)], 1);
        Screen('Flip',Cfg.win);
        
        WaitSecs(Cfg.interBlock_interval)
        
        %% Block txt_Logfile
        fprintf(BlockTxtLogFile,'%12.0f %12s %12f %12f %12f  \n',...
            iBlock,names{iBlock,1},blockOnsets(iBlock,1),blockEnds(iBlock,1),blockDurations(iBlock,1));
        
    end
    
    blockNames = names ;
    
    % End of the run for the BOLD to go down
    WaitSecs(endDelay);
    
    % close txt log files
    fclose(BlockTxtLogFile);
    fclose(EventTxtLogFile);
    fclose(ResponsesTxtLogFile);
    
    
    TotalExperimentTime = GetSecs-Cfg.Experiment_start
    
    %% Save mat log files
    save(fullfile('logfiles',[subjectName,'_all.mat']))
    
    save(fullfile('logfiles',[subjectName,'.mat']),...
        'Cfg','allResponses','blockDurations','blockNames','blockOnsets')
    

    % Close the screen
    clear Screen;
    
catch              % if code crashes, closes serial port and screen
    clear Screen;

    error(lasterror) % show default error
end

