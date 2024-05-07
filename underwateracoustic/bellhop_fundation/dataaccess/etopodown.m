clc
clear
close all
% 网址
httpsUrl = 'https://www.ngdc.noaa.gov/thredds/catalog/global/ETOPO2022/15s/15s_surface_elev_netcdf/catalog.html';
'https://www.ngdc.noaa.gov/thredds/fileServer/global/ETOPO2022/15s/15s_bed_elev_netcdf/ETOPO_2022_v1_15s_N60W030_bed.nc'

%% 设置
UserAgent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36';
options = weboptions('UserAgent',UserAgent,'Timeout',5);
% 爬取数据
data = webread(httpsUrl,options);
% 读取文件名
pattern = 'ETOPO_2022_v1_15s_.*?nc';
result = regexp(data, pattern, 'match');
% 去除重复的文件名
Delete_Index = 1:2:numel(result);
result(:,Delete_Index) = [];
% 建立保存数据的文件夹
Folder_Name = 'Data_Download';
if exist(Folder_Name, 'dir') ~= 7
    mkdir(Folder_Name);
end
%% 下载
tic
for i = 1:numel(result)
    Download_httpsUrl = [httpsUrl,result{1,i}];
    Name_Save = [Folder_Name,'\',result{1,i}];
    websave(Name_Save,Download_httpsUrl);
    disp([Name_Save,'下载完成'])
    disp(['剩余',mat2str(numel(result)-i),'个文件'])
    disp(['预计完成时间在',mat2str((numel(result)-i)*toc/i/60),'分钟后'])
    disp('…………………………')
end