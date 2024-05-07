function [] = write_altimetry(lambda,height,rmax,ri,envfil)
%UNTITLED8 此处显示有关此函数的摘要
%   此处显示详细
w = 2*pi/lambda;
x = 0:ri:rmax;
y = height * (1 + sin(w*x*1000));
fid = fopen([envfil, '.ati'], 'wt+');
fprintf(fid, "'C' \n");
fprintf(fid, '%d \n', length(y));
fprintf(fid, '%6.4f  %6.4f \n',[x ; y] );
fclose(fid);



end