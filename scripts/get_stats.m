% Extract statistics from GIF and BaMoS output to CSV for RISAPS.
clear

NeuroMorph_Segmentation_labels = [
    "Non-Brain Outer Tissue"
    "Cerebral Spinal Fluid"
    "Grey Matter"
    "White Matter"
    "Deep Grey Matter"
    "Brain Stem and Pons"
    "Non-brain low"
    "Non-brain med"
    "Non-brain high"
    ];

tissue_labels = [
    "csf"
    "gm"
    "wm"
    "dgm"
    "bsp"
    ];

root_dir = '/nfs/project/RISAPS/derivatives/BaMoS';

subject_search = dir(fullfile(root_dir, 'sub-*'));
subjects = cell(size(subject_search));
[subjects{:}] = subject_search.name;
nsub = length(subjects);

variable_names = {
    'participant_id'
    'csf_0'
    'gm_0'
    'wm_0'
    'dgm_0'
    'bsp_0'
    'wmh_v_jc_0'
    'wmh_v_pv_0'
    'wmh_n_jc_0'
    'wmh_n_pv_0'
    'csf_24'
    'gm_24'
    'wm_24'
    'dgm_24'
    'bsp_24'
    'wmh_v_jc_24'
    'wmh_v_pv_24'
    'wmh_n_jc_24'
    'wmh_n_pv_24'
    };
stats_table = table( ...
    'Size', [nsub, length(variable_names)], ...
    'VariableTypes', [{'string'}, repmat({'doublenan'}, 1, length(variable_names)-1)], ...
    'VariableNames', variable_names);

for sub = 1:nsub
    subject = subjects{sub};
    subject_path = fullfile(root_dir, subject);
    participant_id = strrep(subject, 'sub-', '');
    stats_table.participant_id(sub) = participant_id;
    
    for ses = {'ses-0'; 'ses-24'}
        session = ses{1};
        session_path = fullfile(subject_path, session, 'anat');
        if ~isfolder(session_path)
            fprintf('Skipping nonexistent session folder: %s\n', session_path)
            continue
        end
        
        laplace_path = fullfile(session_path, 'Laplace');
        if ~isfolder(laplace_path)
            fprintf('Skipping nonexistent Laplace folder: %s\n', laplace_path)
            continue
        end            
        
        time_point = strrep(session, 'ses-', '');
        fprintf('Participant %s, time %s.\n', participant_id, time_point)
        
        temp_dir = tempname;
        mkdir(temp_dir);
        
        
        %%  GIF tissue volumes
        Pseg = gunzip(fullfile(laplace_path, [subject, '_Seg1.nii.gz']), temp_dir);
        Pseg = Pseg{1};
        Nseg = nifti(Pseg);
        Yseg = Nseg.dat(:,:,:);
        
        % Work out volumes
        params_seg = spm_imatrix(Nseg.mat);
        voxel_volume = round(abs(prod(params_seg(7:9))), 3);
        fprintf('Voxel volume: %.3f\n', voxel_volume)
%         stats_table{s, 'voxel_volume'} = voxel_volume;
        
        for tissue = 1:5
            tissue_label = tissue_labels(tissue);
            tissue_tp = sprintf('%s_%s', tissue_label, time_point);
            this_stat = voxel_volume * sum((Yseg(:) == tissue));
            stats_table.(tissue_tp)(sub) = this_stat;
        end
        
        %% BaMoS lesion volumes
        Ples = gunzip(fullfile(session_path, sprintf('CorrectLesion_%s.nii.gz', subject)), temp_dir);
        Ples = Ples{1};
        Play = gunzip(fullfile(laplace_path, sprintf('Layers_%s.nii.gz', subject)), temp_dir);
        Play = Play{1};
        Plob = gunzip(fullfile(laplace_path, sprintf('Lobes_%s.nii.gz', subject)), temp_dir);
        Plob = Plob{1};
        
        Nles = nifti(Ples);
        Yles = Nles.dat(:,:,:);
        Nlay = nifti(Play);
        Ylay = Nlay.dat(:,:,:);
        Nlob = nifti(Plob);
        Ylob = Nlob.dat(:,:,:);
        
        % Merge layers 4 and 5
        Ylay(Ylay==5) = 4;
        
        % Convert lobes to consistent integers
%         Ulob = unique(Ylob(:));
%         Ulob = Ulob(Ulob~=0);
%         Ylobi = zeros(size(Ylob));
%         for f = 1:length(Ulob)
%             Ylobi(Ylob==Ulob(f)) = f;
%         end
        Ylobi = Ylob ./ (max(Ylob(:)) / 10);
        
        % Combine layer and lobe images
        both = (Ylay>0 & Ylobi>0);
        Yll = ((Ylay - 1) .* max(Ylobi(:)) + Ylobi) .* both;
        
        % Split layers into juxtacortical and periventricular
        Ylay2 = zeros(size(Ylay));
        Ylay2(Ylay>0) = 1;
        Ylay2(Ylay==4) = 2;
        
        % Work out volumes
        params_les = spm_imatrix(Nles.mat);
        if any(params_les(:) ~= params_seg(:))
            error('Segmentation and lesion orientation parameters do not match')
        end
        simple_layer_names = {'pv', 'jc'};
        for layer2 = 1:2
            simple_layer_name = simple_layer_names{layer2};
            this_variable = sprintf('wmh_v_%s_%s', simple_layer_name, time_point);
            this_stat = voxel_volume * sum((Ylay2(:) == layer2) & (Yles(:) > 0));
            stats_table.(this_variable)(sub) = this_stat;
        end
        
%         for layer = 1:4
%             for lobe = 1:10
%                 name = sprintf('layer%dlobe%02d', layer, lobe);
%                 this_stat = voxel_volume * sum((Ylay(:) == layer) & ...
%                     (Ylobi(:) == lobe) & (Yles(:) > 0));
%                 this_stat_label = ['lesion_volume_', name];
%                 stats_table{s, this_stat_label} = this_stat;
%             end
%         end
        
%         % Work out lesion counts for two layers by FPTP
%         [lesion_label, num_lesions] = spm_bwlabel(Yles, 6);
%         lesion_location = zeros(num_lesions, 1);
%         for les = 1:num_lesions
%             lesion_locations = Ylay2((Ylay2 > 0) & (lesion_label == les));
%             if isempty(lesion_locations)
%                 % This lesion is entirely outside labelled layers
%                 continue
%             end
%             [unique_lesion_locations, positions] = unique(sort(lesion_locations(:)));
%             if numel(unique_lesion_locations) > 1
%                 % Figure out which is the most frequent label for this lesion
%                 location_counts = diff([positions; numel(lesion_locations) + 1]);
%                 max_location = unique_lesion_locations(location_counts == max(location_counts));
%                 if numel(max_location) > 1
%                     % If there are two or more equally frequent labels, 
%                     % pick one at random.
%                     random_sorter = rand(size(max_location));
%                     while sum(random_sorter == max(random_sorter)) > 1
%                         random_sorter = rand(size(max_location));
%                     end
%                     lesion_location(les) = max_location(random_sorter == max(random_sorter));
%                 else
%                     lesion_location(les) = max_location;
%                 end
%             else
%                 lesion_location(les) = unique_lesion_locations;
%             end
%         end
% 
%         for layer2 = 1:2
%             simple_layer_name = simple_layer_names{layer2};
%             this_variable = sprintf('wmh_n_%s_%s', simple_layer_name, time_point);
%             this_stat = sum(lesion_location == layer2);
%             stats_table.(this_variable)(sub) = this_stat;
%         end
        
        % Work out lesion count by PR
        [lesion_label, num_lesions] = spm_bwlabel(Yles, 6);
        [~, num_lesions18] = spm_bwlabel(Yles, 18);
        [~, num_lesions26] = spm_bwlabel(Yles, 26);
        counts_to_display = { ...
            'surface', num_lesions; ...
            'edge', num_lesions18; ...
            'corner', num_lesions26 ...
            };
        for f = 1:3
            fprintf('Total lesion count (%s): %d.\n', counts_to_display{f,1}, counts_to_display{f,2})
        end

        lesion_counts = zeros(num_lesions, 2);
        for les = 1:num_lesions
            lesion_locations = Ylay2((Ylay2 > 0) & (lesion_label == les));
            if isempty(lesion_locations)
                % This lesion is entirely outside labelled layers
                continue
            end
            lesion_voxels = numel(lesion_locations);
            [unique_lesion_locations, positions] = unique(sort(lesion_locations(:)));
            if numel(unique_lesion_locations) > 1
                % Adjust count by total volume and add to array
                location_counts = diff([positions; numel(lesion_locations) + 1]) ./ lesion_voxels;
                for loc = 1:numel(unique_lesion_locations)
                    lesion_counts(les, unique_lesion_locations(loc)) = location_counts(loc);
                end
            else
                lesion_counts(les, unique_lesion_locations) = 1;
            end
        end
        lesion_count_sums = sum(lesion_counts);
        for layer2 = 1:2
            simple_layer_name = simple_layer_names{layer2};
            this_variable = sprintf('wmh_n_%s_%s', simple_layer_name, time_point);
            this_stat = lesion_count_sums(layer2);
            stats_table.(this_variable)(sub) = this_stat;
        end
    end
end

csv_filename = fullfile(root_dir, 'tissue_lesion_stats.csv');
writetable(stats_table, csv_filename)
rmdir(temp_dir, 's')
