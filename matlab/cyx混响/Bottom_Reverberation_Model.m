for start=1:1;
    %continue
    %由于只需要使用BELLHOP计算一次声场，在计算相同深度不同距离时，使用continue跳过
    bellhop MunkB_ray_SY                                                   % S 200m;  R 3472m
    bellhop MunkB_rayB_SY                                                  % S 3472m; R 205m
    bellhop MunkB_l_r_SY                                                   % S 200m;  R 205m
    [ Arr2, Pos ] = read_arrivals_asc( 'MunkB_ray_SY.arr',40 ); %#ok<NASGU>% usage:[ Arr, Pos ] = read_arrivals_asc( ARRFIL, Narrmx );
    [ Brr2, Pos ] = read_arrivals_asc( 'MunkB_rayB_SY.arr',40 );           % Arr是一个结构体，包含所有到达信号数据
    [ RArr2, Pos ] = read_arrivals_asc( 'MunkB_l_r_SY.arr',40 );           % Pos是一个结构体，包含声源和接收器位置
end                                                                        % 但有一个问题 ： 声源强度在哪体现 ？？？
%设定变量
n=0;                                                                       % 散射体数量
MS=0;
itg=200;                                                                   % 脉冲宽度 τ 单位毫秒
Arr2.A(1,1:20)=1;                                                          % 设置20 arrivals的振幅初始值，5001个接收range，1相当于趋近声源的位置
Arr2.delay(1,1:20)=0.0001;                                                 % 设置20 arrivals的计时器 t 初始值，相当于脉冲结束后t时刻     
Brr2.A(1,1:20)=1;                                                          % 20是因为.arr文件里最多就只有20个arrival
Brr2.delay(1,1:20)=0.0001;                                                 % 注意 A是脉冲响应的振幅

Sscatter=0;                                                                % 是否算散射影像图（1或0）
tic                                                                        % 启动秒表计时器   tic  ...  toc：计算运行时间
for loop=3:3 %选定收发距离
    R=[1 762 3194 5000 10034 7745 5454 14610 1000];                        % 设定收发距离
    Rec=R(loop);                                                           % 接收器的水平距离，（loop=3:1:3,只有一个接收器，range=3194）
    v=0.1;                                                                 % 海底谱强度
    tht=pi/18;                                                             % 为大尺度海底的均方根斜角
    miu=10^(-(32/10));                                                     % Lambert散射参数 μ
    nn=1 ;                                                                 % Lambert散射参数
    %S=100*100;                                                            % 散射面积
    X=50000;                                                               % X计算的最远距离    
    Y=50000;                                                               % Y计算的最远距离
    i=30;                                                                  % 边长渐变精度参数a= 1/30 = 1/i ,越大精度越大
    iplus=100;                                                             % 最小边长精度参数b= 1/100 ,越小精度越大
    pp1(1:60001)=0;                                                        % 600001个时间点(显示时间轴为60s)，但不是每个点pp1都有幅值
    pp2(1:60001)=0;
    origin=-50000;                                                         % 设置x计算起始点
    x=origin;                                                              
    long=1;

    while x<=X
        x;
        y=0;
        breadth=1;
        while  y<=Y;
            [DT0_1,DT1_R,~,CosFi] = TriAngle(0,0,x,y,Rec,0);               % TriAngle计算得到三点构成的三角形的边长和余弦值
            %CosFi=-1;                                                     % 三个点为: 声源投影点 A(0,0), 计算点 B(x,y), 水听器投影点 C(Rec,0)
            if     (DT0_1+DT1_R)>(80000)                                   % 去除过远的路径
                % y=Y;
                break
                %elseif >(Y+1);%去除过远的路径
                %    continue
            else
                S=breadth*long;                                            % S 散射截面  
                %figure (9)
                %plot(x,y,'.')
                %hold on
                %continue
                for n1=1:39                                                % 循环出射 传播方式
                    for n2=1:39                                            % 循环反射传播方式
                        A1 = Arr2.A(DT0_1,n1);                             % 出射传播损失声压  
                        A2 = Brr2.A(DT1_R,n2);                             % 反射传播损失声压
                        delay1=round(Arr2.delay(DT0_1,n1)*1000);           % 出射传播时间。注意*1000是为了pp(delay1+delay2+t)的单位为整数
                        delay2=round(Brr2.delay(DT1_R,n2)*1000);           % 反射传播时间
                        if     Arr2.delay(DT0_1,n1)==0                     % 去除时间为零或过长的声线
                            continue
                        elseif Brr2.delay(DT1_R,n2)==0
                            continue
                        elseif Arr2.RcvrAngle(DT0_1,n1)==0
                            continue
                        elseif Brr2.SrcAngle(DT1_R,n2)==0
                            continue
                        elseif Brr2.delay(DT1_R,n2)+Arr2.delay(DT0_1,n1)>=50  %时间过长的声线
                            continue
                        else
                            [ms1]= Scatter3DL(abs(Arr2.RcvrAngle(DT0_1,n1)),abs(Brr2.SrcAngle(DT1_R,n2)),CosFi,tht,miu,nn,v);
                                                                           % [ms] = Scatter3DL(r,c,CosFi,tht,miu,nn,v)
                                                                           % 采用Lambert散射定律计算海底散射强度Sb，Sb=μ·sinθi·sinθr
                                                                           % 但其实计算的是海底镜反射方向的散射强度 ？？？
                            [ms2]= Scatter3DR(abs(Arr2.RcvrAngle(DT0_1,n1)),abs(Brr2.SrcAngle(DT1_R,n2)),CosFi,tht,miu,nn,v);
                                                                           % 基于Kirchhoff近似 的表面散射函数修正项
                                                                           % 镜反射方向有强散射
                                                                           % ms2 = (1+∆Ω)^2×exp-(∆Ω/2σ^2)
                                                                           % S(θ,θ',φ') = ms1+v*ms2 = μsinθsinθ'+ν*(1+∆Ω)^2×exp-(∆Ω/2σ^2)
                                                                           % 这里没有 v，在最后计算声强的时候补乘了v
                            %[ms2]=0;
                            for t=1:itg                                    % 脉冲串上每个信号单元产生的散射强度
                                                                           % 这段回顾一下散射的推导过程
                                                                           % 关于脉冲长度 τ
                                %s=1552/(cos(ray_rcvrangle.ray_rcvrangle(R,n1))+cos(ray_rcvrangle.ray_rcvrangle(R,n2)));
                                %pp(delay1+delay2+t) = (pi*(((R-2)).^2) - pi*((R).^2))' .*(abs(A1)^2*abs(A2)^2*round(exp(1i*(t+500*2*pi*(delay1+delay2))/100)))^2*10.^(S_b/10)*s+pp(delay1+delay2+t);
                                pp1(delay1+delay2+t) = abs((abs(A1)^2*abs(A2)^2))*ms1*S*2+pp1(delay1+delay2+t);
                                                                           % 每一条射线 在接收器位置产生的声强叠加
                                                                           % 注意：计算结果*2  
                                                                           % 网格划分时只考虑第一、二象限(y>0)的散射体，计算结果做双倍处理得到海底的混响强度
                                pp2(delay1+delay2+t) = abs((abs(A1)^2*abs(A2)^2))*ms2*S*2+pp2(delay1+delay2+t);
                            end
                        end
                    end
                end
            end
            breadth=round(abs(y+x-Rec/2)/i+iplus);                         % 对(x·a+b)以及[(x+y)·a+b]进行取整,作为面元的长和宽 [假设声源与水听器投影的中点在原点]
            y=round(y+abs(y+x-Rec/2)/i+iplus);                             % 但在本程序中，声源位于原点
                                                                           % 故 面元的长和宽变为[(x-Rec/2)·a+b]以及[(x-Rec/2+y)·a+b]
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %用于画出不同散射体对 某一时刻 的影响                             % 为什么是pp2项 
            if Sscatter==1                                                 % pp2与粗糙度有关，即与散射体有关（个人猜测
                n=n+1;
                for scatterT=1:10                                          % 某一时刻的散射体影响
                    MS(scatterT,1,n)=x;
                    MS(scatterT,2,n)=y;
                    MS(scatterT,3,n)=10*log10((abs(pp2(5000+(scatterT-1)*1000))));
                    % pp2(5000+(scatterT-1)*1000)=0;                         % 为什么要置 0 ？？？
                end
            end
            % delay
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        long=round(abs(x-Rec/2)/i+iplus);
        x=round(x+abs(x-Rec/2)/i+iplus);
    end
    %hold off
    pr=0;
    pr(1:60001)=0;
    % 这部分是直达声
    for s=1:39
        %continue
        for t=1:200
            pr(round(RArr2.delay(Rec,s)*1000)+t)=abs(RArr2.A(Rec,s)^2)+pr(round(RArr2.delay(Rec,s)*1000)+t);
        end
    end
    
    figure (loop)
    lpp3(loop,:)=pp1;
    lpp4(loop,:)=pp2;
    lpr(loop,:)=pr;
    yREV=10*log10((abs(pp1+v*pp2+pr)));                                    % 直达声以及后续各项散射波的叠加
    plot(0:0.001:60,yREV);
    %axis([-1,50,-150,-60])
    hold off
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %画散射体影响图


    if Sscatter==1
        for scatterT=1:10
            figure(10+scatterT);
            %subplot(5,5,scatterT)
            % scatter(MS(scatterT,1,:),MS(scatterT,2,:),10,MS(scatterT,3,:),'filled');
            scatter(squeeze(MS(scatterT,1,:)),squeeze(MS(scatterT,2,:)),10,squeeze(MS(scatterT,3,:)),'filled');
            axis([-9000,14000,0,14000]);
            caxis([-350,-135]);
            colorbar;
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
toc

