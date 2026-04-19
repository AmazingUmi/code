function bellhop( filename )

% run the BELLHOP program
%
% usage: bellhop( filename )
% where filename is the environmental file

runbellhop = which( 'bellhop.exe' );
if isempty( runbellhop )
   runbellhop = which( 'bellhop' );
end

if ( isempty( runbellhop ) )
   error( 'bellhop executable not found in your Matlab path' )
else
   status = system( sprintf( '"%s" "%s"', runbellhop, filename ) );
   if status ~= 0
      error( 'bellhop execution failed with status %d', status )
   end
end
