% Extract statistics from GIF and BaMoS output to CSV for RISAPS.
clear

% For reference, _Seg1 file labels numbered from 0:
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

% Script uses labels 1-5
tissue_labels = [
    "csf"
    "gm"
    "wm"
    "dgm"
    "bsp"
    ];

root_dir = '/nfs/project/RISAPS/derivatives/BaMoS';
mask_root = '/nfs/project/RISAPS/derivatives/lesion_masks';
gif_root = '/nfs/project/RISAPS/derivatives/GIF';

subject_search = dir(fullfile(root_dir, 'sub-*'));
subjects = cell(size(subject_search));
[subjects{:}] = subject_search.name;
nsub = length(subjects);

participant_id = strrep(subjects, 'sub-', '');
stats_table = table(participant_id);

for sub = 1:nsub
    subject = subjects{sub};
    subject_path = fullfile(root_dir, subject);
    participant_id = stats_table.participant_id{sub};
    
    for ses = {'ses-0', 'ses-24'}
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
        
        
        %% GIF TIV
        gif_path = fullfile(gif_root, subject, session, 'anat');
        tiv_file = fullfile(gif_path, sprintf('%s_%s_t1_TIV.nii.gz', subject, session));
        Ptiv = char(gunzip(tiv_file, temp_dir));
        Ntiv = nifti(Ptiv);
        Ytiv = Ntiv.dat(:,:,:);
        
        % Work out voxel volume from orientation matrix
        iMtiv = spm_imatrix(Ntiv.mat);
        voxel_volume = round(abs(prod(iMtiv(7:9))), 3);

        % Calculate TIV
        tiv = sum(Ytiv(:));
        tiv_var = sprintf('tiv%s', time_point);
        stats_table.(tiv_var)(sub) = round(tiv * voxel_volume, 0);
        
        
        %%  GIF tissue volumes (maxmap from BaMoS LaPlace directory)
        Pseg = char(gunzip(fullfile(laplace_path, [subject, '_Seg1.nii.gz']), temp_dir));
        Nseg = nifti(Pseg);
        Yseg = Nseg.dat(:,:,:);
        iMseg = spm_imatrix(Nseg.mat);
        if ~isequal(iMseg, iMtiv)
            error('Orientation mismatch:\n%s\n', Pseg)
        end
        if ~isequal(size(Yseg), size(Ytiv))
            error('Size mismatch:\n%s\n', Pseg)
        end
        
        for tissue = 1:5
            tissue_label = tissue_labels(tissue);
            tissue_tp = sprintf('%s_%s', tissue_label, time_point);
            this_stat = sum((Yseg(:) == tissue)) * voxel_volume;
            stats_table.(tissue_tp)(sub) = round(this_stat, 0);
        end
        
        
        %% BaMoS lesion volumes
        % Load BaMoS outputs
        Ples = char(gunzip(fullfile(session_path, sprintf('CorrectLesion_%s.nii.gz', subject)), temp_dir));
        Nles = nifti(Ples);
        Yles = Nles.dat(:,:,:);
        iMles = spm_imatrix(Nles.mat);
        if ~isequal(iMles, iMtiv)
            error('Orientation mismatch:\n%s\n', Ples)
        end
        if ~isequal(size(Yles), size(Ytiv))
            error('Size mismatch:\n%s\n', Ples)
        end

        Play = char(gunzip(fullfile(laplace_path, sprintf('Layers_%s.nii.gz', subject)), temp_dir));
        Nlay = nifti(Play);
        Ylay = Nlay.dat(:,:,:);
        iMlay = spm_imatrix(Nlay.mat);
        if ~isequal(iMlay, iMtiv)
            error('Orientation mismatch:\n%s\n', Play)
        end
        if ~isequal(size(Ylay), size(Ytiv))
            error('Size mismatch:\n%s\n', Play)
        end

        Plob = char(gunzip(fullfile(laplace_path, sprintf('Lobes_%s.nii.gz', subject)), temp_dir));
        Nlob = nifti(Plob);
        Ylob = Nlob.dat(:,:,:);
        iMlob = spm_imatrix(Nlob.mat);
        if ~isequal(iMlob, iMtiv)
            error('Orientation mismatch:\n%s\n', Plob)
        end
        if ~isequal(size(Ylob), size(Ytiv))
            error('Size mismatch:\n%s\n', Plob)
        end
        
        % Apply manual lesion mask if it exists
        mask_path = fullfile(mask_root, subject, session, 'anat');
        mask_var = ['masked', time_point];
        stats_table.(mask_var)(sub) = false;
        stats_table.m24_mask_amended(sub) = false;
        if strcmp(session, 'ses-0')
            mask_file = fullfile(mask_path, [subject, '_ses-0_space-t1_label-lesion_mask.nii.gz']);
            if isfile(mask_file)
                stats_table.(mask_var)(sub) = true;
            end
        elseif strcmp(session, 'ses-24')
            % Prefer the amended m24 mask if it exists
            mask_file = fullfile(mask_path, [subject, '_ses-24_space-m24t1_label-lesion_mask.nii.gz']);
            if isfile(mask_file)
                stats_table.(mask_var)(sub) = true;
                stats_table.m24_mask_amended(sub) = true;
            else
                % Use the baseline mask aligned to m24 is it exists
                mask_file = fullfile(mask_path, [subject, '_ses-0_space-m24t1_label-lesion_mask.nii.gz']);
                if isfile(mask_file)
                    stats_table.(mask_var)(sub) = true;
                end
            end
        else
            error('Unrecognized session: %s\n', session)
        end
        if stats_table.(mask_var)(sub)
            Pmask = char(gunzip(mask_file, temp_dir));
            Nmask = nifti(Pmask);
            Ymask = Nmask.dat(:,:,:);
            iMmask = spm_imatrix(Nmask.mat);
            if ~isequal(iMmask, iMtiv)
                error('Orientation mismatch:\n%s\n', Pmask)
            end
            if ~isequal(size(Ymask), size(Ytiv))
                error('Size mismatch:\n%s\n', Pmask)
            end
            Yles(Ymask > 0) = 0;
        end

        % Merge layers 4 and 5
        Ylay(Ylay==5) = 4;
        
        % Convert lobes to consistent integers
        Ylobi = Ylob ./ (max(Ylob(:)) / 10);
        
        % Final volumes assigned to table variables at the end
        
        
        %% Lesion counts
        % Combine layer and lobe images
        % Lobe varies first then layer:
        % 1-10 = layer 1, lobes 1-10
        % 11-20 = layer 2, lobes 1-10 etc.
        include = (Ylay>0 & Ylobi>0);
        Yll = ((Ylay - 1) .* max(Ylobi(:)) + Ylobi) .* include;
       
        % Split WMH masks into discrete lesions connected by a surface
        [lesion_num, num_lesions] = spm_bwlabel(Yles, 6);
        lesion_location = zeros(num_lesions, 1);  % for absolute
        lesion_counts = zeros(num_lesions, 40);  % for proportional
        for les = 1:num_lesions
            lesion_locations = Yll(include  & (lesion_num == les));
            if isempty(lesion_locations)
                % This lesion is entirely outside labelled layers and lobes
                continue
            end
            [unique_lesion_locations, positions] = unique(sort(lesion_locations(:)));
            lesion_size = numel(lesion_locations);
            if numel(unique_lesion_locations) > 1
                
                % Pick most frequent label for this lesion (abs)
                abs_location_counts = diff([positions; numel(lesion_locations) + 1]);
                max_location = unique_lesion_locations(abs_location_counts == max(abs_location_counts));
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
                
                % Adjust count by total volume and add to array (prop)
                prop_location_counts = diff([positions; numel(lesion_locations) + 1]) ./ lesion_size;
                for loc = 1:numel(prop_location_counts)
                    lesion_counts(les, unique_lesion_locations(loc)) = prop_location_counts(loc);
                end
                
            else
                lesion_location(les) = unique_lesion_locations;  % abs
                lesion_counts(les, unique_lesion_locations) = 1;  % prop
            end
        end
        lesion_count_sums = sum(lesion_counts);
        
        
        %% Assign values to table variables
        for layer = 1:4
            for lobe = 1:10
                % volumes
                region_variable = sprintf('v_layer%dlobe%02d_%s', layer, lobe, time_point);
                region_stat = sum((Ylay(:) == layer) & (Ylobi(:) == lobe)) * voxel_volume;
                stats_table.(region_variable)(sub) = round(region_stat, 1);
                
                lesion_variable = sprintf('wmh_v_layer%dlobe%02d_%s', layer, lobe, time_point);
                lesion_stat = sum((Ylay(:) == layer) & (Ylobi(:) == lobe) & (Yles(:) > 0)) * voxel_volume ;
                stats_table.(lesion_variable)(sub) = round(lesion_stat, 1);

                % counts
                layer_lobe_num = 10 * (layer - 1) + lobe;

                abs_variable = sprintf('wmh_na_layer%dlobe%02d_%s', layer, lobe, time_point);
                abs_stat = sum(lesion_location == layer_lobe_num);
                stats_table.(abs_variable)(sub) = abs_stat;
                
                prop_variable = sprintf('wmh_np_layer%dlobe%02d_%s', layer, lobe, time_point);
                prop_stat = lesion_count_sums(layer_lobe_num);
                stats_table.(prop_variable)(sub) = round(prop_stat, 3);
            end
        end
        rmdir(temp_dir, 's')
    end %ses
end %sub

csv_filename = fullfile(root_dir, 'tissue_lesion_stats_full.csv');
writetable(stats_table, csv_filename)
