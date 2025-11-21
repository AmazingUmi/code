function [ms]= Scatter3DR(r,c,CosFi,tht,miu,nn,v)
dertOmg=(cosd(r)^2+cosd(c)^2-2*cosd(r)*cosd(c)*CosFi)/((sind(r)+sind(c))^2);
% ∆Ω=((cosθ)^2+(cosθ)^2-2cosθcosθ'cosφ')/(sinθ+sinθ')^2
ms=((1+dertOmg)^2)*exp(-dertOmg/(2*(tht^2)));
% S(θ,θ',φ')=μsinθsinθ'+ν(1+∆Ω)^2×exp-(∆Ω/2σ^2)
% 其中，σ为海底的均方根斜率 （rms slope）
%ms=miu*((sind(r)*sind(c))^nn);%
%ms=v*((1+dertOmg)^2)*exp(-dertOmg/(2*(tht^2)))-v;