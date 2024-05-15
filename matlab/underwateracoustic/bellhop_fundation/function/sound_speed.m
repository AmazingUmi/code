function C = sound_speed(Temp, Sal, Depth)
% 使用经典声速经验公式计算声速，ref:COA 1.2节
C = 1449.2 + 4.6*Temp - 0.055*Temp.^2 + 0.00029*Temp.^3 + ...
    (1.34-0.01*Temp).*(Sal-35) + 0.017*Depth;