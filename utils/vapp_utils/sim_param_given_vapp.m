function out = sim_param_given_vapp(parmName, MOD)
% PARAM_GIVEN_VAPP check if a parameter was set by the user
% ATTENTION: this only works with ModSpec models generated by VAPP and if the
% parameter value was set using setparms_vapp.

    out = MOD.parm_given_flag(strcmp(parmName, MOD.parm_names));

    if isempty(out) == true
        fprintf(2, ['Warning: param_given_vapp: there is no parameter with',...
                    ' the name "%s"!'], parmName);
        out = false;
    end
end