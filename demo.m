% This script provides data descriptions and analyses demos relevant to the
% Subcortex-GradientBased-Parcellation project
% Data for each section is located in each corresponding subfolder 
% Code is located in #functions#
% Group level hierachical parcellation for the subcortex is provided in
% #Group-Parcellation#. 

% Contact Ye Tian, yetianmed@gmail.com

%% 1.Compute subcortex-to-subcortex similarity matrix 

addpath ./MapGradient % example data
addpath ./masks
addpath ./functions/wishart
addpath ./functions 

% Subcortex mask 
insFile='subcortex_mask.nii';

% Gray matter mask
gmFile='GMmask.nii';

% Subject ID
SubID='100206';

% Gaussian smoothness in mm
FWHM=6; 

% Voxel size in mm
voxelsize=2; 

dataFile1=[pwd,'/MapGradient/rfMRI_REST1_LR_hp2000_clean.nii.gz'];% L-R phase encoding
dataFile2=[pwd,'/MapGradient/rfMRI_REST1_RL_hp2000_clean.nii.gz'];% R-L phase encoding

% fMRI signals from the two runs are concatenated 
fprintf('Computing similarity matrix\n')
s=compute_similarity(dataFile1,dataFile2,insFile,gmFile,FWHM,voxelsize);

save(['REST1_',SubID,'_s.mat'],'s');

%% 2.Map functional connectivity gradient

addpath ./MapGradient % example data and code
addpath ./masks
addpath ./functions % code

% Load group averaged similariy matrix. Alternatively, load individual data
% such as REST1_100206_s.mat to compute individual gradient map

% Subcortex mask
insFile='subcortex_mask.nii';
[~,ins_msk]=read(insFile);
ind_ins_org=find(ins_msk); % The original subcortical mask

% Load similarity matrix computed based on subcortex_mask.nii
load savg.mat savg

% Target subcortical region to compute gradient
% The input roiFile is a binary mask, which can be the entire subcortex or
% any subregions of interest
% For demo, we use the entire subcortex mask.
% Alternatively, try subcortex_mask_part1.nii
roiFile='subcortex_mask.nii';

Mag=0; % Mag=0; -> Print out slices, background image is eigenmap;
       % Mag=1; ->Print out slices, background image is gradient magnitude
       % Modify colormap in cont_model.m
Streamlines=1; % 1->Write out vector file for tensor; 0->do not compute

Vn=2; % order of eigenvector to compute.
      % Vn=2: 2nd eigenvector (Gradient 1)
      % Vn=3; 3rd eigenvector to compute (Gradient 2)
      % Vn=4; 4th eigenvector to compute (Gradient 3)
      
% Prefix name for output nii images
[~,name]=fileparts(roiFile);
Prefix=[name,'_Average_'];

% Compute gradient
% This function writes out two nii images including one eigenmap and one gradient
% magnitude 
% Write out a vector file when Streamlines=1
cont_model(savg,ind_ins_org,roiFile,Mag,Streamlines,Prefix,Vn)

%% 3.fMRI tractography

addpath ./fMRI-tractography % example data and code
addpath ./functions % code

% Fit tensor into the estimated gradient field then do tractography

% Example vector file for gradient 1
vectorFile='subcortex_mask_Average_Vn2_VectorFile.mat';
load(vectorFile,'Gx_org','Gy_org','Gz_org');
% in this file, 'Gx_org','Gy_org','Gz_org' is in MNI152 space (91x109x91);
% in this file,''gx','gy','gz' is in cropped space (see full2cropped.m)
% either of them can be used to generate tensor

% Symmetrize vectors across two hemisphere, optional, negligible difference 
Symmetrize=1; 
if Symmetrize
    [Gx_org,Gy_org,Gz_org]=symmetrize_vector(Gx_org,Gy_org,Gz_org);   
end

% Convert vector to tensor
[img,msk]=vector2tensor(Gx_org,Gy_org,Gz_org);

% Write out tensor image and mask
[~,name]=fileparts(vectorFile);
fprintf('Write out %s\n',[name,'_tensor.nii'])
mat2nii(img,[name,'_tensor.nii'],size(img),32,'subcortex_mask.nii');
fprintf('Write out %s\n',[name,'_mask.nii'])
mat2nii(msk,[name,'_mask.nii'],size(msk),32,'subcortex_mask.nii'); 
fprintf('Next: do tractography using Diffusion Toolkit\n')

% If visulize tensors in MRtrix
img_mrtrix=tensor_model_2(Gx_org,Gy_org,Gz_org);
fprintf('Write out %s\n',[name,'_tensor_model_2.nii'])
mat2nii(img_mrtrix,[name,'_tensor_model_2.nii'],size(img_mrtrix),32,'subcortex_mask.nii');
fprintf('Next, visulize tensors in MRtrix software\n')

%% 4.Diversity curves

addpath ./fMRI-tractography % example data 
addpath ./functions % code

% Project gradient magnitude onto streamlines 
% Compute the distance between each pair of streamlines
% Diversity curves were genertated for dorsal and ventral group of streamlines
% For demo, we show ventral only which is the group of streamlines propogated in
% subcortex_mask_part1.nii: hippocampus+thalamus+amygdala

TrackFile='subcortex_mask_part1_Average_Vn2_VectorFile.trk'; % Streamlines genarated by Diffusion Toolkit
Lthresh=160; %Length threshold of streamlines. Streamlines shorted than Lthresh are discarded. The value is flexible based on the actual streamlines 
J=300; % Depends on the length of streamlines. Works well here.
% It is time consuming to compute the distance 
% For demo, distance is preloaded
Preload=1;
if Preload
    load subcortex_mask_part1_track_distance.mat M dsym voxelsize
    % M: coordinates (xyz) for each streamline
    % dsym: distance matrix between each pair of streamlines
    % voxelsize in mm
else
    [M,dsym,voxelsize]=track_clust(TrackFile,Lthresh,J);

end

% Map diversity curve for gradient magnitude 
% Symmetrized gradient magnitude
magFile='subcortex_mask_part1_Average_Vn2_magnitude_symmetric.nii';

% Eigenmap 
eigFile='subcortex_mask_part1_Average_Vn2_eigenvector.nii';

% Check the distribution of distance to determine the threshold
ThreshDist=1; 
[dcurve_mag_clust1_avg,dcurve_eig_clust1_avg,length_x1]=diversity_curve(M,dsym,J,voxelsize,magFile,eigFile,ThreshDist);
% dcurve_mag_clust1_avg: diversity curve mapped for gradient magnitude
% dcurve_eig_clust1_avg: diversity curve mapped for eigenmap
% length_x1: length of streamline in mm

%% 5.Geometry-preserving null model

addpath ./GeoNull
addpath ./masks
addpath ./MapGradient
addpath ./functions

% Generate null data to set expections of gradient magntitude due to chance 
% As demo, we show one example:
% Null model with diversity curves
% subcortex_mask_part1.nii which includes thalamus hippocampus and amygadala. 

roiFile='subcortex_mask_part1.nii';
[~,name]=fileparts(roiFile);

NumNull=100;% Number of randomizations
load savg.mat savg

% This part is time consuming
% For demo, computed null data is preloaded
Preload=1;
if Preload
    load GradmNull_subcortex_mask_part1.mat img_mag_null
else
    img_mag_null=gradmNull(savg,roiFile,NumNull); 
    save(['GradmNull_',name,'.mat'],'img_mag_null');   
end

% Write out 4D nii image for visulization
mat2nii(img_mag_null,['GradmNull_',name,'.nii'],size(img_mag_null),32,roiFile);

%% 6.Plot diversity curves: Observed vs Null

addpath ./GeoNull

% Use the function diversity_curve.m, 100 null diversity curves can be mapped.
% Load example data
load dcurve_avg_vn2_null_part1.mat

% Delete the first and last 10 points avoiding edge effect
% Actual data
dcurve_mag_clust1_avg=dcurve_mag_clust1_avg(10:end-11,:);
dcurve_eig_clust1_avg=dcurve_eig_clust1_avg(10:end-11,:);

% Null data
dcurve_mag_clust1_avg_all=dcurve_mag_clust1_avg_all(10:end-11,:);
dcurve_eig_clust1_avg_all=dcurve_eig_clust1_avg_all(10:end-11,:);

%Compute the 95% CI across randomizations
cnt_lower=round(size(dcurve_eig_clust1_avg_all,2)*0.025);
cnt_upper=round(size(dcurve_eig_clust1_avg_all,2)*0.975);
for j=1:size(dcurve_eig_clust1_avg_all,1)
    
    %Eigenmap
    eig=dcurve_eig_clust1_avg_all(j,:);
    [~,ind_eig_srt]=sort(eig);
    eig_lower(j)=eig(ind_eig_srt(cnt_lower));
    eig_upper(j)=eig(ind_eig_srt(cnt_upper));
    
    %Gradient magnitude
    mag=dcurve_mag_clust1_avg_all(j,:);
    [~,ind_mag_srt]=sort(mag);
    mag_lower(j)=mag(ind_mag_srt(cnt_lower));
    mag_upper(j)=mag(ind_mag_srt(cnt_upper));     
end
dcurve_eig_clust1_avg_all_se=[mean(dcurve_eig_clust1_avg_all,2)-eig_lower',...
    eig_upper'-mean(dcurve_eig_clust1_avg_all,2)];
dcurve_mag_clust1_avg_all_se=[mean(dcurve_mag_clust1_avg_all,2)-mag_lower',...
    mag_upper'-mean(dcurve_mag_clust1_avg_all,2)];

hf=figure;hf.Color='w';hf.Position=[100,200,300,200];
fontsize=12;
L=300;
Linewidth=2.5;
Color_clust1=[128,128,128]/255;% Gray 
step_length=length_x1(end)/L; % The last streamline is the representative streamline-x1_ref
x=([1:size(dcurve_mag_clust1_avg_all,1)]'-1)*step_length; % convert to mm
mycolormap=dlmread('trackvis_jet.txt');

% Null data
boundedline(x,mean(dcurve_mag_clust1_avg_all,2),dcurve_mag_clust1_avg_all_se,'-','cmap',Color_clust1,'alpha'); hold on

% Observed data
y=dcurve_mag_clust1_avg;
z=dcurve_eig_clust1_avg;
surf([x(:) x(:)], [y(:) y(:)], [z(:) z(:)], ...  % Reshape and replicate data
     'FaceColor', 'none', ...    % Don't bother filling faces with color
     'EdgeColor', 'interp', ...  % Use interpolated color for edges
     'LineWidth', Linewidth);    % Make a thicker line
view(2);   % Default 2-D view
colormap(mycolormap) 
caxis([0,0.05]);
ax=gca;
set(gca,'FontSize',fontsize);
ax.Box='off';
xlabel('mm');ylabel('Gradient magnitude')
ax.XTick=[0:20:160];
xlim([0,max(x)])

% Mark the local maxima %
[pks1,locs1]=findpeaks(dcurve_mag_clust1_avg,'MinPeakProminence',0.0001,...
    'Annotate','extents'); hold on
locs1=(locs1'-1)*step_length; 
plot(locs1,pks1+0.004,'vk','MarkerFaceColor','k','MarkerSize',5);
hl=legend({'Null-95%CI','Null-mean'},'Location','northeast','box','off');grid on;

%% 7.Parcellation via watershed transform algorithm

addpath ./Group-Parcellation
addpath ./functions

% Load example data in cropped space
gradmfile='subcortex_mask_part1_Average_Vn2_magnitude_symmetric.nii';
[~,gradm]=read(gradmfile); 

% Only analyse the right hemisphere
mid=size(gradm,1)/2;
gradm_rh=zeros(size(gradm));
gradm_rh(1:mid,:,:)=gradm(1:mid,:,:);
gradm=gradm_rh;
sub_msk_rh=~~gradm;

% Specify the center of each cluster (x,y,z)
% Do not need to be exact
cr=[12 15 16; % anterior thalamus
    10 9 15; % posterior thalamus
    5 14 3; % hippocampus
    5 19 4];% amygdala
cr=cr+1; c=cr;

% Normalize gradient image to ensure all values are between 0 and 1
gradm = double(gradm-min(gradm(:)))/(max(gradm(:)-min(gradm(:))));
zslice=[13 14 15 16];
draw_slices(gradm,'Gradient Image',zslice); 

%set the voxels outside the subcortex to a large value
ind=find(sub_msk_rh==0); 
msk=zeros(size(sub_msk_rh));
msk(ind)=1; 
gradm(ind)=0.5;  

% Generate an image with 1 at each centre and 0 elswhere
img_mins=zeros(size(gradm)); 
for i=1:size(c,1)
    img_mins(c(i,1),c(i,2),c(i,3))=1; 
end

% Set the local minima in the gradient image at the centre of each voxel
gradm = imimposemin(gradm,img_mins); 

% Check that local minima have been added
regmin=imregionalmin(gradm); 
cc=bwconncomp(regmin); 
fprintf('Number of local minima %d\n',cc.NumObjects); 

% Run watershed
ws=watershed(gradm);  
img_labels=double(ws).*double(~msk);
draw_slices(img_labels,'Clusters',zslice); colormap jet; 
fprintf('Number of regions in watershed: %d\n',length(unique(img_labels))-1);

% Expand the clusters so that there is no gap between clusters
% 6 neighbours 
Ngh=[0 0 1; 0 0 -1; 0 1 0; 0 -1 0; 1 0 0; -1 0 0];
fprintf('Expanding...\n')
img_labels=expand(msk,img_labels,Ngh,c);
draw_slices(img_labels,'Clusters (Expanded)',zslice); colormap jet;

% Write out subregions
mat2nii(img_labels,'part1_subregions.nii',size(img_labels),32,gradmfile);

% Map back to original MNI space (Optional)
img_new=cropped2full('part1_subregions.nii','subcortex_mask_part1.nii');
mat2nii(img_new,'part1_subregions_full.nii',size(img_new),32,'subcortex_mask_part1.nii') 

%% 8.Homogeneity estimation

addpath ./Homogeneity
addpath ./functions
addpath ./masks

% Example:
% Compute the mean homogeneity for Level 2 parcellation and its matched random
% parcellations for single subject (SubID 100206)
% Use REST2 session fMRI data
mskFile=[pwd,'/Group-Parcellation/3T/subcortex_parcellation_L2_3T.nii'];

% Generate random parcellations with overall matched parcel size and shape
% to the empirical parcellation
MM=100; % Number of randomizations
parcels_random_all=random_parcels(mskFile,MM);

% Save parcellation specific random parcels
[~,Prefix]=fileparts(mskFile);
parcelFile=['random_parcels_',Prefix,'.mat'];
save(parcelFile,'parcels_random_all');

% Gray matter mask
gmFile='GMmask.nii';

% Gaussian smoothness in mm
FWHM=6; 

% Voxel size in mm
voxelsize=2; 

dataFile1=[pwd,'/Homogeneity/rfMRI_REST2_LR_hp2000_clean.nii.gz'];% L-R phase encoding
dataFile2=[pwd,'/Homogeneity/rfMRI_REST2_RL_hp2000_clean.nii.gz'];% R-L phase encoding

% Compute mean homogeneity
[exp_avg,exp_avg_null,z]=do_homogeneity(dataFile1,dataFile2,mskFile,parcelFile,gmFile,MM,FWHM,voxelsize);
% exp_avg: mean homogeneity for the empirical parcellation 
% exp_avg_null: mean homogeneity for random parcellattions
% Repeat this process for all subjects (n=1021) with REST2 session data
% See ./examples/subcortex_parcellation_L2_3T_homogeneity.mat

%% 9.Individual parcellation

addpath ./Individual-Parcellation

% Train SVM classifier based on group parcellation and then predict
% indiviudal parcellation

% Group parcellation
mskFile=[pwd,'/Group-Parcellation/3T/subcortex_parcellation_L4_3T.nii'];
[~,parc]=read(mskFile);

%Extent of dilation (integer value)
DilThresh=2; %Dilate 2 voxels

ind=find(parc);
regs=unique(parc(ind));

Nxyz=size(parc);  %image size
N=length(regs);   %number of regions

fprintf('Dilating each region...\n');
se=strel('sphere',DilThresh);
img_dil=cell(N,1);
rdil=zeros(N,1);
for i=1:N
    ind_reg=find(regs(i)==parc);
    img=zeros(Nxyz);
    img(ind_reg)=1;
    
    %0: not considered, 1: other regions, 2: region of interest
    img_dil{i}=imdilate(img,se).*~~parc+img;
    rdil(i)=sum(~~img_dil{i}(:))/sum(img(:));
end
fprintf('Dilated-to-original ratio (voxels): %0.2f (min: %0.2f, max: %0.2f)\n',mean(rdil),min(rdil),max(rdil));

% Train SVM classifer 
% Random selected training samples (n=100)
load SVM_Subjects.mat subject_train

% similariry matrix in training samples
% sFiles is a string variable with a list of name for the similarity data for
% all the training samples
% Load each sFile sequencially in svm_train.m for the sake of memory
for i=1:length(subject_train)
    sFiles{i}=[num2str(subject_train(i)),'_s.mat'];
end

% This part is time consuming
reg=1;% 1->N,region to train
Preload=1;
if Preload
    % Load example data
    % NOTE: This preloaded classifer was trained based on the similarity matrix
    % from an old version of subcortex mask, which is slightly larger than proposed parcellation. 
    % The old version of subcortex mask is called 
    % subcortex_mask_Thresh47_symmetric_union.nii provided in ./examples
    fprintf('Loading precomputed SVM classifer for region %d\n',reg);
    load region1_Dil2_train.mat Out img_dil ind
else
    Out=svm_train(subject_train,sFiles,reg,ind);
    save(['region',num2str(reg),'_Dil',num2str(DilThresh),'_train.mat'],'Out','img_dil','ind','-v7.3');
end

% Predict individual parcellation
% Testing samples
load SVM_Subjects.mat subject_test;

% Load example data 
% Similarity matrix for one testing subject
SubID='100206';
load REST2_100206_s.mat s

% Compute the probabilistic map 
img_dil=img_dil{reg};
[y_img,dice]=svm_test(img_dil,Out,s,ind);
mat2nii(y_img,'region1_probmap_100206.nii',size(y_img),32,mskFile);
fprintf('region %d,subject %s,Dice=%.2f\n',reg,SubID,dice)

%% 10. Behavioral analysis 

addpath ./Behavior

% Dimensionality reduction using ICA 
% Load data
load ica5_final_Regress1_NumBot500.mat
% w_final: demixing matrix, weights of individual item on each component
% s_final: component score for every individual
% maglist: subject ID
% header3: name of 109 behavioral item that contributes to ICA 
% A spreadsheet version of s_final with subject ID is also provided,see 
% ./Behavior/behavioral_components.xlsx

% Label for each behavioral dimension
labels={'Cognition','Illicit Substance Use','Tobacco Use','Personality-Emotion','Mental Health'};

% Plot demixing matrix
hf=figure; hf.Color='w'; hf.Position=[50,50,500,650];
ha=tight_subplot(1,5,[.005 .01],[.05 .01],[.4 .01]);
for i=1:5
    axes(ha(i));
    imagesc(w_final(i,:)',[-0.2,0.2]);
    ha(i).XTick=[];
    ha(i).TickLength=[0,0];
    if i==1
        ha(i).YTick=[1:size(w_final,2)];
        ha(i).FontSize=6;
        ha(i).TickLength=[0,0];
        ha(i).YTickLabel=header3;
    end
    if i>1
        ha(i).YTick=[];
    end
    
    xlabel(['IC',num2str(i)],'FontSize',12);
end
%% 11.Test subcortical networks correlates of behaviors using Network-based statistic(NBS) toolbox (Zalesky et al 2010)







