function bathm = read_bty(filename)
fid = fopen(filename);
T = textscan(fid, "%s");
T = T{1};
N = str2num(T{2});
r = zeros(1,N);
d = zeros(1,N);
for n = 1:N
    r(n) = str2double(T{2*n+1});
    d(n) = str2double(T{2*n+2});
end

bathm.r = r;
bathm.d = d;