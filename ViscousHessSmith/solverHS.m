function [Cl, Cd, xmax, Cp, maxdCp, x, y, p, p1, SOL] = solverHS(npoint, aname, alpha, varargin)
% Usage:
% - [Cl, Cd, Cp, maxdCp] = solverHS(npoint, aname, alpha)
% - [Cl, Cd, Cp, maxdCp] = solverHS(npoint, aname, alpha, dist, crel)

% maxdCp is a matrix; each row corresponds to an airfoil, first column corresponds to
% lower part, second column corresponds to upper part

% TODO: input check => mi conviene davvero farlo? 
% magari lo faccio e poi lo commento prima di inserirlo in ciclo di ottimizzatore


if length(alpha) == 1 && isempty(varargin)

    aname1 = aname(1, :);
    alpha1 = alpha;

    % Airfoil discretization and plotting
    [x, y] = AirfoilShape(aname1, npoint);
    [p1] = Panels(x, y);
    p = [];

    % Aerodynamic Influence Coefficients Matrix [AIC]
    [AIC] = AICMatrix (p1);

    % Right Hand Side Vector {RHS}
    [RHS] = RHSVector(p1, alpha1, 1);

    % System solution
    SOL = AIC\RHS;

    % Velocity
    [v] = Velocity(p1, alpha1, 1, SOL); % need this for Cp

    % Pressure - FIXME: fix calculation of maxdCp after reading Valarezo-Chin
    maxdCp = zeros(1,2);
    [Cp] = PressureCoeff(v, 1);
    ncp = floor(size(Cp,1)/2);
    maxdCp(1,1) = max(Cp(1:ncp,1)) - min(Cp(1:ncp,1));
    ncp = ncp + 1;
    maxdCp(1,2) = max(Cp(ncp:end,1)) - min(Cp(ncp:end,1));



    % Aerodynamic coefficients
    [Cl, Cd] = Loads(p1, Cp, alpha1); % omitted arguments: Cm, CmLE




elseif (~isempty(varargin)) && length(alpha) >= 2

    % Identify case
    nairfoils = length(alpha);

    % Load inputs
    dist = varargin{1};
    crel = varargin{2};

    % get multi geometry
    [x,y, xmax] = multiGeometry(npoint, aname, alpha, dist, crel);

    % panels
    for i = 1:nairfoils % this runs backwards to avoid preallocation issues!
        [p1(i)] = Panels(x{i}, y{i});
    end
    [p, metaPan] = PanelsMulti(p1);

    % Influence matrix
    [AIC] = AICMatrixMulti(p, metaPan, nairfoils);

    % Right Hand Side Vector {RHS}
    [RHS] = RHSVectorMulti(p, alpha, 1);

    % Solution
    SOL = AIC\RHS;

    % Velocity on profile
    v = VelocityMulti(p, metaPan, nairfoils, alpha, 1, SOL);

    % Preallocation of coefficients
    Cp = cell(1, nairfoils);
    maxdCp = zeros(nairfoils, 2);
    Cl = zeros(nairfoils,1);
    Cd = zeros(nairfoils,1);

    % Calculation of coefficients
    for i = 1:nairfoils
        Cp{i} = PressureCoeff(v{i}, 1);
        [Cl(i), Cd(i)] = Loads(p1(i), Cp{i}, alpha(i));
        % FIXME: fix calculation of maxdCp after reading Valarezo-Chin
        % ncp = floor(size(Cp,1)/2);
        % maxdCp(i, 1) = max(Cp(1:ncp, i)) - min(Cp(1:ncp, i));
        % ncp = ncp + 1;
        % maxdCp(i, 2) = max(Cp(ncp:end, i)) - min(Cp(ncp:end, i));
    end


else  
    error('wrong input; see documentation for instructions on how to use this function.')
end


return
