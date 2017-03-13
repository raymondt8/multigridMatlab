function [model_coarse,p_ad_coarse, sW_ad_coarse,defect_p_ad_coarse,defect_s_ad_coarse, ...
    pIx_coarse, sIx_coarse] ...
    = coarseningV2(model, p_ad, sW_ad,defect,pIx,sIx)
  %% Function description
  %
  % PARAMETERS:
  % model    - System model structure with grid, rock, phases and operator
  %            substructs
  % p_ad     - ADI struct for the pressure
  % s_ad     - ADI struct for the saturation
  % defect   - The defect of the current approximization.
  % pIx      - Index array for pressure values
  % sIx      - Index array for saturation values
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

  %% Create new coarse model
  % Set up coarse grid
  coarse_dims = ceil(model.G.cartDims/2);
  partition  = partitionCartGrid(model.G.cartDims,coarse_dims);
  CG = generateCoarseGrid(model.G, partition);
  CG = coarsenGeometry(CG);
  
  % Define coarse rock
  rock_coarse = makeRock(CG, 30*milli*darcy, 0.3);
  
  % Initiate new coarse model
  %{Not currently in use
  %coarse = true;
  %model_coarse = initiateModel(CG, rock_coarse, coarse); 
  %}
  model_coarse = initiateModel(CG, rock_coarse);

  % Add fields to the coarse grid to ensure that it passes as a
  % regular grid for our purposes.
  model_coarse.G.cartDims = coarse_dims;
  
  %% Restrict AD variables and defect
  weighting = accumarray(partition,1);
  
  coarse_p_init = accumarray(partition, p_ad.val)./weighting;
  coarse_sW_init = accumarray(partition,sW_ad.val)./weighting;
  % Until a better aproach is found, the ADI varaables is re-initiated 
  [p_ad_coarse, sW_ad_coarse] = initVariablesADI(coarse_p_init, coarse_sW_init);

  % Prolongate defect - sum
  [defect_p_ad_coarse, defect_s_ad_coarse]= initVariablesADI(accumarray(partition,defect(pIx)),accumarray(partition,defect(sIx))); 

  %% Coarsen help variables
  nc_coarse = model_coarse.G.cells.num;
  pIx_coarse = 1:nc_coarse;
  sIx_coarse = (nc_coarse+1):(2*nc_coarse);
  
end