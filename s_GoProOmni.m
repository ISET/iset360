%% s_SamsungGear360
% Simulate (roughly) the Go Pro omni rig. This rig consists of 6 GoPro Hero
% 4 cameras arranged in a cube facing out. The cube has edge length of
% roughly 120 mm. 
%
% TL, Scien Stanford, 2017
%
%% Initialize
ieInit;
if ~piDockerExists, piDockerConfig; end

%% Set parameters

% Rendering parameters
gcloudFlag = 0;
sceneName = 'whiteRoom';
filmResolution = round([2704 2028]./16);
pixelSamples = 128;
bounces = 4;

% Save parameters
workingDir = fullfile(rigRootPath,'local');
if(~exist(workingDir,'dir'))
    mkdir(workingDir);
end

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

%% Set camera locations

spacing = 120e-3; % 120 mm cube
forwardAll = [1 0 0;
              0 1 0;
              0 0 1;
              -1 0 0;
              0 -1 0;
              0 0 -1];
originAll = zeros(6,3) + spacing./2.*forwardAll;
upAll = circshift(forwardAll,[0 2]);
targetAll = originAll + forwardAll; % LookAt needs a "to" parameter

% Let's rotate all points

% Use a point for "up" direction
upTargetAll = originAll+upAll;

% Rotate slightly
theta = 10;
Rx = [1 0 0;
    0 cosd(theta) -sind(theta);
    0 sind(theta) cosd(theta)];
upTargetAll = (Rx*upTargetAll')';
forwardAll = (Rx*forwardAll')';
targetAll = (Rx*targetAll')';

camI = 1:6;
plotRig(originAll,...
    forwardAll, ...
    upAll,...
    camI);

% Shift to rigOrigin;
upTargetAll = upTargetAll + repmat(rigOrigin,[6 1]);
targetAll = targetAll + repmat(rigOrigin,[6 1]);
originAll = originAll + repmat(rigOrigin,[6 1]);

% Recalculate up as a vector instead of a point
upAll = upTargetAll-originAll;


%% Change the camera parameters

recipe.camera = struct('type','Camera','subtype','realistic');

% Focus at roughly meter away.
recipe.camera.focusdistance.value = 1.5; % meter
recipe.camera.focusdistance.type = 'float';

% Change the sampler
recipe.sampler.subtype = 'halton';

% Both lenses are fisheye lens
lensFile = fullfile(rigRootPath,'data','lens','wide.56deg.3.0mm_v3.dat');

recipe.film.diagonal.value = 9; % Try something larger to get a bigger FOV
recipe.film.diagonal.type = 'float';

% Attach the lens
recipe.camera.lensfile.value = lensFile; % mm
recipe.camera.lensfile.type = 'string';

% Set the aperture to be the largest possible.
% PBRT-v3-spectral will automatically scale it down to the largest
% possible aperture for the chosen lens.
recipe.camera.aperturediameter.value = 10; % mm
recipe.camera.aperturediameter.type = 'float';

%% Set render quality
recipe.set('filmresolution',filmResolution);
recipe.set('pixelsamples',pixelSamples);
recipe.integrator.maxdepth.value = bounces;

%% Loop through each camera in the rig and render.

% For gCloud
rigInfo = cell(size(originAll,1),5);
allRecipes = cell(size(originAll,1),1); 

for ii = 1:size(originAll,1)
    
    % Follow Facebook's naming conventions for the cameras
    oiName = sprintf('cam%i',ii);
    
    % Set camera lookAt
    origin = originAll(ii,:);
    target = targetAll(ii,:);
    up = upAll(ii,:);
    
    recipe.set('from',origin);
    recipe.set('to',target);
    recipe.set('up',up);
    
    recipe.set('outputFile',fullfile(workingDir,strcat(oiName,'.pbrt')));
    
    piWrite(recipe);
    
    if(gcloudFlag)
        
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
        
        % Delete the .dat file if it exists (to avoid running out of local storage space)
        [p,n,e] = fileparts(recipe.outputFile);
        datFile = fullfile(p,'renderings',strcat(n,'.dat'));
        if(exist(datFile,'file'))
            delete(datFile);
        end
        datFileDepth = fullfile(p,'renderings',strcat(n,'_depth.dat'));
        if(exist(datFileDepth,'file'))
            delete(datFileDepth);
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
