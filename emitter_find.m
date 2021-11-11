images_EMCCD = data.data.data.images_EMCCD;
% P1=sum(sum(images_EMCCD(:,:,:)))/(512*512);
% P2=squeeze(P1);
% plot(P2)
size_EMCCD = size(images_EMCCD);
n_images = size_EMCCD(3);

emitter_kernel=[1 4 7 4 1;4 16 26 16 4;7 26 41 26 7; 4 16 26 16 4;1 4 7 4 1]/273;
emitter_kernel2=[-1 -1 -1 -1 -1;-1 1 1 1 -1; -1 1 8 1 -1; -1 1 1 1 -1; -1 -1 -1 -1 -1];

emitter_kernel3D=zeros(5,5,5);
emitter_kernel3D(:,:,1)=-2*emitter_kernel2;
emitter_kernel3D(:,:,2)=emitter_kernel2;
emitter_kernel3D(:,:,3)=2*emitter_kernel2;
emitter_kernel3D(:,:,4)=emitter_kernel2;
emitter_kernel3D(:,:,5)=-2*emitter_kernel2;

emitter_cov3D=convn(images_EMCCD,emitter_kernel3D);
emitter_cov3D=emitter_cov3D(3:514,3:514,3:303);
% for i=1:n_images
%     imagesc(emitter_cov3D(:,:,i));
%     title(num2str(i))
%     waitforbuttonpress
% end
figure(1)
wl=load('Z:\Experiments\Diamond\EG313_1108\Image2021_11_02_22_10_31');
imagesc(wl.images_EMCCD)



%%
% emitter_flag=zeros(1,n_images);
% 
% figure(2)
% imagesc(data.data.data.images_EMCCD(:,:,59))
% waitforbuttonpress
% imagesc(data.data.data.images_EMCCD(:,:,81));
% waitforbuttonpress
% 
% emitter_cov=conv2(data.data.data.images_EMCCD(:,:,81),emitter_kernel);
% imagesc(emitter_cov);
% 
% waitforbuttonpress
% emitter_cov=conv2(emitter_cov(3:514,3:514),emitter_kernel2);
% emitter_cov=emitter_cov(3:514,3:514);
% imagesc(emitter_cov);
% for i=1:n_images
%     imagesc(data.data.data.images_EMCCD(:,:,i))
%     title(num2str(i))
%     waitforbuttonpress
% end
%%
figure(3)



a=[];
pmax=[];
for i=1:n_images
%     emitter_cov=conv2(data.data.data.images_EMCCD(:,:,i),emitter_kernel);
% %     emitter_cov=emitter_cov(3:514,3:514);
%     emitter_cov=conv2(emitter_cov(3:514,3:514),emitter_kernel2);
%     emitter_cov=emitter_cov(3:514,3:514);
    if 8*sum(sum((abs(emitter_cov3D(:,:,i)))))/(512*512)<max(max(emitter_cov3D(:,:,i)))
        emitter_flag(i)=1;
        a=[a;i];
        pos=find(emitter_cov3D(:,:,i)==max(max(emitter_cov3D(:,:,i))));
        pmax=[pmax;floor(pos/512) pos-512*floor(pos/512)];
    else
        emitter_flag(i)=0;
    end
end
emitter_flag;
a
pmax

for i=1:size(a)
    imagesc(data.data.data.images_EMCCD(:,:,a(i)))
    title(num2str(a(i)))
    waitforbuttonpress
    imagesc(data.data.data.images_EMCCD(:,:,a(i)))
    title(num2str(a(i)))
    hold on
    scatter(pmax(i,1),pmax(i,2),100,'r')
    hold off
    waitforbuttonpress
    imagesc(emitter_cov3D(:,:,a(i)))   
    title(num2str(a(i)*100))
    waitforbuttonpress
end


% sum(sum(emitter_cov))
% imagesc(emitter_cov)