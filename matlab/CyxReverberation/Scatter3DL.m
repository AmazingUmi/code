function [ms]= Scatter3DL(r,c,CosFi,tht,miu,nn,v)
%dertOmg=(cosd(r)^2+cosd(c)^2-2*cosd(r)*cosd(c)*CosFi)/((sind(r)+sind(c))^2);
ms=abs(miu*((sind(r)*sind(c))^nn));
%ms=miu*((sind(r)*sind(c))^nn);%
%ms=v*((1+dertOmg)^2)*exp(-dertOmg/(2*(tht^2)))-v;