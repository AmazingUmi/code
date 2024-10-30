function  [coordE]= jingweidu(coordS, coordE, R, azi)
    azi = azi / 180 *pi;
    coordE.lon = coordS.lon + R * sin(azi) / (111 * cos(coordS.lat/180*pi));
    coordE.lat = coordS.lat + R * cos(azi) / 111;