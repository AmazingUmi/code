function PlusAcouFields3(filename_all, ave_type)

pressure = 0;
for ifile = 1: length(filename_all)
    filename = filename_all{ifile};
    [ PlotTitle, PlotType, freqVec, freq0, atten, Pos, pressure1 ] = ...
        read_shd( [filename '.shd'], 0 );
    if contains(filename,'km_1')
        if ave_type == 'C'
            pressure = (pressure) + (pressure1);
        else
            pressure = abs(pressure) + abs(pressure1);
        end
    elseif contains(filename,'km_2')
        if ave_type == 'C'
            pressure = (pressure) + 0.707*(pressure1);
        else
            pressure = abs(pressure) + 0.707*abs(pressure1);
        end
    end
end
% pressure = pressure/ length(filename_all);
shdfil = [ filename_all{end} '.shd.mat' ];   % output file name (pressure)
save( shdfil, 'PlotTitle', 'PlotType', 'freqVec', 'freq0', 'atten', 'Pos', 'pressure' )
end