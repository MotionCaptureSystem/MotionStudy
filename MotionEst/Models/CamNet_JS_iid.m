function [y_bark, Qk] = CamNet_JS_iid(x_k, camstruct, options)

nstates = length(x_k);
link    = options.link;
groups  = unique([link.Group]);
g_max   = max(groups);
nDof    = 0;
links   = [];
for gg = 1:g_max
    %links = [get_group_links(link,gg)];
    links = [links,get_group_links(link,gg)];
    %nDof = nDof + sum([link(links).nDof]);
    nDof = sum([link(links).nDof]);
    if nDof == nstates
        g_max = gg;
        break
    end
end

if g_max>1
    last_group_links = get_group_links(link,g_max-1);
    last_group_links = 1:last_group_links(end);
else
    last_group_links = [];
end

links = setdiff(links,last_group_links);

cams = options.est.cams;

ncam = length(cams);
nmeas = ncam*length([link(links).MeasInds]);

Pi0 = [1,0,0,0;0,1,0,0;0,0,1,0];
z_hat = [0;0;1;0];
if isempty(link(links(1)).BFvecs)
    MeasStart = link(links(2)).MeasInds(1);   
else
    MeasStart = link(links(1)).MeasInds(1);            
end

%Grab a mean
y_bark = zeros(nmeas,1);
%Qk = 1*eye(length(y_bark));
Qk = zeros(length(y_bark));
%uncert = 2*[1:length(links)];
%uncert = logspace(0,3,length(links));
%uncert = {[1,1,1],[1,1],[3,1],[3,3,3],[3,3],[8,5,3],[8,5,3],[8,3]};
uncert = {[1,1,1],[1,1,1],[1,1,1],[1,1,1,1],[1,1,1],[1,1,1,1],[1,1,1,1],...
          [1,1,1],[1,1,1],[1,1,1,1],[1,1,1],[1,1,1,1],[1,1,1,1],[1,1,1],[1,1,1],...
          [1,1,1],[1,1,1],[1,1,1,1],[1,1,1],[1,1,1,1],[1,1,1,1],[1,1,1],[1,1,1],[1,1,1],[1,1,1],[1,1,1],[1,1,1]};
scale=5;

uncert = cellfun(@(x) x*scale,uncert,'un',0);
%uncert = {[1,1,1],[3,1],[3,3,3],[3,3],[8,5,3],[8,5,3],[8,3]};
%uncert = {[1,1,1,1,1],[1],[1],[1],[1],[1],[1]};
for cc = 1:ncam         %for each camera
    Hin = invH(camstruct(cams(cc)).H);
    cnt = 0;
    for ll = links
        cnt = cnt+1;
        nvecs = size(link(ll).BFvecs,2);
        H_ll = HTransform(x_k(1:sum([link([last_group_links,links(1:cnt)]).nDof]),1),link);
        %H_ll = HTransform(x_k,link);
        for pp = 1:nvecs
            x_lpi = [link(ll).BFvecs(:,pp);1];
            %Determine predicted range to point
            lambda = z_hat'*Hin*H_ll*x_lpi; 
            %Determine Sensor Model Jacobian
            ndx = nmeas/ncam*(cc-1)+link(ll).MeasInds(2*pp-1:2*pp)-MeasStart+1;
            y_bar_int = 1/lambda*camstruct(cams(cc)).K*Pi0*Hin*H_ll*x_lpi;
            y_bark(ndx) = y_bar_int(1:2)/y_bar_int(3);
%             p = [camstruct(cams(cc)).foc_l;
%                  camstruct(cams(cc)).skew; 
%                  camstruct(cams(cc)).prin_p;
%                  camstruct(cams(cc)).om;
%                  camstruct(cams(cc)).T];
%             sigpvec = [(camstruct(cams(cc)).foc_l_e/3).^2;
%                        (camstruct(cams(cc)).skew_e/3).^2; 
%                        (camstruct(cams(cc)).prin_p_e/3).^2;
%                        (camstruct(cams(cc)).om_e/3).^2;
%                        (camstruct(cams(cc)).T_e/3).^2];
%             Jp = dhdp_mfile([p; x_lpi]);
% 
%             Q2 = Jp*diag(sigpvec)*Jp';
% 
%             uncertainty_increase_factor = 1.2;
%             % multiply by this to increase uncertainty due to unmodeled things
%             % (uncertainty in distortion, higher-order-uncertainty, etc)
             link_inds = links == ll;
%              if ismember(ll,last_group_links)
                Qk(ndx,ndx) = uncert{ll}(pp)* eye(length(ndx));
%              else
%                 Qk(ndx,ndx) = 0.000001*eye(length(ndx),length(ndx)); 
%              end
        end
    end
end
