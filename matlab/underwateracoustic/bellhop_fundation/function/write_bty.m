function write_bty(envfil, interp_type, bathm)
%% 写入海底地形数据
% envfil:  .bty文件名
% interp_type:  插值类型
% bathm.r:  海底地形距离向量
% bathm.d:  海底地形海深向量

fid = fopen( [envfil,'.bty'], 'wt' );
fprintf(fid,'%s\n',interp_type);
N = length(bathm.r);
fprintf(fid,'%d\n',N);
for it = 1:N
    fprintf(fid,'%f %f\n',bathm.r(it), bathm.d(it));
end
fclose(fid);