function copyByCategory(srcFolders, subsetName, subdirs, dstRoot)
    for k = 1:numel(srcFolders)
        srcRoot = srcFolders{k};
        % 对每个类别 A–E
        for s = 1:numel(subdirs)
            catName = subdirs{s};
            % 递归匹配：所有 Rr* 文件夹下的 Pic_out/A/*.png
            pattern = fullfile(srcRoot, '**', 'Pic_out', catName, '*.png');
            F = dir(pattern);
            for f = 1:numel(F)
                srcFile = fullfile(F(f).folder, F(f).name);
                % 直接用原文件名
                dstFile = fullfile(dstRoot, subsetName, catName, F(f).name);
                copyfile(srcFile, dstFile);
            end
        end
    end
end
