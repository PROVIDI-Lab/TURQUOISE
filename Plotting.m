classdef Plotting < handle
    methods (Static)
        
        % Show a 3D plot of the labels
        function Labels3DView(app)
            f=figure;
            ax = axes(f);
            hold(ax,'on');
            axis(ax,'vis3d');
            axis(ax,'off');
            cameratoolbar(f);
            for N=1:max(app.segmentation.img(:))
               L = app.segmentation.img == N;
               L = smooth3(L,'gaussian',5);
               h(N) = patch(ax,isosurface(L,0.3),                       ...
                   'FaceColor',                                         ...
                   [1 1 1],                                             ...
                   'EdgeColor',                                         ...
                   'none');
%                isonormals(L,h);
%                h.BackFaceLighting = 'reverselit';
            end
            lighting(ax,'gouraud');
            camlight(ax,'headlight'); 
            for N=1:length(h)
               h(N).FaceColor =                                         ...
                   [randi(100)/100 randi(100)/100 randi(100)/100];
               h(N).FaceLighting = 'gouraud';
               h(N).EdgeLighting = 'gouraud';
            end
        end
        
        
        % Show statistics of each label
        function LabelsStatsPlot(app)
            CV      = app.data.img(:,:,:,app.current_4d_idx);
            min_val = inf;
            max_val = -inf;
            f       = figure;
            
            %First find the range that the histogram needs to be shown
            %with:
            %iterate over all labels in image
            for N=1:max(app.segmentation.img(:))
                
               %Get list of all labeled values
               L = app.segmentation.img == N;
               S = CV(L(:) > 0);
               if(isempty(S))
                   continue
               end
               
               %Find histogram min_val and max_val
               if(max(S(:)) > max_val)
                   max_val = max(S(:));
               end
               if(min(S(:)) < min_val)
                   min_val = min(S(:));
               end
            end
            
            %iterate over all labels in image
            for N=1:max(app.segmentation.img(:))
                
               %Get list of all labeled values
               L = app.segmentation.img == N;
               S = CV(L(:) > 0);
               if(isempty(S))
                   continue
               end
               
               %Make histogram
               nbins = 30;
               step = (max_val-min_val)/nbins;
               range = min_val:step:max_val;
               h = hist(S(:),range);
               if(length(h) < 2)
                   continue
               end
               
               %Get name of segmentation
               Name        = app.seg_names{N};
               
               %Plot histogram
               ax=subplot(max(app.segmentation.img(:)),1,N);
               bar(ax,range,h);
               hold on;
               Nvoxels = length(S);
               title([Name ' - NVox ' num2str(Nvoxels)]);
               [current_max_val,max_ind] = max(h);
               max_plot = plot([range(max_ind) range(max_ind)],         ...
                                [0 current_max_val],'--r','LineWidth',2);
               mean_val = mean(S(:));
               mean_plot = plot([mean_val mean_val],                    ...
                                [0 current_max_val],'--g','LineWidth',2);
               prctiles = prctile(S,[5 95]);
               legend([max_plot mean_plot],                             ...
                   {['Modus: ' sprintf('%.2f',range(max_ind))],       ...
                   ['Mean: ' sprintf('%.2f',mean_val)]},            ...
                   'Location',                                          ...
                   'best');
            end
        end     
    end
end














