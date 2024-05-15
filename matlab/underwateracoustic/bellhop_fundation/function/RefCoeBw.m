function result_R = RefCoeBw(base_type, envfil, freqvec, ssp_end, alpha_b)
%  REFCOE 根据海底参数计算反射系数。
%
% 此函数的详细说明。
result_R1 = 0;
for ifreq = 1: length(freqvec)
    f = freqvec(ifreq);
    switch base_type

        case 'IMG'
            speed = [ssp_end 1500];
            layer_depth = [0 1 ];
            rho_D = [1 1 ];
        case 'D05'
            speed = [ssp_end,1542.05,1502.70,1500.39,1499.09,1492.67,1489.81,1495.51,1569.88,1580.84,1583.34];
            % 实测声速
            layer_depth = [0,0.462,0.954,1.453,1.945,2.443,2.91,3.406,3.898,4.395,4.895];
            % 介质深度（0m对应的是海水最后一层）
            rho_D = [1,1.51,1.36,1.37,1.35,1.38,1.37,1.38,1.50,1.45,1.40];
            % 介质密度
            alpha_p = [0 alpha_b * ones(1, length(rho_D)-1)];
            % 介质系数系数，这里直接用的0.05 dB/lambda
        case 'D40'
            speed = [ssp_end 1568.69 1664.50 1591.08 1569.42 1587 1562.01];
            layer_depth = [0 0.467 0.967 1.462 1.958 2.463 3.268];
            rho_D = [1 1.52 1.72 1.63 1.58 1.60 1.57];
            alpha_p = [0 alpha_b * zeors(1, length(rho_D)-1)];
        case 'SCS-4'
            speed = [ssp_end 1609.87 1591.64 1589.51 1552.50];
            layer_depth = [0 0.468 0.962 1.465 2.158];
            rho_D = [1 1.69 1.64 1.61 1.51];
            alpha_p = [0 alpha_b * zeors(1, length(rho_D)-1)];
    end
    angle_graze = 0:90;
    angle_graze_end = (acosd(speed(end)/speed(1)*cosd(angle_graze)));
    angle_graze_end_1 = (acosd(speed(end-1)/speed(1)*cosd(angle_graze)));
    Z_end = speed(end)*rho_D(end)./sind(angle_graze_end);
    Z_end_1 = speed(end-1)*rho_D(end-1)./sind(angle_graze_end_1);
    angle_graze_temp = angle_graze_end_1;
    Z_temp = Z_end_1;
    R_temp = (Z_end-Z_end_1)./(Z_end+Z_end_1);

    for ii = 2:length(speed)-1
        angle_graze_up = (acosd(speed(end-ii)/speed(1)*cosd(angle_graze)));
        Z_up = speed(end-ii)*rho_D(end-ii)./sind(angle_graze_up);
        R_up = (Z_temp-Z_up)./(Z_temp+Z_up);
        phi = 2*pi*f/speed(end-ii+1)*(layer_depth(end-ii+1)-layer_depth(end-ii))...
            *sind(angle_graze_temp);
        R_temp = (R_up+R_temp.*exp(2*1j*phi))./(1+R_up.*R_temp.*exp(2*1j*phi));
        Z_temp = Z_up;
        angle_graze_temp = angle_graze_up;
    end
    % plot(angle_graze,-20*log10(abs(R_temp)))
    % hold on
    angle_graze_2 = (acosd(speed(2)/speed(1)*cosd(angle_graze)));
    Z_1 = speed(1)*rho_D(1)./sind(angle_graze);
    Z_2 = speed(2)*rho_D(2)./sind(angle_graze_2);
    R_simple = (Z_2-Z_1)./(Z_2+Z_1);
    % plot(angle_graze,-20*log10(abs(R_simple)))
    R_halfspace = R_simple;
    R_multilayer = R_temp;


    R_multilayer(isnan(R_multilayer)) = 1;
    result_R1 = result_R1 + abs(R_multilayer);
    % angle_R = angle(R_multilayer)/pi*180;

end
result_R = zeros(length(R_halfspace),3);
result_R(:,1) = angle_graze;
result_R(:,2) = result_R1/ length(freqvec);
result_R(:,3) = 0;
fid = fopen([envfil '.brc'], 'wt+');
fprintf(fid, '%d \n', length(R_halfspace));
fprintf(fid, '%6.2f  %6.2f  %6.2f\n', result_R.');
fclose(fid);


end