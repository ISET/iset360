function [] = plotRig(from,to,up,index)
%PLOTRIG Given a series of camera LookAt's (from, to, and up) make a plot
%of their locations and label each camera with the given index vector.

nCameras = size(from,1);

if(size(to,1) ~= nCameras || ...
        size(up,1) ~= nCameras || ...
        length(index) ~= nCameras)
    error('Input vector lengths do not match.')
end

figure;
hold on; grid on;
axis image;

% For plotting, we flip the axes for easier viewing.
% Z --> Y
% Y --> Z
% X --> X
xlabel('x (m)')
ylabel('z (m)')
zlabel('y (m)');
title('Camera Positions');

% Normalize arrow size
forward = to-from;
for i = 1:nCameras
    forward(i,:) = forward(i,:)./norm(forward(i,:));
    up(i,:) = up(i,:)./norm(up(i,:));
end
forward = forward.*(10^-1);
up = up.*(10^-1);

for i = 1:nCameras

% Plot forward vector
h2 = quiver3(from(i,1),from(i,3),from(i,2), ...
    forward(i,1),forward(i,3),forward(i,2),'r', ...
    'MaxHeadSize',3,'AutoScale','off');

% Plot up vector
h3 = quiver3(from(i,1),from(i,3),from(i,2), ...
    up(i,1),up(i,3),up(i,2),'g', ...
    'MaxHeadSize',3,'AutoScale','off');

% Plot origins
h1 = scatter3(from(i,1),from(i,3),from(i,2),80,...
        'x',...
        'MarkerEdgeColor','b',...
        'MarkerFaceColor','b');

% Draw fulstrum
% right = cross(forward(i,:),up(i,:));
% s = 0.25;
% TR = to(i,:) + s.*(right + up);
% BR = to(i,:) + s.*(right - up);
% TR = to(i,:) + s.*(right);
% BR = to(i,:) + s.*(right);
% TL = to(i,:) + s.*(-right + up);
% BL = to(i,:) + s.*(-right - up);
% scatter3(TR(1),TR(2),TR(3));
% scatter3(BR(1),BR(2),BR(3));
% scatter(TL(1),TL(2),TL(3));
% scatter(BL(1),BL(2),BL(3));

% Plot indices
    x = from(i,1)+0.015;
    y = from(i,2)+0.0;
    z = from(i,3)+0.015;
    text(x,z,y,num2str(index(i)));    
end

legend([h1 h2 h3],'Origin', ...
    'Forward Vector','Up Vector','location','best')

% Adjust text size
view(170,25);
set(findall(gcf,'-property','FontSize'),'FontSize',18)
set(findall(gcf,'-property','LineWidth'),'LineWidth',2)
end

