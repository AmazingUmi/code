function [] = SourceBeam(BeamWidth,theta,DI,envfil)
%UNTITLED6 此处显示有关此函数的摘要
%   此处显示详细说明
bw0=0;         % 最初指向性主瓣宽度 (最大值的一半所在角度）
bw00=bw0+0;        % 主瓣最近的极小值点所在角度(零点宽度)
for ibw=1:length(BeamWidth)
    if ibw==length(BeamWidth)
        theta_int = theta;
        DI_int = interp1(theta,ones(1,length(theta)),theta,'spline');
        % % 绘图
        % figure;
        % polarplot(theta_int/180*pi, DI_int);
        % set(gca,'ThetaDir','clockwise');
        % rticks([0:0.2:1]);
        % thetaticks([0:30:360]);
        % title('无指向性');
    else
        bw=BeamWidth(ibw);  % 主瓣宽度
        if bw>=bw0
            ibwL = find(abs(theta)<=bw);             
            ibwH = find(abs(theta-180)<=bw);
            percent=bw/bw0;                         % 缩放因子
            theta1=-bw:bw;                               % 缩放后角度
            theta0=linspace(-bw0,bw0,length(theta1));    % 缩放前角度
            DI1 = interp1(theta,DI,theta0,'spline');     % 插值得到缩放后指向性
            theta2 = 180-bw:180+bw;
            theta0=linspace(180-bw0,180+bw0,length(theta2));
            DI2 = interp1(theta,DI,theta0,'spline');

            theta_int= [theta(1:ibwL(1)-1),theta1,theta(ibwL(end)+1:ibwH(1)-1),theta2,theta(ibwH(end)+1:end)];  % 插值后的角度向量
            DI_int = [DI(1:ibwL(1)-1),DI1,DI(ibwL(end)+1:ibwH(1)-1),DI2,DI(ibwH(end)+1:end)] ;                  % 插值后的指向性
        
        else
            percent=bw/bw0;                         % 缩放因子
            bw00_=bw00*percent;                     % 主瓣零点缩小后开角大小
            ibwL1 = find(abs(theta)<=bw00);             
            ibwH1 = find(abs(theta-180)<=bw00);
            ibwL = find(abs(theta)<=bw00_);             
            ibwH = find(abs(theta-180)<=bw00_);
            
            theta1=-bw00_:bw00_;                    % 缩小后角度
            theta0=linspace(-bw00,bw00,length(theta1));
            DI1=interp1(theta,DI,theta0,'spline');  % 缩小后指向性
            theta2 = 180-bw00_:180+bw00_;
            theta0=linspace(180-bw00,180+bw00,length(theta2));
            DI2 = interp1(theta,DI,theta0,'spline');
            
            DI0=DI;
            DI0(ibwL1(1):ibwL(1)-1)=DI0(ibwL1(1));
            DI0(ibwL(end)+1:ibwL1(end))=DI0(ibwL1(end));
            DI0(ibwH1(1):ibwH(1)-1)=DI0(ibwH1(1));
            DI0(ibwH(end)+1:ibwH1(end))=DI0(ibwH1(end));
            theta_int= [theta(1:ibwL(1)-1),theta1,theta(ibwL(end)+1:ibwH(1)-1),theta2,theta(ibwH(end)+1:end)];  % 插值后的角度向量
            DI_int = [DI0(1:ibwL(1)-1),DI1,DI0(ibwL(end)+1:ibwH(1)-1),DI2,DI0(ibwH(end)+1:end)] ;                  % 插值后的指向性
            
        end
        % % 绘图
        % figure;
        % polarplot(theta_int/180*pi, DI_int);
        % set(gca,'ThetaDir','clockwise');
        % rticks([0:0.1:1]);
        % thetaticks([0:30:360]);
        % title(['bw=',num2str(bw),'\circ']);
    end
    DI_int=20*log10(DI_int);

    write_sbp(envfil, theta_int, DI_int );  % 写入指向性指数
end

end