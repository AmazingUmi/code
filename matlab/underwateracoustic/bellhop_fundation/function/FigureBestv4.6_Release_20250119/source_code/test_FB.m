close all

% ---------------------------------------------------
figure;
x = 1:0.1:4;
plot(x,x.^2,x,x.^2.2+1,x,x.^2.4+2,x,x.^2.6+3,x,x.^2.8+4);

% ---------------------------------------------------
figure
scatter3(randn(300,1),randn(300,1),randn(300,1))

% ---------------------------------------------------
figure
bar([1 5 6;7 9 2;3 8 4])

% ---------------------------------------------------
figure
x = -1:0.1:1;
y = -1:0.1:1;
[X Y] = meshgrid(x,y);
Z = sin(-X.*Y);
surf(X,Y,Z)

% ---------------------------------------------------
figure
subplot(221)
bar(magic(3))
subplot(222)
plot(magic(4))
subplot(223)
theta = linspace(0,1,500);
x = exp(theta).*sin(100*theta);
y = exp(theta).*cos(100*theta);
s = scatter(x,y);
subplot(224)
x = 2*randn(5000,1) + 5;
histogram(x,'Normalization','pdf')
hold on
y = -5:0.3:15;
mu = 5;
sigma = 2;
x = 2*randn(5000,1) + 8;
histogram(x,'Normalization','pdf')

% ---------------------------------------------------
figure
subplot(3,3,[1 2 4 5])
bar([1 3 4;2 4 2; 3 5 1]);
subplot(3,3,3)
scatter(randn(15,1),randn(15,1))
hold on
scatter(randn(15,1)+2,randn(15,1)+2)
subplot(3,3,6)
x = linspace(1,10,10);
y = sin(x);
errorbar(x,y,rand(1,length(x)))
hold on
errorbar(x+2,y+3,rand(1,length(x)))
set(gca,'XLim',[0 14])
subplot(3,3,[7 8 ])
x = 2*randn(5000,1) + 5;
histogram(x,'Normalization','pdf')
subplot(3,3,9)
x = linspace(1,6,30);
h = stem(x(1:3:end),sin(x(1:3:end)));
set(gca,'XLim',[0 7])

% ---------------------------------------------------
figure
x = 2*randn(5000,1) + 5;
histogram(x,'Normalization','pdf')
hold on
y = -5:0.3:15;
mu = 5;
sigma = 2;
f = exp(-(y-mu).^2./(2*sigma^2))./(sigma*sqrt(2*pi));
plot(y,f,'LineWidth',1.5)

% ---------------------------------------------------
figure
subplot(211)
x = linspace(1,10,20);
y = sin(x);
errorbar(x,y,rand(1,length(x)))
hold on
errorbar(x+2,y+3,rand(1,length(x)))
subplot(212)
x = randn(30,4)*4;
boxplot(x)

% ---------------------------------------------------
figure
subplot(221)
x = -4:0.1:4;
y = -4:0.1:4;
[X Y] = meshgrid(x,y);
Z =X.*X+Y.*Y;
contourf(X,Y,Z)
subplot(222)
[X,Y] = meshgrid(-2:.2:2);
Z = X.*exp(-X.^2 - Y.^2);
[DX,DY] = gradient(Z,.2,.2);
contour(X,Y,Z)
subplot(2,2,3)
x = linspace(0,3*pi,200);
y = cos(x) + rand(1,200);
scatter(x,y)
subplot(2,2,4)
load test.mat
scatter(test(:,1),test(:,2))


