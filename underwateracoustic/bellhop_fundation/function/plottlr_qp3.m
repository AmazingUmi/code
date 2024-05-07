function plottlr_qp3(filename, rdt, mkl)
% plot a single TL slice from the shade file
%
% usage:
% plottlr( filename, rdt )
% where
%   filename is the shadefile (with extension)
%   rdt is the receiver depth in m
%   if rdt is a vector then one plot is generated for each element
% mbp

global units

disp( 'PlotTLr uses the first bearing and source depth in the shade file; check OK' )
itheta = 1;
isd    = 1;

% read

[ PlotTitle, ~, freq, ~, ~, Pos, pressure ] = read_shd( filename );
rkm = Pos.r.r / 1000.0;         % convert to km

pressure = pressure( itheta, isd, :, : );

tlt = abs( pressure );	            % this is really the negative of TL
tlt( tlt == 0 ) = max( max( tlt ) ) / 1e10;      % replaces zero by a small number
tlt = -20.0 * log10( tlt );          % so there's no error when we take the log

range = Pos.r.r;
tlslice = zeros(1,length(range));
for k = 1:length(range)
    irz = (Pos.r.z >= (rdt-50)) & (Pos.r.z <= (rdt+50));
    irr = (Pos.r.r >= (range(k)-500)) & (Pos.r.r <= (range(k)+500));
    %     irz = (Pos.r.z == (rd)) ;
    %     irr = (Pos.r.r == (1000*range(k))) ;
    I = abs(squeeze(pressure(1,1,irz,irr))).^2;
    tlslice(k) = -10*log10(mean(I(:)));
end


hh = plot( rkm, tlslice', mkl );

set( gca, 'YDir', 'Reverse' )   % because view messes up the zoom feature
xlabel( 'Range (km)' )
ylabel( 'TL (dB)' )
title( { deblank( PlotTitle ); [ 'Freq = ' num2str( freq ) ' Hz    Sz = ' num2str( Pos.s.z( isd ) ) ' m' ] } )

set( hh, 'LineWidth', 2 )

% generate legend
for ird = 1: length( rdt )
    legendstr( ird, : ) = [ 'Rz = ', num2str( rdt( ird ) ), ' m' ];
end

legend( legendstr, 'Location', 'Best' )
legend( 'boxoff' )
drawnow

% %figure; plot( rkm, abs( interp1( Pos.r.depth, squeeze( pressure ), rdt ) ) );
