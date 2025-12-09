function [a,b,c,CosFi]=TriAngle(x1,y1,x2,y2,x3,y3)

a2 = (x1-x2)*(x1-x2)+(y1-y2)*(y1-y2);
b2 = (x3-x2)*(x3-x2)+(y3-y2)*(y3-y2);
c2 = (x1-x3)*(x1-x3)+(y1-y3)*(y1-y3);
a = round(abs(sqrt(a2))+1);
b = round(abs(sqrt(b2))+1);
c = round(abs(sqrt(c2))+1);
CosFi = -(a2+b2-c2)/(2*sqrt(a2*b2));    %求出余弦值
%angle = acos(pos);         %余弦值装换为弧度值
%realangle = angle*180/pi;   %弧度值转换为角度值
%disp(realangle);