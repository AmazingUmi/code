function write_ssp(filename, rkm, SSP)
%% 将区间内的声速剖面集合写入.ssp文件
% filename: .ssp文件名
% rkm:      距离向量
% SSP:      不同距离上的声速剖面集合

% 按正负的最大距离设置
if abs(rkm(1)) < rkm(end)
    rkm = [-rkm(end),rkm];
    SSP = [SSP(:,1),SSP];
elseif abs(rkm(1)) > rkm(end)
    rkm = [rkm, abs(rkm(1))];
    SSP = [SSP,SSP(:,end)];
end

% % 稍微扩大ssp的范围，以保证它包含Box的范围
 rkm(end) = rkm(end) + 3;
% rkm(1) = rkm(1) - 1;

Npts = length( rkm );
fid = fopen( [filename,'.ssp'], 'wt' );
fprintf( fid, '%i\n', Npts );   
fprintf( fid, '%6.3f ', rkm );
fprintf( fid, '\n' );

for ii = 1 : size( SSP, 1 )
   fprintf( fid, '%6.1f ', SSP( ii, : ) );  % 写入声速剖面
   fprintf( fid, '\n' );
end

fclose( fid );