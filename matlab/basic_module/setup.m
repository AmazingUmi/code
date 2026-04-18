clear; close all; clc;
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
addpath(pathstr);
addpath(fullfile(pathstr, 'function'));
clear tmp index;