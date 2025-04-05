function plotssp_bty(r,bathm,SSP)

pcolor(r ,SSP.z ,SSP.c);
shading interp; colormap( jet );
colorbar( 'YDir', 'Reverse' )
set( gca, 'YDir', 'Reverse' )   % because view messes up the zoom feature
xlabel( 'range(km)' );
ylabel( 'Depth (m)' );
hold on
yl = get(gca, 'YLim');
x_patch = [r, fliplr(r)];  
y_patch = [bathm, repmat(yl(2), 1, length(r))];
fill(x_patch, y_patch, [ 0.5 0.3 0.1 ]);