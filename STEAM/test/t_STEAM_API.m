fprintf(2, 'Testing STEAM API... \n');

% Transistor model parameters
m_handle = @bsim3;
model_id = 'VA_BSIM3_NMOS';

% Trying a 2D Model
n_dims   = 2;
model    = MOS5TModel2D(m_handle, model_id);

% If you want to try a full 3D model
%{
n_dims   = 3;
model    = MOS5TModel(m_handle, model_id); 
%}

% STEAM (discretization/interpolation) parameters
d_method = 'c';
d_order  = randi([6, 6], 1, n_dims);
d_bounds = cell( 1, n_dims );

% Interpolation parameters (Which interpolant to use post-discretization)
n_pieces = randi([1, 1], 1, n_dims);
i_method = 'bli';

for d_i = 1 : size(d_bounds, n_dims)
    d_bounds{1, d_i} = linspace(-1, 1, n_pieces(d_i)+1)';
end

% Initializing a STEAM model
steam_model = STEAM(model, i_method, d_method, d_order, d_bounds);

% Draw a comparison between the original model and the STEAM generated model to
% see the differences between the two
fprintf(2, 'Testing STEAM generated model against original!\n')
n_test_pts     = 500;
n_dims         = steam_model.n_in_dims;
[~, ~, er_plt] = compareIObjs(n_test_pts, d_bounds, model, steam_model, 'STEAM');
compareIDers(n_test_pts, d_bounds, model, steam_model, 'STEAM');
