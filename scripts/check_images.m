% Check everything

clear

orientation = 'axial';
mask_col = [0 0 0; 1 0 0];
load batlowS
transparency = 0.4;

root_dir = '/nfs/project/RISAPS/derivatives/BaMoS';
out_dir = fullfile(root_dir, 'check');
if ~isfolder(out_dir)
    mkdir(out_dir)
end

subject_search = dir(fullfile(root_dir, 'sub-*'));
subject_dirs = cell(size(subject_search));
[subject_dirs{:}] = subject_search.name;
nsub = length(subject_dirs);

% Make sure the SPM Graphics window is clear
F = spm_figure('FindWin', 'Graphics');
spm_figure('Close', F);
spm_figure('GetWin', 'Graphics');

counter = 0;
for sub = 1:nsub
    subject_dir = subject_dirs{sub};
    disp(subject_dir)
    subject_path = fullfile(root_dir, subject_dir);
    session_search = dir(fullfile(subject_path, 'ses-*'));
    session_dirs = cell(size(session_search));
    [session_dirs{:}] = session_search.name;
    nses = length(session_dirs);
    for ses = 1:nses
        counter = counter + 1;
        session_dir = session_dirs{ses};
        disp(session_dir)
        session_path = fullfile(subject_path, session_dir, 'anat');
        
        laplace_path = fullfile(session_path, 'Laplace');
        if ~isfolder(laplace_path)
            fprintf('Skipping nonexistent Laplace folder: %s\n', laplace_path)
            continue
        end            

        img = struct( ...
            't1',      fullfile(session_path, sprintf('T1_%s.nii.gz', subject_dir)), ...
            'flair',   fullfile(session_path, sprintf('FLAIR_%s.nii.gz', subject_dir)), ...
            'layers',  fullfile(laplace_path, sprintf('Layers_%s.nii.gz', subject_dir)), ...
            'lobes',   fullfile(laplace_path, sprintf('Lobes_%s.nii.gz', subject_dir)), ...
            'lesions', fullfile(session_path, sprintf('CorrectLesion_%s.nii.gz', subject_dir)), ...
            'seg',     fullfile(laplace_path, sprintf('%s_Seg1.nii.gz', subject_dir)) ...
        );
        
        fields_to_check = fieldnames(img);
        all_files_exist = true;
        for f = 1:length(fields_to_check)
            field_to_check = fields_to_check{f};
            file_to_check = img.(field_to_check);
            if ~isfile(file_to_check)
                fprintf('No %s image.\n', field_to_check)
                all_files_exist = false;
            end
        end
        if ~all_files_exist
            disp('One or more image is missing. Skipping this session.')
            continue
        end
        
        temp_dir = tempname;
        mkdir(temp_dir)
        disp('gunzipping images to temporary directory')
        for f = 1:length(fields_to_check)
            field_to_check = fields_to_check{f};
            temp_image = gunzip(img.(field_to_check), temp_dir);
            img.(field_to_check) = temp_image{1};
        end
        
        print_prefix = fullfile(out_dir, sprintf('%04d_%s_%s_', ...
            counter, subject_dir, session_dir));
        print_files = { ...
            [print_prefix, '1_T1.png'], ...
            [print_prefix, '2_seg.png'], ...
            [print_prefix, '3_FLAIR.png'], ...
            [print_prefix, '4_lesions.png'], ...
            [print_prefix, '5_layers.png'], ...
            [print_prefix, '6_lobes.png'], ...
            };
        
        print_file_exists = false(length(print_files), 1);
        for f = 1:length(print_files)
            if isfile(print_files{f})
                print_file_exists(f) = true;
            end
        end
        if ~all(print_file_exists)
            
            
            %% T1
            so = slover;
            so.cbar = [];
            so.img(1).vol   = spm_vol(img.t1);
            so.img(1).type  = 'truecolour';
            so.img(1).cmap  = gray;
            [mx, mn] = slover('volmaxmin', so.img(1).vol);
            so.img(1).range = [0 mx*0.99];
            
            % Work out slices
            M   = so.img(1).vol.mat;
            vx  = sqrt(sum(M(1:3,1:3).^2));
            dim = so.img(1).vol.dim;
            ends = [0 dim(3)];
            ends = ends .* vx(3);
            ends = ends - mean(ends);
            slices = linspace(ends(1), ends(2), 25);
            slices = slices(1:end-1) + diff(slices)./2;

            % Reset orientation
            if det(M(1:3,1:3))<0
                vx(1) = -vx(1);
            end
            orig = (dim(1:3)+1)/2;
            off  = -vx.*orig;
            M1   = [vx(1) 0      0         off(1)
                0      vx(2) 0      off(2)
                0      0      vx(3) off(3)
                0      0      0      1];
            so.img(1).vol.mat = M1;
            
            so.img(1).prop  = 1;
            so.transform    = orientation;
            so.slices       = slices;
            so.figure       = spm_figure('GetWin', 'Graphics');
            paint(so);
            
            if ~isfile(spm_file(print_files{1}, 'suffix', '_001'))
                header = sprintf('T1: %s\nDate: %s\n', ...
                    spm_file(img.t1, 'filename'), ...
                    datestr(now,0));
                ann1=annotation('textbox',[0 .94 1 .06],'Color','r','String',header,...
                    'EdgeColor','none', 'Interpreter', 'none');
                spm_print(print_files{1}, 'Graphics', 'png');
                delete(ann1);
            end

            
            %% GIF segmentation
            so.img(1).prop  = 1-transparency;
            
            so.img(2).vol     = spm_vol(img.seg);
            so.img(2).vol.mat = M1;
            so.img(2).type    = 'truecolour';
            so.img(2).cmap    = [0 0 0 ; batlowS(1:8,:)];
            so.img(2).range   = [0 8];
            so.img(2).prop    = transparency;
            
            paint(so);
            
            if ~isfile(spm_file(print_files{2}, 'suffix', '_001'))
                header = sprintf('T1: %s\nSeg: %s\nDate: %s\n', ...
                    spm_file(img.t1, 'filename'), ...
                    spm_file(img.seg, 'filename'), ...
                    datestr(now, 0));
                ann1=annotation('textbox', [0 .94 1 .06], 'Color', 'r', 'String', header, ...
                    'EdgeColor', 'none', 'Interpreter', 'none');
                spm_print(print_files{2}, 'Graphics', 'png');
                delete(ann1);
            end
            

            %% FLAIR
            so = slover;
            so.cbar = [];
            so.img(1).vol   = spm_vol(img.flair);
            so.img(1).type  = 'truecolour';
            so.img(1).cmap  = gray;
            [mx, mn] = slover('volmaxmin', so.img(1).vol);
            so.img(1).range = [0 mx*0.99];
            
            % Work out slices
            M   = so.img(1).vol.mat;
            vx  = sqrt(sum(M(1:3,1:3).^2));
            dim = so.img(1).vol.dim;
            ends = [0 dim(3)];
            ends = ends .* vx(3);
            ends = ends - mean(ends);
            slices = linspace(ends(1), ends(2), 25);
            slices = slices(1:end-1) + diff(slices)./2;

            % Reset orientation
            if det(M(1:3,1:3))<0
                vx(1) = -vx(1);
            end
            orig = (dim(1:3)+1)/2;
            off  = -vx.*orig;
            M1   = [vx(1) 0      0         off(1)
                0      vx(2) 0      off(2)
                0      0      vx(3) off(3)
                0      0      0      1];
            so.img(1).vol.mat = M1;
            
            so.img(1).prop  = 1;
            so.transform    = orientation;
            so.slices       = slices;
            so.figure       = spm_figure('GetWin', 'Graphics');
            paint(so);
            
            if ~isfile(spm_file(print_files{3}, 'suffix', '_001'))
                header = sprintf('FLAIR: %s\nDate: %s\n', ...
                    spm_file(img.flair, 'filename'), ...
                    datestr(now,0));
                ann1=annotation('textbox',[0 .94 1 .06],'Color','r','String',header,...
                    'EdgeColor','none', 'Interpreter', 'none');
                spm_print(print_files{3}, 'Graphics', 'png');
                delete(ann1);
            end


            %% BaMoS lesions
            so.img(2).vol     = spm_vol(img.lesions);
            so.img(2).vol.mat = M1;
            so.img(2).type    = 'truecolour';
            so.img(2).cmap    = mask_col;
            so.img(2).range   = [0 1];
            so.img(2).prop    = transparency;
            
            paint(so);
            
            if ~isfile(spm_file(print_files{4}, 'suffix', '_001'))
                header = sprintf('FLAIR: %s\nLesions: %s\nDate: %s\n', ...
                    spm_file(img.flair, 'filename'), ...
                    spm_file(img.lesions, 'filename'), ...
                    datestr(now, 0));
                ann1=annotation('textbox', [0 .94 1 .06], 'Color', 'r', 'String', header, ...
                    'EdgeColor', 'none', 'Interpreter', 'none');
                spm_print(print_files{4}, 'Graphics', 'png');
                delete(ann1);
            end

            
            %% BaMoS layers
            so.img(2).vol     = spm_vol(img.layers);
            so.img(2).vol.mat = M1;
            so.img(2).type    = 'truecolour';
            so.img(2).cmap    = [0 0 0 ; batlowS(1:4,:)];
            so.img(2).range   = [0 4];
            so.img(2).prop    = transparency;
            
            paint(so);
            
            if ~isfile(spm_file(print_files{5}, 'suffix', '_001'))
                header = sprintf('FLAIR: %s\nLayers: %s\nDate: %s\n', ...
                    spm_file(img.flair, 'filename'), ...
                    spm_file(img.layers, 'filename'), ...
                    datestr(now, 0));
                ann1=annotation('textbox', [0 .94 1 .06], 'Color', 'r', 'String', header, ...
                    'EdgeColor', 'none', 'Interpreter', 'none');
                spm_print(print_files{5}, 'Graphics', 'png');
                delete(ann1);
            end
            

            %% BaMoS lobes
            so.img(2).vol     = spm_vol(img.lobes);
            so.img(2).vol.mat = M1;
            so.img(2).type    = 'truecolour';
            so.img(2).cmap    = [0 0 0 ; batlowS(1:10,:)];
            [mx, mn] = slover('volmaxmin', so.img(2).vol);
            so.img(2).range   = [0 mx];
            so.img(2).prop    = transparency;
            
            paint(so);
            
            if ~isfile(spm_file(print_files{6}, 'suffix', '_001'))
                header = sprintf('FLAIR: %s\nLobes: %s\nDate: %s\n', ...
                    spm_file(img.flair, 'filename'), ...
                    spm_file(img.lobes, 'filename'), ...
                    datestr(now, 0));
                ann1=annotation('textbox', [0 .94 1 .06], 'Color', 'r', 'String', header, ...
                    'EdgeColor', 'none', 'Interpreter', 'none');
                spm_print(print_files{6}, 'Graphics', 'png');
                delete(ann1);
            end
        end
    end%ses
end%sub
disp(' ')
disp('All done.')
disp('Quitting SPM.')
spm('quit')
disp('The job should complete now but if it has not, delete it manually.')
disp(' ')
