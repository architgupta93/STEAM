function [dae, outputs, simArgs] = daeMOSInverter(varargin)
%function [dae, outputs, simArgs] = daeMOSInverter(varargin)

    cktdata.cktname = 'MOS Inverter';
    if (nargin > 2)
        cktdata.cktname = 'Tabulated MOS Inverter';
    end

    % nodes (names)
    cktdata.nodenames = {'vdd', 'in', 'out'};
    cktdata.groundnodename = 'gnd';

    % list of elements 

    % vsupElem
    vsupElem.name = 'vdd';
    vsupElem.model = vsrcModSpec('vdd');
    vsupElem.nodes = {'vdd', 'gnd'}; % p, n
    vsupElem.parms = {}; % vsrc/isrc have no parameters

    cktdata.elements = {vsupElem};

    % vinElem
    vinElem.name = 'vin';
    vinElem.model = vsrcModSpec('vin');
    vinElem.nodes = {'in', 'gnd'}; % p, n
    vinElem.parms = {}; % vsrc/isrc have no parameters

    cktdata.elements = {cktdata.elements{:}, vinElem};

    cktdata = add_subcircuit(cktdata, MOSInverter(varargin{:}), 'INV', ...
        {'vdd', 'in' , 'out'});
    
    dae = MNA_EqnEngine(cktdata);

    % Setting up transient/DC/AC parameters

    VDD = 1.0;
    VInOffset = 0.5;

    % Finding if the model is BSIM or MVS
    simArgs = struct();
    simArgs.fstart = 1;
    simArgs.fstop = 1e9;
    simArgs.nsteps = 5; % 5 points per decade

    parm_string = varargin{2};
    kBSIM = findstr(parm_string, 'BSIM');
    kSH = findstr(parm_string, 'SH');
    kPSP = findstr(parm_string, 'PSP');
    kMVS = findstr(parm_string, 'MVS');
    
    % AC analysis arguments
    simArgs.VIN_MIN = VDD/2 - 0.1;
    simArgs.VIN_MAX = VDD/2 + 0.1;
    simArgs.n_ops = 4;
    
    % Different Transient Inputs to try (Declare here as they are required for setting the time step)
    vddArgs.VDD = VDD;

    sinArgs.A = .2;
    sinArgs.f = 1e6;
    sinArgs.Offset = VInOffset;

    % Transient Arguments
    simArgs.tstart = 0;
    simArgs.tstep = 0.05/sinArgs.f;
    simArgs.tstop = 4/sinArgs.f;

    if (~isempty(kBSIM) || ~isempty(kSH) || ~isempty(kPSP))
        % DC Analysis Arguments
        simArgs.v_start = 0;
        simArgs.v_step = 0.02;
        simArgs.v_stop = VDD;
    elseif(~isempty(kMVS))
        % DC Analysis Arguments: For MVS, it works better this way
        %simArgs.v_start = 0.85*VDD;
        simArgs.v_start = VDD;
        simArgs.v_step = -0.02;
        simArgs.v_stop = 0;
    else
        fprintf(2, 'Circuit parameters not found for the given MOS model\n');
    end

    % This transient input requires variables that were described above
    stepArgs.A = .2;
    stepArgs.scale = 10*simArgs.tstep;
    stepArgs.Offset = 0.4;
    stepArgs.Onset = (simArgs.tstart+simArgs.tstop)/2;
    stepArgs.smoothing = 0.01;

    % Transient function description
    sinFunc = @(t,args) args.Offset+args.A*sin(args.f*2*pi*t);
    stepFunc = @(t,args) args.Offset+args.A*smoothstep((t-args.Onset)/...
        args.scale, args.smoothing);

    vddFunc = @(t,a) a.VDD;
    
    inFunc = sinFunc; inArgs = sinArgs;
    %inFunc = stepFunc; inArgs = stepArgs;

    % Setting up transient inputs
    dae = dae.set_utransient('vin:::E', inFunc, inArgs, dae);
    dae = dae.set_utransient('vdd:::E', vddFunc, vddArgs, dae);
    
    % Setting up DC inputs
    QSS = dae.utransient(simArgs.tstart, dae);
    dae = dae.set_uQSS(QSS, dae); % Vin is irrelevant for DCSWEEP

    if (nargout > 2)
        % Checking if we have already computed an initial guess
        simArgs.daeIdentifier = [varargin{2}, '_inverter'];
        global STEAM_DATA_DIR;
        base_initguess_filename = [simArgs.daeIdentifier, '_initguess.mat'];
        initguess_filename = [STEAM_DATA_DIR, base_initguess_filename];

        if (exist(initguess_filename, 'file'))
            fprintf(2, 'Found initial guess for DAE: %s in %s\n', simArgs.daeIdentifier, base_initguess_filename);
            load(initguess_filename, '-mat');
        else
            initguess = zeros(dae.nunks(dae), 1);
            % Generating an initial guess using voltage stepping
            n_vdd_steps = 5;
            for vdd_val = [ linspace( 0.1, VDD, n_vdd_steps)];
                stepping_dae = dae.set_uQSS('vdd:::E', vdd_val, dae); 
                % This is for DC Analysis only. Comment out for Transient
                stepping_dae = stepping_dae.set_uQSS('vin:::E', ...
                    simArgs.v_start, stepping_dae); 
                op_pt = op(stepping_dae, initguess);
                initguess = op_pt.getSolution(op_pt);
            end
            fprintf(2, 'Saving generated initial-guess in %s for later use\n', base_initguess_filename);
            save(initguess_filename, 'initguess', '-v7');
        end
        simArgs.xinit = initguess;
    end

    outputs = StateOutputs(dae);
    outputs = outputs.DeleteAll(outputs);
    outputs = outputs.Add({'e_in', 'e_out'}, outputs);
    % outputs = outputs.Add({'e_out'}, outputs); % For AC Analysis
end
