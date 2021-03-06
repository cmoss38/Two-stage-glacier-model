clear all;
close all;clc

%% Parameters
%%Set Grid Resolution
parameters.grid.n_nodes = 1000;      %Horizontal Resolution
parameters.grid.n2_nodes = 40;
parameters.grid.gz_nodes = 203;      %Horizontal Resolution in grounding zone
parameters.grid.sigma_gz = 0.97;
parameters.Dupont_G = 0;          %lateral shear stress

parameters.year = 3600*24*365;                     %length of a year in seconds
parameters.tfinal = 100e3.*parameters.year;          %total time of integration
parameters.nsteps = 100e3;                           %number of time steps

parameters.accumrate = 0.5./parameters.year;
% parameters.accum_new = 0.48/parameters.year;
parameters.accum_mean = parameters.accumrate;
parameters.accum_std = 0.1./parameters.year;

parameters.buttress = 0.4;
parameters.buttress_mean = parameters.buttress;
parameters.buttress_std = 0;

parameters.C_schoof = 7.624e6;      %See Schoof (2007)
parameters.C_mean   = parameters.C_schoof;
parameters.C_std    = 0*parameters.C_mean;

parameters.C_noise_list = parameters.C_std.*randn(parameters.nsteps,1);
parameters.buttress_noise_list = parameters.buttress_std.*randn(parameters.nsteps,1);
parameters.accum_noise_list = parameters.accum_std.*randn(parameters.nsteps,1);

parameters.icedivide = 0;
parameters.bedslope = -3e-3;
parameters.sill_min = 3000e3;
parameters.sill_max = 3010e3;
parameters.sill_slope = 1e-4;
parameters.sin_amp = 0;
parameters.sin_length = 10e3;

%%Time step parameters
parameters.dtau = parameters.tfinal/parameters.nsteps; %length of time steps
parameters.dtau_max = parameters.dtau;

%%Newton Parameters
parameters.HS_sensitivity = pi*parameters.year;     %sensitivity of the HS function (as this gets larger, theta approaches the actual HS function)
parameters.uverbose = 1;
parameters.iteration_threshold = 1e-3;
parameters.hiter_max=1e3;
parameters.uiter_max=5e2;
parameters.titer_max=4e1;
parameters.CFL=50;

%%Grid Parameters
parameters.grid.n_elements = parameters.grid.n_nodes-1;           %number of finite elements (= n_nodes-1 in 1-D), h and N have length n_elements
% parameters.grid.sigma_node = linspace(0,1,parameters.grid.n_nodes)';  %node positions scaled to (0,1)
% parameters.grid.sigma_node = flipud(1-linspace(0,1,parameters.grid.n_nodes)'.^parameters.grid.n_exponent); %node positions scaled to (0,1) with refinement near GL
parameters.grid.sigma_node = [linspace(0,0.97,parameters.grid.n_nodes-parameters.grid.gz_nodes),linspace(0.97+(.03/parameters.grid.gz_nodes),1,parameters.grid.gz_nodes)]'; %node positions scaled to (0,1) with refinement near GL
parameters.grid.sigma_element =...
    (parameters.grid.sigma_node(1:parameters.grid.n_nodes-1)+...
    parameters.grid.sigma_node(2:parameters.grid.n_nodes))/2;     %element centres scaled to (0,1)

parameters.grid.n2_elements = parameters.grid.n2_nodes-1;           %number of finite elements (= n_nodes-1 in 1-D), h and N have length n_elements
parameters.grid.eta_node = linspace(0,1,parameters.grid.n2_nodes)';  %eta node positions scaled to (0,1)
parameters.grid.eta_element =...
    (parameters.grid.eta_node(1:parameters.grid.n2_nodes-1)+...
    parameters.grid.eta_node(2:parameters.grid.n2_nodes))/2;     %eta element centres scaled to (0,1)

%%Glen's Law parameters
parameters.B_Glen = (4.227e-25^(-1/3)).* ones(parameters.grid.n_elements,1);                     %B in Glen's law (vertically averaged if necessary)
parameters.n_Glen = 3;

%%Physical parameters
parameters.rho = 917;  %917                                 %ice density
parameters.rho_w = 1028;  %1028                               %water density
parameters.g = 9.81;                                    %acceleration due to gravity
parameters.D_eps = 1e-10;                               %strain rate regularizer
parameters.u_eps = 1e-9;                %velocity regularizer
parameters.u_in = 0./parameters.year; 

%%Sliding Law Parameters
parameters.frictionlaw = 'Weertman';

parameters.C_schoof = 7.624e6;      %See Schoof (2007)
parameters.m_schoof = 1/3;          %See Schoof (2007)

parameters.B_shear = 0;
parameters.width_shear = 1e3;

parameters.float = 1;

rho_i = parameters.rho;
rho_w = parameters.rho_w;

g = parameters.g;
n = parameters.n_Glen;
m = parameters.m_schoof;

year = parameters.year;
accum = parameters.accumrate;
% accum_new = parameters.accum_new;

A_glen =(parameters.B_Glen(1).^(-3));
C = parameters.C_schoof;
% h0 = 2710;
% h0 = 5000;

theta0 = 1-parameters.buttress;
omega = ((A_glen*(rho_i*g)^(n+1) * (1-(rho_i/rho_w))^n / (4^n * C))^(1/(m+1))) * theta0^(n/(m+1));
beta = (m+n+3)/(m+1);
lambda = rho_w/rho_i;

gz_frac = 1;

%NL Model
tf = parameters.tfinal;
nt = parameters.nsteps;
dt = tf/nt;

h=1000;
xg = 500e3; %initial guess

%run to steady state first
for t = 1:2e5 %100kyr to steady state
    b = Base(xg,parameters);
    bx = dBasedx(xg,parameters);
    omega = ((A_glen*(rho_i*g)^(n+1) * (1-(rho_i/rho_w))^n / (4^n * C))^(1/(m+1))) * theta0^(n/(m+1));
    
    hg = -(rho_w/rho_i)*b;
    Q = (rho_i*g/(C*gz_frac*xg))^n * (h^(2*n + 1));
   
    Q_g = omega*(hg^beta);
    
    dh_dt = accum - (Q/xg) - (h/(xg*hg))*(Q-Q_g);
    dxg_dt = (Q-Q_g)/hg;

    h = h + dh_dt*4*year;
    xg = xg + dxg_dt*4*year;
    xgs_nl(t) = xg;
    
end
xg_orig = xg;
b_orig = b;
hg_orig = hg;
h_orig = h;

%% Steady state

parameters.bedslope = -1.5*hg_orig/(beta*lambda*xg_orig);
parameters.icedivide = b_orig-(parameters.bedslope*xg_orig);

for t = 1:2e4 %100kyr to steady state
    b = Base(xg,parameters);
    bx = dBasedx(xg,parameters);
    omega = ((A_glen*(rho_i*g)^(n+1) * (1-(rho_i/rho_w))^n / (4^n * C))^(1/(m+1))) * theta0^(n/(m+1));
    
    hg = -(rho_w/rho_i)*b;
    Q = (rho_i*g/(C*gz_frac*xg))^n * (h^(2*n + 1));
   
    Q_g = omega*(hg^beta);
    
    dh_dt = accum - (Q_g/xg) - (h/(xg*hg))*(Q-Q_g);
    dxg_dt = (Q-Q_g)/hg;

    h = h + dh_dt*4*year;
    xg = xg + dxg_dt*4*year;
    xgs_nl(t) = xg;
    
end

xg_orig = xg;
b_orig = b;
hg_orig = hg;
h_orig = h;

% %% Response to step in accumulation for different slopes
% 
% tss_stab_slow = -hg_orig/(beta*lambda*xg_orig);
% 
% nlines = 6;
% 
% mts = [linspace(3,0.5,nlines-1),12];
% clr = lines(nlines);
% 
% accum = accum*0.99;
% for j = 1:length(mts)
% 
%     
%     parameters.bedslope = mts(j)*tss_stab_slow;
%     parameters.icedivide = b_orig-(parameters.bedslope*xg_orig);
% 
%     xg = xg_orig;
%     h = h_orig;
%     xgs_nl = xg;
% 
%     for t = 1:2e4 %100kyr to steady state
% 
%         b = Base(xg,parameters);
%         bx = dBasedx(xg,parameters);
%         omega = ((A_glen*(rho_i*g)^(n+1) * (1-(rho_i/rho_w))^n / (4^n * C))^(1/(m+1))) * theta0^(n/(m+1));
% 
% 
%         hg = -(rho_w/rho_i)*b;
%         Q = (rho_i*g/(C*gz_frac*xg))^n * (h^(2*n + 1));
% 
%         Q_g = omega*(hg^beta);
% 
%         dh_dt = accum - (Q/xg) - (h/(xg*hg))*(Q-Q_g);
%         dxg_dt = (Q-Q_g)/hg;
% 
%         h = h + dh_dt*1*year;
%         xg = xg + dxg_dt*1*year;
%         xgs_nl(t) = xg;
% 
% 
% 
%     end
% 
%     figure(1);plot(linspace(0,t./1e3,length(xgs_nl)),(xgs_nl-xg_orig)./1e3,'Color',clr(j,:),'linewidth',4);hold on;
% end
% 
% set(gca,'fontsize',24)
% xlabel('Time (kyr)','fontsize',24)
% ylabel('Grounding Line Excursion (km)','fontsize',24)

%% Response to initial GL perturb for different slopes

tss_stab_slow = -hg_orig/(beta*lambda*xg_orig);
tss_stab_fast = (hg_orig/(beta*lambda*xg_orig))*(3*n+1);

mts = 1.5:-0.5:0.5;
clr = ['b';'r';'m'];

for j = 1:length(mts)

    xg = xg_orig+2e3;
    h = h_orig;
    xgs_nl = xg;
    
    parameters.bedslope = mts(j)*tss_stab_slow;
    parameters.icedivide = b_orig-(parameters.bedslope*xg_orig);

 
    for t = 1:2e4 %100kyr to steady state

        b = Base(xg,parameters);
        bx = dBasedx(xg,parameters);
        omega = ((A_glen*(rho_i*g)^(n+1) * (1-(rho_i/rho_w))^n / (4^n * C))^(1/(m+1))) * theta0^(n/(m+1));


        hg = -(rho_w/rho_i)*b;
        Q = (rho_i*g/(C*gz_frac*xg))^n * (h^(2*n + 1));

        Q_g = omega*(hg^beta);

        dh_dt = accum - (Q_g/xg) - (h/(xg*hg))*(Q-Q_g);
        dxg_dt = (Q-Q_g)/hg;

        h = h + dh_dt*1*year;
        xg = xg + dxg_dt*1*year;
        xgs_nl(t) = xg;



    end

    figure(2);
    subplot(1,2,1);
    plot(linspace(0,t./1e3,length(xgs_nl)),(xgs_nl-xg_orig)./1e3,'Color',clr(j,:),'linewidth',4);hold on;
    subplot(1,2,2);
%     plot(linspace(0,t./1e3,length(xgs_nl)),(xgs_nl-xg_orig)./1e3,'Color',clr(j,:),'linewidth',4);hold on;
    semilogx(linspace(0,t,length(xgs_nl)),(xgs_nl-xg_orig)./1e3,'Color',clr(j,:),'linewidth',4);hold on;
end

xg = xg_orig+2e3;
h = h_orig;
xgs_nl = xg;

parameters.bedslope = 1*tss_stab_fast;
parameters.icedivide = b_orig-(parameters.bedslope*xg_orig);


for t = 1:2e4 %100kyr to steady state

    b = Base(xg,parameters);
    bx = dBasedx(xg,parameters);
    omega = ((A_glen*(rho_i*g)^(n+1) * (1-(rho_i/rho_w))^n / (4^n * C))^(1/(m+1))) * theta0^(n/(m+1));


    hg = -(rho_w/rho_i)*b;
    Q = (rho_i*g/(C*gz_frac*xg))^n * (h^(2*n + 1));

    Q_g = omega*(hg^beta);

    dh_dt = accum - (Q/xg) - (h/(xg*hg))*(Q-Q_g);
    dxg_dt = (Q-Q_g)/hg;

    h = h + dh_dt*1*year;
    xg = xg + dxg_dt*1*year;
    xgs_nl(t) = xg;



end
%%
figure(2);set(2,'units','normalized','position',[0.1 0.1 0.7 0.45]);
subplot(1,2,1);
plot(linspace(0,t./1e3,length(xgs_nl)),(xgs_nl-xg_orig)./1e3,'k','linewidth',4);hold on;
subplot(1,2,2);
% plot(linspace(0,t./1e3,length(xgs_nl)),(xgs_nl-xg_orig)./1e3,'k','linewidth',4);hold on;
semilogx(linspace(0,t,length(xgs_nl)),(xgs_nl-xg_orig)./1e3,'k','linewidth',4);hold on;
% ylim([0 5e3])

subplot(1,2,1)
ylim([0 5])
set(gca,'fontsize',24)
xlabel('Time (kyr)','fontsize',24)
ylabel('Grounding Line Deviation (km)','fontsize',24)
legend({'$\bar{b}_x^{*S} \times 1.5$','$\bar{b}_x^{*S}$','$\bar{b}_x^{*S} \times 0.5$','$\bar{b}_x^{*F}$'},'Interpreter','LaTeX','Location','NorthEast')
text(0.01,1.0,'a','Units', 'Normalized', 'VerticalAlignment', 'Top','fontsize',40)

subplot(1,2,2)
ylim([0 5])
xlim([0 1e4])
set(gca,'fontsize',24,'XTick',[1e1 1e2 1e3 1e4]);%,'YTick',[1e1 1e2 1e3 1e4])
xlabel('Time (yr)','fontsize',24)
ylabel('Grounding Line Deviation (km)','fontsize',24)
% xticks([1e1 1e2 1e3 1e4])
text(0.01,1.0,'b','Units', 'Normalized', 'VerticalAlignment', 'Top','fontsize',40)
