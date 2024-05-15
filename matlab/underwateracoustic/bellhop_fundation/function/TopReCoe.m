function result_R = TopReCoe(freqvec,c_surface,sea_state_level, out_filname)
%UNTITLED 此处提供此函数的摘要
%   此处提供详细说明
wave_height = [0 .1 .5 1.25 2.5 4 6 9 14];
sigma = wave_height(sea_state_level+1) * .707;

theta = 0:90;
Re_mean = 0;
for ifreq = 1: length(freqvec)
    k = 2* pi* freqvec(ifreq) / c_surface;
    tau = 2 * k * sigma * sind(theta);
    Re_top = - exp(-.5* tau.^2);
    Re_mean = Re_mean + abs(Re_top);
end
Re_mean = Re_mean / length(freqvec);
result_R = zeros(length(theta), 3);
result_R(:,1) = theta;
result_R(:,2) = abs(Re_mean);
result_R(:,3) = 180;
fid = fopen([out_filname '.trc'], 'wt+');
fprintf(fid, '%d \n', length(result_R));
fprintf(fid, '%6.2f  %6.2f  %6.2f\n', result_R.');
fclose(fid);
end