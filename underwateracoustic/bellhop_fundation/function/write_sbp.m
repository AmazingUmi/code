function write_sbp(envfil, theta, DI )
%%  д��.sbpָ�����ļ�
% envfil:  .sbp�ļ���
% theta:   ָ���Է�������
% DI:      ָ����ָ��
fid = fopen([envfil '.sbp'], 'wt+');
fprintf(fid, '%d \n', length(theta));
fprintf(fid, '%6.2f  %6.2f \n', [theta ; DI ]); % DI��λdB theta DI ������
fclose(fid);