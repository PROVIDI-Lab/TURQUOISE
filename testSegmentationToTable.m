%% segmentation -> tables

seg = nii;
%segmentation index

%get names of properties
nameLst = {};
prop    = seg.properties{1};
for propIdx = 1:length(prop)
    nameLst{end+1} = prop{propIdx}{1};
end

%store properties in cell array
cellArr = {length(seg), length(prop)};
for idx = 1:length(seg.properties)
    prop    = seg.properties{idx};    
    
    for propIdx = 1:length(prop)
        cellArr{idx, propIdx} = prop{propIdx}{2};
    end
end

%write cellarray to table
tab = cell2table(cellArr, 'VariableNames', nameLst);

% write to disk
filename = 'D:\test.xlsx';
writetable(tab,filename,'Sheet',2,'Range','E2')
