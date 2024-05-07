function write_sbp(envfil, theta, DI )
%%  写入.sbp指向性文件
% envfil:  .sbp文件名
% theta:   指向性方向向量
% DI:      指向性指数
fid = fopen([envfil '.sbp'], 'wt+');
fprintf(fid, '%d \n', length(theta));
fprintf(fid, '%6.2f  %6.2f \n', [theta ; DI ]); % DI单位dB theta DI 行向量
fclose(fid);