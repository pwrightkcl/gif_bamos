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
participant_id = strrep(subjects, 'sub-', '');

stats_table = table(participant_id);

for sub = 1:nsub
    subject = subjects{sub};
    subject_path = fullfile(root_dir, subject);
    this_participant_id = stats_table.participant_id{sub};
    
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
        fprintf('Participant %s, time %s.\n', this_participant_id, time_point)
        
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
        
        % Work out volumes
        params_les = spm_imatrix(Nles.mat);
        if any(params_les(:) ~= params_seg(:))
            error('Segmentation and lesion orientation parameters do not match')
        end
       
        for layer = 1:4
            for lobe = 1:10
                region_variable = sprintf('v_layer%dlobe%02d_%s', layer, lobe, time_point);
                region_stat = voxel_volume * sum((Ylay(:) == layer) & ...
                    (Ylobi(:) == lobe));
                stats_table.(region_variable)(sub) = region_stat;
                lesion_variable = sprintf('wmh_v_layer%dlobe%02d_%s', layer, lobe, time_point);
                lesion_stat = voxel_volume * sum((Ylay(:) == layer) & ...
                    (Ylobi(:) == lobe) & (Yles(:) > 0));
                stats_table.(lesion_variable)(sub) = lesion_stat;
            end
        end
        
        % Work out lesion counts by FPTP
        [lesion_num, num_lesions] = spm_bwlabel(Yles, 26);
        lesion_location = zeros(num_lesions, 1);
        for les = 1:num_lesions
            lesion_locations = Yll((Yll > 0) & (lesion_num == les));
            if isempty(lesion_locations)
                % This lesion is entirely outside labelled layers and lobes
                continue
            end
            [unique_lesion_locations, positions] = unique(sort(lesion_locations(:)));
            if numel(unique_lesion_locations) > 1
                % Figure out which is the most frequent label for this lesion
                location_counts = diff([positions; numel(lesion_locations) + 1]);
                max_location = unique_lesion_locations(location_counts == max(location_counts));
                if numel(max_location) > 1
                    % If there are two equally frequent labels, pick one at
                    % random
                    random_sorter = rand(size(max_location));
                    while sum(random_sorter == max(random_sorter)) > 1
                        random_sorter = rand(size(max_location));
                    end
                    lesion_location(les) = max_location(random_sorter == max(random_sorter));
                else
                    lesion_location(les) = max_location;
                end
            else
                lesion_location(les) = unique_lesion_locations;
            end
        end
        for layer = 1:4
            for lobe = 1:10
                this_variable = sprintf('wmh_n_layer%dlobe%02d_%s', layer, lobe, time_point);
                layer_lobe_num = 10 * (layer - 1) + lobe;
                this_stat = sum(lesion_location == layer_lobe_num);
                stats_table.(this_variable)(sub) = this_stat;
            end
        end
        
        % Work out lesion count by PR
        [lesion_label, num_lesions] = spm_bwlabel(Yles, 6);
        lesion_counts = zeros(num_lesions, 40);
        for les = 1:num_lesions
            lesion_locations = Yll((Yll > 0) & (lesion_label == les));
            if isempty(lesion_locations)
                % This lesion is entirely outside labelled layers
                continue
            end
            lesion_voxels = numel(lesion_locations);
            [unique_lesion_locations, positions] = unique(sort(lesion_locations(:)));
            if numel(unique_lesion_locations) > 1
                % Adjust count by total volume and add to array
                location_counts = diff([positions; numel(lesion_locations) + 1]) ./ lesion_voxels;
                for loc = 1:numel(location_counts)
                    lesion_counts(les, unique_lesion_locations(loc)) = location_counts(loc);
                end
            else
                lesion_counts(les, unique_lesion_locations) = 1;
            end
        end
        lesion_count_sums = sum(lesion_counts);
        for layer = 1:4
            for lobe = 1:10
                this_variable = sprintf('wmh_n_layer%dlobe%02d_%s', layer, lobe, time_point);
                layer_lobe_num = 10 * (layer - 1) + lobe;
                this_stat = lesion_count_sums(layer_lobe_num);
                stats_table.(this_variable)(sub) = this_stat;
            end
        end
    end
end

csv_filename = fullfile(root_dir, 'tissue_lesion_stats_full.csv');
writetable(stats_table, csv_filename)
rmdir(temp_dir, 's')
