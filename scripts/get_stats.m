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

        % Convert lobes to consistent integers
        Ylobi = Ylob ./ (max(Ylob(:)) / 10);

        % Combine layer and lobe images
        include = (Ylay>0 & Ylobi>0);

        % Calculate total WMH volume
        this_variable = sprintf('wmh_v_%s', time_point);
        this_stat = voxel_volume * sum(include(:) .* Yles(:));
        stats_table.(this_variable)(sub) = round(this_stat, 1);
        
%         % Calculate periventricular and juxtacortical volumes
%         Ylay2 = zeros(size(Ylay));
%         Ylay2(Ylay>0) = 1;
%         Ylay2(Ylay==4) = 2;
%         
%         simple_layer_names = {'pv', 'jc'};
%         for layer2 = 1:2
%             simple_layer_name = simple_layer_names{layer2};
%             this_variable = sprintf('wmh_v_%s_%s', simple_layer_name, time_point);
%             this_stat = voxel_volume * sum((Ylay2(:) == layer2) & (Yles(:) > 0));
%             stats_table.(this_variable)(sub) = this_stat;
%         end
        rmdir(temp_dir, 's')
    end %ses
end %sub

csv_filename = fullfile(root_dir, 'tissue_lesion_stats.csv');
writetable(stats_table, csv_filename)

