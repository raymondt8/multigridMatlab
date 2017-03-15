function [model] = initiateModel(G,rock,varargin)
  %% Function description
  %
  % PARAMETERS:
  % G        - initialized grid structure
  % rock     - initialized rock structure
  % # Not currently used: varargin - {1} coarse/true Contains a true statement if model is to be
  %             initialized for a coarsed grid: Do not compute transmissibilities
  %
  % RETURNS:
  % p_ad_coarse - Coarsed version of the pressure eqs. with reinitialized
  %               ADI structure
  % sW_ad_coarse - Coarsed version of the pressure eqs. with reinitialized
  %               ADI structure
  % defect_p_ad_coarse - Coarsed version of the pressure defect
  % defect_s_ad_coarse - Coarsed version of the saturation defect
  % pIx_coarse   - Coarsed version of the pressure index
  % sIx_coarse   - Coarsed version of the saturation index
  %
  % COMMENTS:
  % - This coarsening function is currently not optimized for performance
  % - The function may be bugged in current state
  %
  % SEE ALSO:
  %

  %% Rock model
 % rock = makeRock(G, 30*milli*darcy, 0.3);
  cr   = 1e-6/barsa;
  p_r  = 200*barsa;
  pv_r = poreVolume(G, rock);
  pv   = @(p) pv_r .* exp( cr * (p - p_r) );
  
  %rock struct
  rock = struct('perm',rock.perm,'poro',rock.poro, ...
      'cr', cr, 'p_r',p_r, 'pv_r', pv_r, 'pv',pv);
  
  %% Define model for two-phase compressible fluid
  % Define a water phase
  muW    = 1*centi*poise;
  cw     = 1e-5/barsa;
  rho_rw = 960*kilogram/meter^3;
  rhoWS  = 1000*kilogram/meter^3;
  rhoW   = @(p) rho_rw .* exp( cw * (p - p_r) );
  krW = @(S) S.^2;
  
  water = struct('muW', muW, 'cw', cw, 'rho_rw', rho_rw, 'rhoWS', rhoWS, 'rhoW', rhoW, 'krW', krW);
    
  % Define a lighter, more viscous oil phase with different relative
  % permeability function
  muO   = 5*centi*poise;
  co      = 1e-4/barsa;
  rho_ro = 850*kilogram/meter^3;
  rhoOS  = 750*kilogram/meter^3;
  krO = @(S) S.^3;

  rhoO   = @(p) rho_ro .* exp( co * (p - p_r) );

  oil = struct('muO', muO, 'co', co, 'rho_ro', rho_ro, 'rhoOS', rhoOS, 'rhoO', rhoO, 'krO', krO);
  
  %% Compute transmissibilities
  N  = double(G.faces.neighbors);
  intInx = all(N ~= 0, 2);
  N  = N(intInx, :);                          % Interior neighbors
  
%   if(isempty(varargin)==0)
%       coarse = varargin{1};
%   else
%       coarse = 0;
%   end
%   if(coarse == true)
%      T =  computeTrans(G, rock);
%      T = T(intInx);
%   else
    hT = computeTrans(G, rock);                 % Half-transmissibilities
    cf = G.cells.faces(:,1);
    nf = G.faces.num;
    T  = 1 ./ accumarray(cf, 1 ./ hT, [nf, 1]); % Harmonic average
    T  = T(intInx);                             % Restricted to interior
%  end
  
  %% Define discrete operators
  n = size(N,1);
  C = sparse( [(1:n)'; (1:n)'], N, ones(n,1)*[-1 1], n, G.cells.num);
  grad = @(x)C*x; % Discrete gradient
  div  = @(x)-C'*x; % Discrete divergence
  avg  = @(x) 0.5 * (x(N(:,1)) + x(N(:,2))); % Averaging
  upw = @(flag, x) flag.*x(N(:, 1)) + ~flag.*x(N(:, 2)); % Upwinding 

  gradz  = grad(G.cells.centroids(:,3));

  operator = struct('grad', grad, 'div', div, 'avg', avg, 'upw', upw, 'gradz', gradz, 'C',C);
  
  %% Define wells
  injIndex = 1;
  prodIndex = G.cells.num;

  inRate = 1;
  outRate = 0.5;
  
  well = struct('injIndex',injIndex, 'prodIndex',prodIndex, 'inRate', inRate, 'outRate', outRate);
  
  %% Place all model parts and help function i a "modelstruct"
  model = struct('G',G,'rock', rock, 'water', water, 'oil',oil, 'T', T, ...
      'operator', operator, 'well', well);

end