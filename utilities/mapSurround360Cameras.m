function [from, to, up, camI] = mapSurround360Cameras(numCamerasCircum,radius)
%MAPSURROUND360CAMERAS Outputs and plots "LookAt's" for cameras arranged
%around a ring, as in the Surround360 rig.
% We follow Facebook's numbering convention:
% Camera 0 is the camera facing up.
% Cameras 1:numCircum are the ones around the ring.
% Camera numCircum+1 and numCircum+2 are the cameras facing down.
%
% Note the final output coordinate system assumes that the y-axis points up
% (i.e. toward the ceiling) while the x/z axes create the horizontal plane
% (i.e. the floor). This is consistent with Benedikt Bitterli's
% conventions. See "Flip Coordinates"  section below.  
%
% Inputs:
%   numCamerasCircum = number of cameras to place around the horizontal
%       ring
%   whichCameras = which cameras to return (might not need this)
%   radius = radius of the rig, in millimeters
%
% TLian, SCIEN Stanford, 2018

%% Set up the camera locations around the circumference

angleIncrement = 360/numCamerasCircum;
basePlateHeight = 0; % Fixed at zero. We can adjust the base plate height by physically adjusting all camera heights in the main script. 

horizCameraLocations = zeros(numCamerasCircum,3); % [x,y,z]
horizLookDir = zeros(numCamerasCircum,3);
currAngle = 0;
for i = 1:numCamerasCircum
    currAngle = currAngle - angleIncrement;
    horizCameraLocations(i,:) = [radius.*[cosd(currAngle) sind(currAngle)] basePlateHeight];
    horizLookDir(i,:) = [(radius*2).*[cosd(currAngle) sind(currAngle)] basePlateHeight];
end

%% Set up the locations of top and bottom cameras
% Note: Point grey camera module is around 50 mm tall, so we factor that in
% as well.
% Second bottom camera is 3.375 inches == 85.73 off the center

vertCameraLocations = [0 0 basePlateHeight+50;
    0 0 basePlateHeight-50;
    85.73 0 basePlateHeight-50];
vertLookDir= vertCameraLocations +[0 0 100;
    0 0 -100;
    0 0 -100];

%% Combine all cameras into a single vector.
% The indexing must correspond to the indexing given in the Facebook 360
% manual (see Section 3)

horizForward = horizLookDir - horizCameraLocations;

locationsAll = [vertCameraLocations(1,:); horizCameraLocations; vertCameraLocations(2:3,:)];
targetsAll = [vertLookDir(1,:); horizLookDir; vertLookDir(2:3,:)];

% We match the up direction of the top/bottom cameras with the lookAt of
% the first camera. Not strictly necessary, but it might make rotating the
% top and bottom views easier.
forwardLength = sqrt(sum(horizForward.^2,2));
upAll = [horizForward(1,:); repmat([0 0 forwardLength(1)],[numCamerasCircum 1]); ...
    [horizForward(1,:); horizForward(1,:)] ];

% Add camera ID's
camIAll= (1:(numCamerasCircum+3)) - 1;

%% Flip coordinates
% Note on coordinate flips:
% There are some conventions on how we define coordinates in a scene. The
% scenes from Benedikt Bitterli have "y" being up, i.e. toward the ceiling
% and "x/y" being the horizontal plane, i.e. the floor. Our convention in
% the past and in mapSurround360Cameras has been "z" being up and "y/x"
% being the horizontal plane. To account for this discrepancy, we switch
% the coordinates here.
%
% mapSurround Y == bitterli Z
% mapSurround Z == bitterli Y
% mapSurround X == bitterli X

locationsAll = [locationsAll(:,1) locationsAll(:,3) locationsAll(:,2)];
targetsAll = [targetsAll(:,1) targetsAll(:,3) targetsAll(:,2)];
upAll = [upAll(:,1) upAll(:,3) upAll(:,2)];

%% Convert from millimeters to meters
locationsAll = locationsAll/10^3;
targetsAll = targetsAll/10^3;
upAll = upAll/10^3;

%% Output 
% Only output the cameras we chose to render
from = locationsAll;
to = targetsAll;
up = upAll;
camI = camIAll;

end

