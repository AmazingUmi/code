function tlt = output_shd( varargin )

% plot a single TL surface in dB
% usage:
% plotshd( filename, m, n, p )
% (m, n, p) optional subplot spec
% '.shd' is the default file extension if not specified
%
% plotshd( filename, freq ) to plot field for a specified frequency
% plotshd( filename, freq, m, n, p ) to plot field for a specified frequency
% mbp

global units jkpsflag

% read

%disp( 'PlotShd uses the first frequency, bearing, and source depth in the shade file; check OK' )
itheta = 1;   % select the index of the receiver bearing
isz    = 1;   % select the index of the source depth
filename = varargin{ 1 };

switch nargin
   case 1   % straight call
      [ PlotTitle, ~, freqVec, ~, ~, Pos, pressure ] = read_shd( filename );
      freq = freqVec( 1 );
   case 2   % a frequency has been selected
      freq = varargin{ 2 };
      [ PlotTitle, ~, freqVec, ~, ~, Pos, pressure ] = read_shd( filename, freq );
   case 4   % a subplot m n p has been selected
      m = varargin{ 2 };
      n = varargin{ 3 };
      p = varargin{ 4 };      
      [ PlotTitle, ~, freqVec, ~, ~, Pos, pressure ] = read_shd( filename );
      freq = freqVec( 1 );
   case 5   % a frequency and a subplot m n p has been selected
      freq = varargin{ 2 };
      m    = varargin{ 3 };
      n    = varargin{ 4 };
      p    = varargin{ 5 };      
      [ PlotTitle, ~, freqVec, ~, ~, Pos, pressure ] = read_shd( filename, freq );
end

pressure = squeeze( pressure( itheta, isz, :, : ) );
zt       = Pos.r.z;
rt       = Pos.r.r;

% set labels in m or km
xlab     = 'Range (m)';
if ( strcmp( units, 'km' ) )
   rt      = rt / 1000.0;
   xlab    = 'Range (km)';
end

if ( nargin == 1 || nargin == 2 )
   %figure
else
   if ( p == 1 )
      %figure( 'units', 'normalized', 'outerposition', [ 0 0 1 1 ] ); % first subplot
      figure
   else
      hold on   % not first subplot
   end
   subplot( m, n, p )
end
%%

% calculate caxis limits

% SPARC runs are snapshots over time; usually want to plot the snapshot not TL
if ( length( PlotTitle ) >= 5 && strcmp( PlotTitle( 1 : 5 ), 'SPARC' ) )
   tlt = real( pressure );
   tlt = 1e6 * tlt;   % pcolor routine has problems when the values are too low
   
   %tlt( :, 1 ) = zeros( nrd, 1 );   % zero out first column for SPARC run
   tlmax = max( max( abs( tlt ) ) );
   tlmax = 0.4 * max( tlmax, 0.000001 );
   %tlmax = tlmax / 10;
   %tlmax = 0.02 / i;
   tlmin = -tlmax;
else
   tlt = double( abs( pressure ) );   % pcolor needs 'double' because field.m produces a single precision
   tlt( isnan( tlt ) ) = 1e-6;   % remove NaNs
   tlt( isinf( tlt ) ) = 1e-6;   % remove infinities
   
   icount = find( tlt > 1e-37 );        % for stats, only these values count
   tlt( tlt < 1e-37 ) = 1e-37;          % remove zeros
   tlt = -20.0 * log10( tlt );          % so there's no error when we take the log
   % compute some statistics to automatically set the color bar
   
   tlmed = median( tlt( icount ) );    % median value
   tlstd = std( tlt( icount ) );       % standard deviation
   tlmax = tlmed + 0.75 * tlstd;       % max for colorbar
   tlmax = 10 * round( tlmax / 10 );   % make sure the limits are round numbers
   tlmin = tlmax - 50;                 % min for colorbar
end
