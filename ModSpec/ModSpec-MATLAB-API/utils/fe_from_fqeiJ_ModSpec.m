
function out = fe_from_fqeiJ_ModSpec(varargin)
    flag.fe = 1; flag.qe = 0; flag.fi = 0; flag.qi = 0; flag.J = 0;
    MOD = varargin{end};
    [fqei_out, J_out] = feval(MOD.fqeiJ, varargin{1:(end-1)}, flag, MOD);
    out = fqei_out.fe;
end

