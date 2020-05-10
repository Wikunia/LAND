function [ varargout ] = voronoiCluster( obj, isRandom, showImage, saveImageFolder, saveImageFilename, title_class, max_area, max_cum_area )
    function [ ys ] = hist2cumhist(vals, bins)
        half_dist_bins = (bins(2)-bins(1))/2;
        ys = zeros(1,length(bins));
        for i=1:length(bins)
            c_vals_idx = find(bins(i)-half_dist_bins <= vals & vals < bins(i)+half_dist_bins);
            ys(i) = sum(vals(c_vals_idx));
        end    
    end
    %voronoiCluster computes Voronoi cells around each data point and uses them
    %for density estimation
    %
    % The current version is implemented for 2D + 3D data sets.
    %
    % Input:
    %   obj: The cell object (given by cell.voronoiCluster)
    %   isRandom: true = use random data; false = use experimental data
    %            (default: false)
    %   showImage: true = shows histograms and the Voronoi clustering
    %            (default: false)
    %   saveImageFolder: The name of the existing folder images will be saved to 
    %            (default: "")
    %   saveImageFilename: The images will be saved i.e with:  
    %             saveas(f, saveImageFolder+"/"+saveImageFilename+"_density_histo", "png");
    %   title_class: Will be part of the plot title for plots 
    %            (default: "")
    %   max_area: limit the maximum area in histogram plots 
    %            (default: 0 = no limit)
    %   max_cum_area: limit the maximum cumulative area in plots 
    %            (default: 0 = no limit)
    
    %
    % Output
    %   (1) smallest area/volume in nanometer^{2,3}
    %   (2) biggest area/volume in nanometer^{2,3}
    %   (3) lowest plot density in 1/nanometer^{2,3} (0.5% outlier)
    %   (4) highest plot density in 1/nanometer^{2,3} (99.5% outlier)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    switch nargin
        
        case 1
            isRandom = 0;
            showImage = 0;
            saveImageFolder = "";
            saveImageFilename = "";
            title_class = "";
            max_area = 0;
            max_cum_area = 0;
        case 2
            showImage = 0;
            saveImageFolder = "";
            saveImageFilename = "";
            title_class = "";
            max_area = 0;
            max_cum_area = 0;
        case 3
            saveImageFolder = "";
            saveImageFilename = "";
            title_class = "";
            max_area = 0;
            max_cum_area = 0;
        case 4
            saveImageFilename = "";
            title_class = "";
            max_area = 0;
            max_cum_area = 0;
        case 5
            title_class = "";
            max_area = 0;
            max_cum_area = 0;
        case 6
            max_area = 0;
            max_cum_area = 0;
        case 7
            max_cum_area = 0;
        case 8
            
        otherwise
            error('Wrong number of input arguments!')
    end
    if isRandom == true
        positions = obj.randomTable;
        dataMat = obj.randomClusterStruct;
        treeData = obj.randomQueryData;
    else
        positions = obj.positionTable;
        dataMat = obj.clusterStruct;
        treeData = obj.queryData;
    end
    
    dim = obj.dimension;
    
    %% Voronoi
    if dim == 2
        dt = delaunayTriangulation(double(positions(:,1)),double(positions(:,2)));
    elseif dim == 3
        dt = delaunayTriangulation(double(positions(:,1)),double(positions(:,2)),double(positions(:,3)));
    else
        error("Only dimension 2 and 3 are supported")
    end
    %% voronoi vertices and regions
    [V,R] = voronoiDiagram(dt);
    
    A = 0;
    smallest_vol = Inf;
    biggest_vol = 0;
    xmin = min(positions(:, 1));
    xmax = max(positions(:, 1));
    ymin = min(positions(:, 2));
    ymax = max(positions(:, 2));
    if dim == 3
       zmin = min(positions(:, 3));
       zmax = max(positions(:, 3)); 
    end
    reasonables = false(1,length(R));
    j = 1;
    
    area_or_vol = "Area";
    if dim == 3
        area_or_vol = "Volume";
    end
    
    saveImage = false;
    if saveImageFolder ~= ""
       saveImage = true;
    end
    
    %% calculate biggest and smallest area/volume if whole voronoi cluster is inside the cell area
    %% for each region check if inside
    high_density_region_x = 0.0;
    high_density_region_y = 0.0;
    for i = 1:length(R)
        reasonable = true;
        for jxy=V(R{i},:)'
            if jxy(1) <= xmin || jxy(1) >= xmax || jxy(2) <= ymin || jxy(2) >= ymax
                reasonable = false;
                break
            end
        end
        if reasonable == false
            continue
        end
        reasonables(i) = 1;
        if dim == 2
            volume = polyarea(V(R{i}([1:end,1]),1),V(R{i}([1:end,1]),2));
        else
             XR10 = V(R{i},:);
             [K,volume] = convhull(XR10);
        end
        if isnan(volume) == false && isinf(volume) == false
         A(j) = volume;
         j = j + 1;
         if volume < 2.5 && high_density_region_y == 0 && high_density_region_x == 0
             high_density_region_x = V(R{i}(1),1);
             high_density_region_y = V(R{i}(1),2);
         end
         
         if volume < smallest_vol
             % disp(["volume: ",volume," pos: ",V(R{i}(1),1),V(R{i}(1),2)])
             smallest_vol = volume;
         end
         if volume > biggest_vol
             biggest_vol = volume;
         end
        end
    end
    high_density_region_x = 2000;
    high_density_region_y = 2000;
    
    disp("Size A: ")
    A = A';
    disp(size(A))
    densities = 1./A;
    if dim == 2
        micro_densities = 10^6.*densities;
    elseif dim == 3
        micro_densities = 10^9.*densities;
    end
    
    if dim == 2
        micro_area = 10^(-6).*A;
    elseif dim == 3
        micro_area = 10^(-9).*A;
    end
    
    obj.voronoi_micro_area = micro_area;
    obj.voronoi_micro_densities = micro_densities;
    
    
    disp("quantile 0.5%")
    lowest_plot_density = quantile(micro_densities, 0.005)
    disp("quantile 99.5%")
    highest_plot_density = quantile(micro_densities, 0.995);
    
    lowest_plot_density = 823.4638;
    highest_plot_density = 40000;
    
    lowest_plot_area = quantile(micro_area, 0.005);
    highest_plot_area = quantile(micro_area, 0.995);
    
    mdensities_range_idx = find(lowest_plot_density <= micro_densities &  micro_densities <= highest_plot_density);
    mdensities_range = micro_densities(mdensities_range_idx);
    
    marea_range_idx = find(lowest_plot_area <= micro_area &  micro_area <= highest_plot_area);
    marea_range = micro_area(marea_range_idx);
    
    % density histo plots
    if showImage || saveImage
        if ~showImage
            f = figure('visible', 'off');
        else
            f = figure
        end
        histogram(micro_densities,40)
        set(gca,'yscale','log')
        title({"Density histogram"; "Type: "+title_class+", #voronoi cells: "+length(micro_densities)})
        xlabel("Density in μm^{-"+dim+"}")
        ylabel("Number of voronoi cells")
        if saveImage
            saveas(f, saveImageFolder+"/"+saveImageFilename+"_density_histo", "png");
        end
          
        if ~showImage
            f = figure('visible', 'off');
        else
            f = figure
        end
        histogram(mdensities_range,40)
        set(gca,'yscale','log')
        title({"Density histogram 0.5% - 99.5%"; "Type: "+title_class+", #voronoi cells: "+length(mdensities_range)})
        xlabel("Density in μm^{-"+dim+"}")
        ylabel("Number of voronoi cells")
        if saveImage
            saveas(f, saveImageFolder+"/"+saveImageFilename+"_density_histo_range", "png");
        end
    end
    
    % cumulative plots and area histo plots
    if showImage || saveImage
        if ~showImage
            f = figure('visible', 'off');
        else
            f = figure
        end
        [yvals,xvals] = ecdf(micro_densities);
        semilogx(xvals,yvals,'-r')
        title({"Cumulative density plot"; "Type: "+title_class})
        ylabel("Cumulative fraction")
        xlabel("Voronoi density in μm^{-"+dim+"}")
        if saveImage
            saveas(f, saveImageFolder+"/"+saveImageFilename+"_cum_density", "png");
        end
        
        if ~showImage
            f = figure('visible', 'off');
        else
            f = figure
        end
        [contents, bins] = hist(micro_area,40);
        ys = hist2cumhist(micro_area, bins);
        bar(bins, ys, 1)
        xlabel(area_or_vol+" in μm^{"+dim+"}")
        ylabel("Cumulative area of voronoi cells")
        title({area_or_vol+" histogram"; "Type: "+title_class+", Total "+area_or_vol+": "+sprintf("%.1f", sum(micro_area))+"μm^{"+dim+"}"})
        
        if saveImage
            saveas(f, saveImageFolder+"/"+saveImageFilename+"_"+area_or_vol+"_histo_cum", "png");
        end
        
        if ~showImage
            f = figure('visible', 'off');
        else
            f = figure
        end
        histogram(micro_area,40)
        set(gca,'yscale','log')
        xlabel(area_or_vol+" in μm^{"+dim+"}")
        ylabel("Number of voronoi cells")
        title({area_or_vol+" histogram"; "Type: "+title_class+", #voronoi cells: "+length(micro_area)})
        
        if saveImage
            saveas(f, saveImageFolder+"/"+saveImageFilename+"_"+area_or_vol+"_histo", "png");
        end
        
        if ~showImage
            f = figure('visible', 'off');
        else
            f = figure
        end
        histogram(marea_range,40)
        set(gca,'yscale','log')
        xlabel(area_or_vol+" in μm^{"+dim+"}")
        ylabel("Number of voronoi cells")
        title({area_or_vol+" histogram 0.5% - 99.5%"; "Type: "+title_class+", #voronoi cells: "+length(marea_range)})
        
        if saveImage
            saveas(f, saveImageFolder+"/"+saveImageFilename+"_"+area_or_vol+"_histo_range", "png");
        end
        
        if ~showImage
            f = figure('visible', 'off');
        else
            f = figure;
        end
        [contents, bins] = hist(marea_range,40);
        ys = hist2cumhist(marea_range, bins);
        bar(bins, ys, 1)
        xlabel(area_or_vol+" in μm^{"+dim+"}")
        ylabel("Cumulative area of voronoi cells")
        title({area_or_vol+" histogram 0.5% - 99.5%"; "Type: "+title_class+", Total "+area_or_vol+": "+sprintf("%.1f", sum(marea_range))+"μm^{"+dim+"}"})
        
        if saveImage
            saveas(f, saveImageFolder+"/"+saveImageFilename+"_"+area_or_vol+"_histo_range_cum", "png");
        end
        
        if max_area ~= 0 && max_cum_area ~= 0
            marea_range_setting_idx = find(0 <= micro_area &  micro_area <= max_area);
            marea_range_setting = micro_area(marea_range_setting_idx);
               
            if ~showImage
                f = figure('visible', 'off');
            else
                f = figure
            end
            nbins = 40;
            histogram(marea_range_setting,nbins)
            set(gca,'yscale','log')
            xlabel(area_or_vol+" in μm^{"+dim+"}")
            ylabel("Number of voronoi cells")
            title({area_or_vol+" histogram"; "Type: "+title_class+", #voronoi cells: "+length(marea_range_setting)})
            ylim([1 max_cum_area/(max_area/nbins)]);
            xlim([0 max_area]);
    
            if saveImage
                saveas(f, saveImageFolder+"/"+saveImageFilename+"_"+area_or_vol+"_histo_range_setting", "png");
            end
    
            if ~showImage
                f = figure('visible', 'off');
            else
                f = figure;
            end
            [contents, bins] = hist(marea_range_setting,40);
            ys = hist2cumhist(marea_range_setting, bins);
            bar(bins, ys, 1)
            xlabel(area_or_vol+" in μm^{"+dim+"}")
            ylabel("Cumulative area of voronoi cells")
            title({area_or_vol+" histogram"; "Type: "+title_class+", Total "+area_or_vol+": "+sprintf("%.1f", sum(marea_range_setting))+"μm^{"+dim+"}"})
            ylim([0 max_cum_area]);
            xlim([0 max_area]);
    
            if saveImage
                saveas(f, saveImageFolder+"/"+saveImageFilename+"_"+area_or_vol+"_histo_range_cum_setting", "png");
            end 
        end
    end
        
    
    disp("Smallest "+area_or_vol+": nm^{+"+dim+"}")
    disp(smallest_vol)
    
    disp("Biggest "+area_or_vol+": nm^{+"+dim+"}")
    disp(biggest_vol)
    
    if showImage || saveImage
        if ~showImage
            f = figure('visible', 'off');
        else
            f = figure
        end
        if dim == 2
            scatter(double(positions(:,1)),double(positions(:,2)),'.r', 'LineWidth', 1)
        else
            scatter3(double(positions(:,1)),double(positions(:,2)),double(positions(:,3)),'.r')
        end
        axis equal
        xlim([xmin,xmax])
        ylim([ymin,ymax])
        if dim == 3
            zlim([zmin,zmax])
            zlabel("z in nm")
        end
        title({"Localizations"; "Type: "+title_class})
        title({"Localizations";})
        xlabel("x in nm")
        ylabel("y in nm")
        if saveImage
            saveas(f, saveImageFolder+"/"+saveImageFilename+"_locs", "png");
        end
     
        if ~showImage
            f = figure('visible', 'off');
        else
            f = figure
        end
        hold on
        j = 1;
        if dim == 3
            z_mean = mean(double(positions(:,3)));
        end
        disp(high_density_region_x);
        disp(high_density_region_y);
           
        ncolors = 1000;
        cmap = parula(ncolors);
        caxis([lowest_plot_density highest_plot_density]);
        %scatter(double(positions(:,1)),double(positions(:,2)),'.r', 'LineWidth', 2)
        for i=1:length(R)
            if reasonables(i)
                %{
                if V(R{i}(1),1) > high_density_region_x + 500 || V(R{i}(1),1) < high_density_region_x - 500
                    j = j+1;
                    continue
                end
                if V(R{i}(1),2) > high_density_region_y + 500 || V(R{i}(1),2) < high_density_region_y - 500
                    j = j+1;
                    continue
                end
               %}
            
               cmap_row = floor(ncolors*((micro_densities(j)-lowest_plot_density)/(highest_plot_density-lowest_plot_density)))+1;
               if cmap_row >= ncolors+1
                   cmap_row = ncolors;
               end
               color = "black";
               if cmap_row > 0
                  color = cmap(cmap_row,:);
               end
               if dim == 2
                    h = fill(V(R{i},1),V(R{i},2), color);
                    set(h,'EdgeColor','none')
                  else 
                    if any(V(R{i},3) >= z_mean - 20) && any(V(R{i},3) <= z_mean + 20)
                        XR10 = V(R{i},:);
                        K = convhull(XR10);
                        trisurf(K, XR10(:,1) ,XR10(:,2) ,XR10(:,3) , 'FaceColor', color, 'FaceAlpha',0.9, 'EdgeColor', 'none')
                    end
               end
               j = j+1;
            else
                %plot(V(R{i}([1:end,1]),1),V(R{i}([1:end,1]),2),'-b')
            end        
        end
    
    
        %plot(double(positions(:,1)),double(positions(:,2)),'.w');
        hold off
        %%plot(vx,vy,'-b',double(positions(:,1)),double(positions(:,2)),'.r');
        axis equal
        %xlim([high_density_region_x-200,high_density_region_x+200])
        %ylim([high_density_region_y-200,high_density_region_y+200])
        xlim([xmin,xmax])
        ylim([ymin,ymax])
        if dim == 3
            zlim([zmin,zmax])
            zlabel("z in nm")
        end
        set(gca,'Color',"black")
        if dim == 2
            %title({"Voronoi diagram"; "Type: "+title_class})
        else 
            title({"Voronoi diagram (z in ["+(z_mean-20)+","+(z_mean+20)+"])"; "(range: 0.5% - 99.5%)";  "Type: "+title_class})
        end
        xlabel("x in nm")
        ylabel("y in nm")
        
        c = colorbar;
        c.Label.String = "Density in μm^{-"+dim+"}";
        c.Limits = [lowest_plot_density highest_plot_density];
        if saveImage
            %set(gcf,'position',[0,0,1920,1080])
            %set(gcf, 'InvertHardCopy', 'off');
            saveas(f, saveImageFolder+"/"+saveImageFilename+"_voronoi", "png");
        end
    end
    
    varargout{1} = smallest_vol;
    varargout{2} = biggest_vol;
    varargout{3} = lowest_plot_density;
    varargout{4} = highest_plot_density;
end