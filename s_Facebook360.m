%% s_Facebook360
% Simulate the Facebook Surround360 camera rig.
%
% TL, SCIEN Stanford, 2017
%
%% Initialize
ieInit;
if ~piDockerExists, piDockerConfig; end

%% Set parameters

% Rendering parameters
gcloudFlag = 0;
sceneName = 'whiteRoom';
filmResolution = [128 128];
pixelSamples = 128;
bounces = 4;

% Save parameters
workingDir = fullfile(piRootPath,'local');
if(~exist(workingDir,'dir'))
    mkdir(workingDir);
end

% Camera parameters
% We use the function "mapSurround360Cameras" later in the script to
% generate camera positions according to the Surround360 setup.
% By default, cam0 is a fisheye pointing up and cam(N+1) and cam(N+2) are
% fisheyes pointing down, where N = numCamerasCircum. This is according to
% the convention of the Surround360 rig.
numCamerasCircum = 14;
whichCameras = [1:3]; %[0:16] + 1; % Which cameras you'd like to render.
radius = 230;% mm

%% Setup

% Setup gcloud
if(gcloudFlag)
    gCloud = gCloud('dockerImage','gcr.io/primal-surfer-140120/pbrt-v3-spectral-gcloud',...
        'cloudBucket','gs://primal-surfer-140120.appspot.com');
    gCloud.renderDepth = true;
    gCloud.clusterName = 'trisha';
    gCloud.maxInstances = 20;
    gCloud.init();
end

% Setup save directory. We name the save directory as follows to help avoid
% overwriting previous renders (which an potentially be a very
% computationally costly mistake!)
saveDir = fullfile(workingDir, ...
    sprintf('%s_%i_%i_%i_%i',...
    sceneName,...
    filmResolution(1),...
    filmResolution(2),...
    pixelSamples,...
    bounces));
if(~exist(saveDir,'dir'))
    mkdir(saveDir);
end


%% Select scene
[pbrtFile,rigOrigin] = selectBitterliScene(sceneName);

%% Read the file
recipe = piRead(pbrtFile,'version',3);

%% Calculate camera locations

% Calculates the correct lookAts for each of the cameras.
% First camera is the one looking up
% Followed by the cameras around the circumference
% Followed by the two cameras looking down.
[camOrigins, camTargets, camUps, camI] = ...
    mapSurround360Cameras(numCamerasCircum,radius);

% Only render selected cameras
camOrigins = camOrigins(whichCameras,:);
camTargets = camTargets(whichCameras,:);
camUps = camUps(whichCameras,:);
camI = camI(whichCameras);

% Plot the rig
plotRig(camOrigins,camTargets,camUps,camI)

%% Change the camera lens

recipe.set('camera','realistic');

% Focus at roughly meter away.
recipe.set('focusdistance',1.5);

%% Loop through each camera in the rig and render.

% For gCloud
rigInfo = cell(size(camOrigins,1),5);
allRecipes = cell(size(camOrigins,1),1);

for ii = 1:size(camOrigins,1)
    
    % Follow Facebook's naming conventions for the cameras
    oiName = sprintf('cam%i',camI(ii));
    
    %% Change the lens depending on the camera
    % We will use a wide angle lens that is our closest match to the Facebook
    % lens.
    if(camI(ii) == 0 || camI(ii) == (numCamerasCircum+1) || camI(ii) == (numCamerasCircum+2))
        % Top and bottom cameras
        lensFile = fullfile(piRootPath,'data','lens','fisheye.87deg.6.0mm.dat');
    else
        % Circumference cameras
        lensFile = fullfile(piRootPath,'data','lens','wide.56deg.6.0mm.dat');
    end
    
    % Set sensor size
    recipe.set('filmdiagonal',16); % Facebook (1")
    
    % Attach the lens
    recipe.set('lensfile',lensFile);

    
    % Set the aperture to be the largest possible.
    % PBRT-v3-spectral will automatically scale it down to the largest
    % possible aperture for the chosen lens.
    recipe.set('aperturediameter',10); % mm
    
    %% Set render quality
    recipe.set('filmresolution',filmResolution);
    recipe.set('pixelsamples',pixelSamples);
    recipe.set('maxdepth',bounces);
    
    %% Set camera lookAt
    
    % PBRTv3 has units of meters, so we scale here.
    origin = camOrigins(ii,:)+ rigOrigin;
    target = camTargets(ii,:)+ rigOrigin;
    up = camUps(ii,:)+ rigOrigin.*camUps(ii,:);
    recipe.set('from',origin);
    recipe.set('to',target);
    recipe.set('up',up);
    
    recipe.set('outputFile',fullfile(workingDir,strcat(oiName,'.pbrt')));
    
    piWrite(recipe);
    
    if(gcloudFlag)
        % Save all generated recipes in a cell matrix to be uploaded to
        % gCloud later in the script.
        allRecipes{ii} = copy(recipe);
        
        % Save rig info in a large cell matrix. We will save these in the
        % optical image after we download the rendered data from gCloud.
        rigInfo{ii,1} = oiName;
        rigInfo{ii,2} = origin;
        rigInfo{ii,3} = target;
        rigInfo{ii,4} = up;
        rigInfo{ii,5} = rigOrigin;
        
    else
        % Otherwise render normally.
        [oi, result] = piRender(recipe);
        vcAddObject(oi);
        oiWindow;
        
        % Save the OI along with location information
        oiFilename = fullfile(saveDir,oiName);
        save(oiFilename,'oi','origin','target','up','rigOrigin');
        
        clear oi
        
        % Delete the .dat file if it exists (to avoid running out of local
        % storage space. Since the oi has already been saved, the .dat file is
        % redundant at this point.
        [p,n,e] = fileparts(recipe.outputFile);
        datFile = fullfile(p,'renderings',strcat(n,'.dat'));
        if(exist(datFile,'file'))
            delete(datFile);
        end
        datFileDepth = fullfile(p,'renderings',strcat(n,'_depth.dat'));
        if(exist(datFileDepth,'file'))
            delete(datFileDepth)
        end
        
    end
    
end

%% Render in gCloud (if applicable)

if(gcloudFlag)
    
    % Upload all recipes to gCloud
    % Note: We have to do the upload here because we want to wait until all
    % pbrt files have been written out before we start uploading. This way
    % all the data needed to render all pbrt files is ready in the working
    % folder.(gCloud.upload only zips the working directory up once!)
    for ii = 1:length(allRecipes)
        gCloud.upload(allRecipes{ii});
    end
    
    gCloud.render();
    
    % Save the gCloud object in case MATLAB closes
    save(fullfile(workingDir,'gCloudBackup.mat'),'gCloud');
    
    % Pause for user input (wait until gCloud job is done)
    x = 'N';
    while(~strcmp(x,'Y'))
        x = input('Did the gCloud render finish yet? (Y/N)','s');
    end
    
    objects = gCloud.download();
    
    for ii = 1:length(objects)
        
        oi = objects{ii};
        
        % "Fix" name. (OI name now includes date, but we want to use the
        % "camX" name when saving)
        oiName = oiGet(oi,'name');
        C = strsplit(oiName,'-');
        oiName = C{1};
        oiFilename = fullfile(saveDir,strcat(oiName,'.mat'));
        
        % Load up rig info
        % Match "camX" name with the ones recorded in the rigInfo cell matrix.
        for jj = 1:size(rigInfo,1)
            if(strcmp(oiName,rigInfo{jj,1}))
                origin = rigInfo{jj,2};
                target = rigInfo{jj,3};
                up = rigInfo{jj,4};
                rigOrigin = rigInfo{jj,5};
                break;
            end
        end
        
        save(oiFilename,'oi','origin','target','up','rigOrigin');
        fprintf('Saved oi at %s \n',oiFilename);
        
    end
    
    
end