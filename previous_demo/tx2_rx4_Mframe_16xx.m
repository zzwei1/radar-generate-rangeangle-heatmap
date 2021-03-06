clc;
clear all;
close all;
%% parameter setting
% constant parameters
c = physconst('LightSpeed');% Speed of light in air (m/s)
fc = 77e9;% Center frequency (Hz)
lambda = c/fc;
Rx = 4;
Tx = 2;

% file information and frame information
frame_start = 1;
frame_end = 10;
% option=0,only plot ang-range; option=1, only generate the synthetic(merged) range-angle heatmap;
% option=2,only record raw data in format of matrix; option=3,ran+dop+angle estimate;
option = 0; 
IS_Plot_RD = true; % 1 ==> plot the Range-Doppler heatmap
IS_SAVE_Data = false;% 1 ==> save range-angle data and heatmap figure
Is_Det_Static = true;% 1==> detection includes static objects (!!! MUST BE 1 WHEN OPYION = 1)
Is_Windowed = false;% 1==> Windowing before doing angle fft
num_stored_figs = 50;% the number of figures that are going to be stored
cali_n = 5;
% the number of range bins that need to be calibrated
neidop_n = 3; % the number of neighbored bins around the selected the doppler

% generate file name and folder
file_name = 'adc_data_0.bin';

% configuration parameters
Fs = 4*10^6;
sweepSlope = 21.0017e12;
samples = 128;
loop = 255;
% loop = 128;
Tc = 120e-6; %us
fft_Rang = 128;
fft_Vel = 256;
fft_Ang = 91;

% size of bounding box
widthRec = 22.5;% degrees ==> pi/8
heigtRec = 2.5;% meters

%% Creat grid table
freq_res = Fs/fft_Rang;% range_grid
freq_grid = (0:fft_Rang-1).'*freq_res;
rng_grid = freq_grid*c/sweepSlope/2;% d=frediff_grid*c/sweepSlope/2;

w = [-180:4:180]; % angle_grid
agl_grid = asin(w/180)*180/pi; % [-1,1]->[-pi/2,pi/2]

% velocity_grid
dop_grid = fftshiftfreqgrid(fft_Vel,1/Tc); % now fs is equal to 1/Tc
vel_grid = dop_grid*lambda/2;   % unit: m/s, v = lamda/4*[-fs,fs], dopgrid = [-fs/2,fs/2]
% vel_grid=3.6*vel_grid;        % unit: km/h

%% read the data file
data = readDCA1000(file_name);
data_length=length(data);
data_each_frame=samples*loop*Tx*Rx;
Frame_num=data_length/data_each_frame;

caliDcRange_odd = [];
caliDcRange_even = [];
obj_pos = [];
obj_pos_value = [];
init_pos = [];

for i=frame_start:frame_end % 1:end frame, Note:start frame must be 1
    
    % reshape data of each frame to the format [samples, Rx, chirp]
    data_frame = data(:,(i-1)*data_each_frame+1:i*data_each_frame);
    data_chirp = [];
    for cj=1:Tx*loop
        temp_data = data_frame(:,(cj-1)*samples+1:cj*samples);
        data_chirp(:,:,cj) = temp_data;
    end
    chirp_odd = data_chirp(:,:,1:2:end);
    chirp_even = data_chirp(:,:,2:2:end);
    chirp_odd = permute(chirp_odd, [2,1,3]);
    chirp_even = permute(chirp_even, [2,1,3]);
    
    if option == 0
        %% plot ang-range and find the location of objects
        % FOR CHIRP 1
        % Range FFT
        [Rangedata_odd] = fft_range(chirp_odd,fft_Rang);
        
%         % caliDcRangeSig
%         [Rangedata_odd, caliDcRange_odd] = caliDcRangeSig(Rangedata_odd,i,frame_start,caliDcRange_odd,cali_n);
        % Check whether to plot range-doppler heatmap
        if IS_Plot_RD
            % Doppler FFT
            [Dopdata_odd] = fft_doppler(Rangedata_odd,fft_Vel);
            % plot range-doppler
            plot_rangeDop(Dopdata_odd,vel_grid,rng_grid)
        else
            
        end
        
%         FOR CHIRP 2
        % Range FFT
        [Rangedata_even] = fft_range(chirp_even,fft_Rang);
        
%         % caliDcRangeSig
%         [Rangedata_even,caliDcRange_even] = caliDcRangeSig(Rangedata_even,i,frame_start,caliDcRange_even,cali_n);
        
        % Angle FFT
        % need to do doppler compensation on Rangedata_chirp2 in future
        Rangedata_merge = [Rangedata_odd,Rangedata_even];
        Angdata = fft_angle(Rangedata_merge,fft_Ang,Is_Windowed);
        
        if i < frame_start + num_stored_figs % plot Range_Angle heatmap
            [axh] = plot_rangeAng(Angdata,rng_grid,agl_grid);
        end
        
        %             if i == frame_start % search the initial position of object
        %                 cur_pos = find_obj_position(Angdata,init_pos,1,Is_Det_Static);
        %                 init_pos = cur_pos;
        %                 obj_pos = [obj_pos;i,cur_pos]; % obj_pos list format [frame, range, angle]
        %                 obj_pos_value = [obj_pos_value;i,rng_grid(cur_pos(1)),agl_grid(cur_pos(2))];
        %             else % search the position of object in specific range(temporarily)
        %                 cur_pos = find_obj_position(Angdata,init_pos,0,Is_Det_Static);
        %                 init_pos = cur_pos;
        %                 obj_pos = [obj_pos;i,cur_pos]; % obj_pos list format [frame, range, angle]
        %                 obj_pos_value = [obj_pos_value;i,rng_grid(cur_pos(1)),agl_grid(cur_pos(2))];
        %             end
        
        if IS_SAVE_Data
            [Angdata] = Normalize(Angdata);
            % save range-angle heatmap to .mat file
            saved_file_name = strcat(saved_folder_name,'/',data_name,'_',num2str(i-frame_start,'%06d'),'.mat');
            eval(['save(saved_file_name,''Angdata'',''-v6'');'])
            
            if i < frame_start + num_stored_figs % plot rectangle
                posiObjCam = [agl_grid(cur_pos(2))-widthRec/2,rng_grid(cur_pos(1))-heigtRec/2];
                hold on
                plot_rectangle(posiObjCam,widthRec,heigtRec);
                % save to figure
                saved_fig_file_name = strcat(saved_fig_folder_name,'/','frame_',num2str(i,'%06d'),'.png');
                eval(['saveas(axh,saved_fig_file_name,''png'');'])
                close
            end
        end
        i % print index i
        
        %% igonre the following part currently
        %     elseif option == 1
        %         %% generate the synthetic(merged) range-angle heatmap
        %         for iS = 1:1
        %         if i > frame_start-1
        %             x_dop = [];
        %             x_dop_C = [];
        %
        %             % FOR CHIRP 1
        %             % Range FFT
        %             [Rangedata_chirp1] = fft_range(Xcube_chirp1,fft_Rang);
        %             % caliDcRangeSig,cali_n=3
        %             [Rangedata_chirp1,caliDcRange_chirp1] = caliDcRangeSig(Rangedata_chirp1,i,loop,frame_start,caliDcRange_chirp1,cali_n);
        %
        %             % FOR CHIRP 2
        %             % Range FFT
        %             [Rangedata_chirp2] = fft_range(Xcube_chirp2,fft_Rang);
        %             % caliDcRangeSig
        %             [Rangedata_chirp2,caliDcRange_chirp2] = caliDcRangeSig(Rangedata_chirp2,i,loop,frame_start,caliDcRange_chirp2,cali_n);
        %
        %             % Generate range-doppler heatmap for chirp1
        %             [Dopdata_chirp1] = fft_doppler(Rangedata_chirp1,fft_Vel);% Doppler FFT
        %             [Dopdata_chirp2] = fft_doppler(Rangedata_chirp2,fft_Vel);% Doppler FFT
        %
        %             if IS_Plot_RD
        %                 % plot range-doppler(with DC removal)
        %                 plot_rangeDop(Dopdata_chirp1,vel_grid,rng_grid)
        %             else
        %             end
        %
        %             Dop_sum = squeeze(sum(Dopdata_chirp1,2)/size(Dopdata_chirp1,2)); % Sum 4 receive antennas
        %
        %             % CFAR to detect all velocity component
        %             for rani = cali_n+1:fft_Rang  % from range 4(because the DC component in range1-3 have been canceled)
        %                 x_detected = cfar_ca1D(Dop_sum(rani,:),4,4,3.5,1);
        %                 x_dop = [x_dop,x_detected];
        %             end
        %
        %             % deal with the empty x_dop (CFAR didn't detect the object)
        %             if length(x_dop) == 0
        %                 % find the maximum velocity component in heatmap
        %                 [peak_pos] = find_2Dmax(Dop_sum,cali_n+1,fft_Rang,1,fft_Vel);
        %                 x_dop = [x_dop,[peak_pos(2),0,0]'];
        %             end
        %
        %             [x_dop_U,~,~] = unique(x_dop(1,:)); % make detecton result unique
        %
        %             for dopi = 1:length(x_dop_U) % add the neighbor bins
        %                 x_dop_C = [x_dop_C,[max(x_dop_U(dopi)-neidop_n,1):1:min(x_dop_U(dopi)+neidop_n,fft_Vel)]];
        %             end
        %
        %             [x_dop_CU,~,~] = unique(x_dop_C(1,:)); % make detecton result unique again
        %
        %             % Angele FFT
        %             Dopdata_merge = [Dopdata_chirp1,Dopdata_chirp2];
        %             Angdata = fft_angle(Dopdata_merge,fft_Ang,Is_Windowed);
        %
        %             % sum selected range-angle heatmaps, the indexes are in x_dop_CU
        %             Angdata_merge = sum(Angdata(:,:,x_dop_CU),3)/length(x_dop_CU);
        %             Angdata_merge_RemoveDC = (sum(Angdata(:,:,x_dop_CU),3) - Angdata(:,:,65))/(length(x_dop_CU) - 1);
        %
        %             % plot Range_Angle heatmap
        %             if i < frame_start + num_stored_figs
        %                 [axh] = plot_rangeAng(Angdata_merge_RemoveDC,rng_grid,agl_grid);
        %             end
        %
        %             if i == frame_start % search the initial position of object
        %                 cur_pos = find_obj_position(Angdata_merge_RemoveDC,init_pos,1,1);
        %                 init_pos = cur_pos;
        %                 obj_pos = [obj_pos;i,cur_pos]; % obj_pos list format [frame, range, angle]
        %                 obj_pos_value = [obj_pos_value;i,rng_grid(cur_pos(1)),agl_grid(cur_pos(2))];
        %             else % search the position of object in specific range(temporarily)
        %                 cur_pos = find_obj_position(Angdata_merge_RemoveDC,init_pos,0,1);
        %                 init_pos = cur_pos;
        %                 obj_pos = [obj_pos;i,cur_pos]; % obj_pos list format [frame, range, angle]
        %                 obj_pos_value = [obj_pos_value;i,rng_grid(cur_pos(1)),agl_grid(cur_pos(2))];
        %             end
        %
        %             if IS_SAVE_Data
        %                 [Angdata_merge] = Normalize(Angdata_merge);
        %                 % save range-angle heatmap to .mat file
        %                 saved_file_name = strcat(saved_folder_name,'/',data_name,'_',num2str(i-frame_start,'%06d'),'.mat');
        %                 eval(['save(saved_file_name,''Angdata_merge'',''-v6'');'])
        %
        %                 if i < frame_start + num_stored_figs % plot rectangle
        %                     posiObjCam = [agl_grid(cur_pos(2))-widthRec/2,rng_grid(cur_pos(1))-heigtRec/2];
        %                     hold on
        %                     plot_rectangle(posiObjCam,widthRec,heigtRec);
        %                     % save to figure
        %                     saved_fig_file_name = strcat(saved_fig_folder_name,'/','frame_',num2str(i,'%06d'),'.png');
        %                     eval(['saveas(axh,saved_fig_file_name,''png'');'])
        %                     close
        %                 end
        %             end
        %         i % print index i
        %         end
        %         end
        %     elseif option == 2
        %         %% record raw data in the form of matrix
        %         for ir = 1:1
        %             if i > frame_start-1
        %                 saved_file_name = strcat(data_name,'_',num2str(i,'%03d'),'.mat');
        %                 Xcube_chirp = [Xcube_chirp1,Xcube_chirp2];
        %                 eval(['save(saved_file_name,''Xcube_chirp'',''-v6'');']);
        %             else
        %             end
        %         end
        %     elseif option == 3
        %         %% ran+dop+angle estimate
        %         for ie = 1:1
        %         % chirp1
        %         % range fft
        %         [Rangedata_chirp1]=range_fft(Xcube_chirp1,fft_Rang,fft_Vel,fft_Ang);
        %
        %         % caliDcRangeSig
        %         for anti = 1:4
        %             if rem(i,20) == 1
        %                 caliDcRange(:,anti) = sum(squeeze(Rangedata_chirp1(:,anti,:)),2)/loop;
        %             else
        %             end
        %             % remove DC
        %             Rangedata_chirp1(1:3,anti,:) = Rangedata_chirp1(1:3,anti,:) - repmat(caliDcRange(1:3,anti),...
        %                 1,size(Rangedata_chirp1(1:3,anti,:),2),size(Rangedata_chirp1(1:3,anti,:),3));
        %         end
        %
        %         % doppler fft
        %         Dopdata_chirp1 = doppler_fft(Rangedata_chirp1,fft_Rang,fft_Vel,fft_Ang);
        %         figure()
        %         mesh(vel_grid,rng_grid,abs(squeeze(Dopdata_chirp1(:,1,:))));
        %         view(0,90)
        %         axis([-10,10,0,25])
        %         title('Range-doppler plot for Rx1')
        %         xlabel('doppler')
        %         ylabel('Range')
        %
        %         %for chirp2
        %         [Rangedata_chirp2]=range_fft(Xcube_chirp2,fft_Rang,fft_Vel,fft_Ang);
        %
        %         % caliDcRangeSig
        %         for anti = 1:4
        %             if rem(i,20) == 1
        %                 caliDcRange(:,anti) = sum(squeeze(Rangedata_chirp2(:,anti,:)),2)/loop;
        %             else
        %             end
        %             % remove DC
        %             Rangedata_chirp2(1:3,anti,:) = Rangedata_chirp2(1:3,anti,:) - repmat(caliDcRange(1:3,anti),...
        %                 1,size(Rangedata_chirp2(1:3,anti,:),2),size(Rangedata_chirp2(1:3,anti,:),3));
        %         end
        %
        %         % doppler fft
        %         Dopdata_chirp2 = doppler_fft(Rangedata_chirp2,fft_Rang,fft_Vel,fft_Ang);
        %         % sum
        %         Dopdata_sum = squeeze(sum(abs(Dopdata_chirp1)+abs(Dopdata_chirp2),2))/8;
        %
        %         for rani = 4:fft_Rang     %%% from range 4(because the DC component in range1-3 have been canceled)
        %             x_detected = cfar_ca1D(Dopdata_sum(rani,:),4,3,4,1);
        %             x_dop = [x_dop,x_detected];
        %         end
        %
        %         % make unique
        %         [C,~,~] = unique(x_dop(1,:));
        %
        %         % CFAR for each specific doppler bin
        %         for dopi = 1:size(C,2)
        %             y_detected = cfar_ca1D(Dopdata_sum(:,C(1,dopi)),4,4,3,0);
        %             if isempty(y_detected) ~= 1
        %                 Resl_indx_temp = [C(1,dopi)*ones(1,size(y_detected,2));y_detected];%%% 1st doppler, 2st range, 3st object power(log2), 4th estimated noise
        %                 Resl_indx = [Resl_indx,Resl_indx_temp];
        %             else
        %
        %             end
        %         end
        %
        %         % delete the nodes which has -inf noiseSum
        %         Resl_indx(:,isinf(Resl_indx(4,:))) = [];
        %
        %         % Angle FFT
        %         for angi = 1:size(Resl_indx,2)
        %             Dop_Antedata = [Dopdata_chirp1(Resl_indx(2,angi),:,Resl_indx(1,angi)),Dopdata_chirp2(Resl_indx(2,angi),:,Resl_indx(1,angi))];
        %             Angdata = angFFT(Dop_Antedata,fft_Ang);
        %             [~,I]=max(abs(Angdata));
        %             Resl_indx(5,angi) = I;
        %         end
        %         end
    else
        
    end
end

if IS_SAVE_Data
    dlmwrite(saved_pos_file_name,obj_pos_value);
end

