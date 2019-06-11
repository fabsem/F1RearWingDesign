function [warnOut, x_transition, Cf] = solverBL(Re, x, y, ue, h_trans, varargin)
%solverBL - inspired by J. Moran's INTGRL; solves integral boundary layer equations
%starting at a stagnation point.
%Uses Thwaites' method for laminar flow, Michel's method to fix transition, Head's method
%for turbulent flow.

    % TODO: best fit for h_trans; remember it must be between 1.3 and 1.4 (necessarily >=1!)
    if h_trans < 1
        error('h1 cannot be < 1.')
    end

    %% input check
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~isscalar(Re)
        error('wrong input; Re must be a scalar number.')
    end
    if ~isvector(x) || ~isvector(y) || ~isvector(ue)
        error('wrong input; either x, y or ue is not a vector.')
    end
    if length(x) ~= length(y)
        error('wrong input; x and y have different lengths.')
    end
    if length(x) ~= length(y)
        error('wrong input; ue does not match mesh dimension.')
    end



    %% load settings
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % possibly fixed transition
    if isempty(varargin) || varargin{1} == 0
        fixedTrans = false;
    else
        fixedTrans = true;
        xtrans = varargin{1};
    end

    % warning behaviour
    showWarn = true;
    if length(varargin) > 1
        showWarn = varargin{2};
    end


    %% define parameters
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    nx = length(x);


    %% initialisation
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Cf = zeros(1, nx);
    warnOut = {};
    xi = getSwiseCoord(x, y); % get streamwise coordinate
    ugrad = gradVel(ue, xi); % get velocity gradient



    %% laminar: integration
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % initial conditions (main variables)
    theta = sqrt(.075/Re/ugrad(1)); % value from Moran
    delta = 2.23641 * theta; % derived starting from Eppler's cond. on hek
    eta = 0;

    % initial conditions (auxiliary variables)
    % hek = 1.61998; % value from Eppler
    h = 2.23641; % obtained from value above with Eppler's empirical h(hek)
    Retheta = Re * ue(1) * theta;

    % initialisation
    ii = 1; % counter for panels
    x_transition = x(end);
    opts = optimset('Display','off'); % options for nonlinear solver

    while eta < 9

        % check laminar separation
        % if it happens, calculations switch to turbulent (as if there were a trans. bubble)
        % however, if turbulent flow separates straight away, it probably was a laminar separation
        %if hek < 1.515
        %    if showWarn
        %        warning(['laminar separation at x = ' num2str(x(ii))]);
        %    end
        %    warnOut{end+1} = 'laminar separation';
        %    warnOut{end+1} = x(ii);
        %    break
        %end

        % calculate skin friction factor
        Cf(ii) = cflam(Retheta, h);

        % go on to next panel, check if such panel exists
        ii = ii + 1;
        if ii > nx
            return
        end

        % integration of bl: forward/backward Euler
        guess_y = [theta, delta, eta];
        dxi = xi(ii) - xi(ii-1);
        f = @(a) stepBackEuler(a, Re, theta, delta, eta, dxi, ue(ii), ugrad(ii));
        [y, ~, exitFlag] = fsolve(f, guess_y, opts);
        if exitFlag > 1
            warning(['at iteration ' int2str(ii) ', fsolve did not properly converge; exit flag ' int2str(exitFlag) '.'])
        elseif exitFlag < 1
            warning(['at iteration ' int2str(ii) ', fsolve did not converge; exit flag ' int2str(exitFlag) '.'])
        end

        % correction if on second cell
        % if ii == 2
        %    theta(2) = theta(1);
        % end

        % update variables
        theta = y(1);
        delta = y(2);
        eta = y(3);
        h = delta/theta;
        Retheta = Re * theta * ue(ii);

        % check transition
        if fixedTrans
            if x(ii) > xtrans
                break
            end
        end

    end

    % save data
    x_transition = x(ii);
    %i_trans = ii;



    %% turbulent: integration
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % initialisation
    h = h_trans;
    yy(2) = h1_of_h(h);
    yy(1) = theta;

    % legend: yy = [theta, h1]

    % keep on integrating
    while ii <= nx

        % get dx and perform integration step
        dx = xi(ii) - xi(ii-1);
        yy = runge2(ii-1, ii, dx, yy, 2, ue, ugrad, Re);

        % unpack integration output
        theta(ii) = yy(1);
        h = h_of_h1(yy(2));

        % get Re and Cf
        Retheta = Re * ue(ii) * theta(ii);
        Cf(ii) = cfturb(Retheta, h);

        % check separation
        if h > 2.4
            if showWarn
                warning(['turbulent separation at x = ' num2str(x(ii))]);
            end
            warnOut{end+1} = 'turbulent separation';
            warnOut{end+1} = x(ii);
            return
        end

        % update counter
        ii = ii + 1;

    end

end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SUBROUTINES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%% calculate streamwise coordinate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function xi = getSwiseCoord(x, y)

    nx = length(x);
    
    xi = zeros(1, nx); % streamwise coordinate

    for ii = 2:nx
        dx = x(ii) - x(ii-1);
        dy = y(ii) - y(ii-1);
        xi(ii) = xi(ii-1) + sqrt(dx*dx + dy*dy);
    end
end



%% differentiate velocity
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function  ugrad = gradVel(ue, xi)

    nx = length(ue);

    ugrad = zeros(1, nx); % external velocity gradient

    v1 = ue(3);
    x1 = xi(3);
    v2 = ue(1);
    x2 = xi(1);
    xi(nx+1) = xi(nx-2);
    for ii = 1:nx
        v3 = v1;
        x3 = x1;
        v1 = v2;
        x1 = x2;
        v2 = ue(nx-2);
        if ii < nx
            v2 = ue(ii+1);
        end
        x2 = xi(ii+1);
        fact = (x3 - x1)/(x2 - x1);
        ugrad(ii) = ((v2 - v1) * fact - (v3 - v1)/fact)/(x3-x2);
    end

end



%% laminar closure: Drela and Giles
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function hs = hek_of_h(h)
    if h < 4
        hs = 1.515 + 0.076*((4-h)^2)/h;
    else
        hs = 1.515 + 0.040*((h-4)^2)/h;
    end
end

function h = h_of_hek(hek, guess_h) % possibly deprecated
    if hek < 1.515
        error('too low value of hek; laminar flow should be separated (possibly originating a transition bubble).')
    elseif hek < 1.51509 % give it a little error margin
        h = 4;
    else
        f = @(x) hek_of_h(x) - hek;
        [h, ~, exitFlag] = fzero(f, guess_h);
        if exitFlag ~= 1
            error(['fzero did not converge; exit flag ' int2str(exitFlag) '.'])
        end
    end
end

function h = h_of_hek_eppler(hek) % possibly deprecated
%h_of_hek - empirical formula from Eppler.
% This one provides a good fit of the previous one (hek_of_h) for 1.8574 < h < 4 (1.515 < hek < 1.7515).
% However, the inverse of hek(h) is NOT A FUNCTION - so this is basically just one branch of the inverse.
% Might be useful for initial value.
    if hek < 1.515
        error('too low value of hek.')
    elseif hek < 1.57258
        h = 4.02922 - (583.60182 - 724.55916*hek + 227.1822*hek.^2) * sqrt(hek - 1.515);
    else
        h = 79.870845 - 89.582142*hek + 25.715786*hek.^2;
    end
end

function cf = cflam(Ret, h)
    if h < 7.4
        lhs = -0.067 + 0.01977*((7.4-h)^2)/(h-1);
    else
        lhs = -0.067 + 0.022*(1 - 1.4/(h-6))^2;
    end
    cf = 2 * lhs /Ret;
end

function cds = cdiss(Ret, hek, h)
    if h < 4
        lhs = 0.207 + 0.00205 * (4-h)^(5.5);
    else
        lhs = 0.207 - 0.003 * ((h-4)^2) / (1 + 0.02*(h-4)^2);
    end
    cds = lhs * hek /2 /Ret;
end

function hd = hdens(h)
    % hd = 0.064/(h-0.8) + 0.251;
    hd = 0; % since Me = 0
end

function [l, m] = lm(h)
    l = (6.54*h - 14.07)/h^2;
    m = (0.058*((h-4)^2)/(h-1) - 0.068)/l;
end

function diff = detadre(h)
    diff = 0.01*sqrt(((2.4*h - 3.7 + 2.5*tanh(1.5*h-4.65))^2)+0.25);
end

function y = stepBackEuler(x, Re, theta, delta, eta, dxi, n_ue, n_ugrad)

    y = zeros(size(x)); % preallocation

    % LEGEND: plain variables = old variables; n_variables = new variables

    % unpack input
    n_theta = x(1); % theta_(n+1)
    n_delta = x(2); % delta_(n+1)
    n_eta = x(3); % eta_(n+1)

    % preprocessing
    n_Ret = Re * n_ue * n_theta; % Re_theta
    n_h = n_delta/n_theta; % new h = d/theta
    n_hek = hek_of_h(n_h); % new hek(h)
    h = delta/theta; % old h
    hek = hek_of_h(h); % old hek
    d_eta = detadre(n_h);
    [l, m] = lm(n_h);

    % momentum thickness and energy shape parameter equations: BACKWARDS EULER
    y(1) = (n_theta - theta)/dxi ...
            + (2+n_h)*(n_theta/n_ue)*n_ugrad - cflam(n_Ret, n_h)/2;
    y(2) = n_theta*(n_hek-hek)/dxi ...
            + (2*hdens(n_h) + n_hek*(1-n_h))*(n_theta/n_ue)*n_ugrad - 2*cdiss(n_Ret, n_hek, n_h) ...
            + n_hek*cflam(n_Ret, n_h)/2;
    y(3) = (n_eta - eta)/dxi ...
            - d_eta * (m+1)/2 * l/n_theta;
    
end




%% turbulent closure: Head's correlation formula
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function h1 = h1_of_h(h)

    if h > 1.6
        h1 = 3.3 + 1.5501*(h - .6778)^(-3.064);
    else
        h1 = 3.3 + .8234*(h - 1.1)^(-1.287);
    end

end



%% turbulent closure: inverse Head's correlation formula
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 

function h = h_of_h1(h1)

    if h1 < 3.3
        h = 3.0;
    elseif h1 < 5.3
        h = .6778 + 1.1536*(h1 - 3.3)^(-.326);
    else
        h = 1.1 + .86*(h1 - 3.3)^(-.777);
    end

end



%% turbulent closure: Ludwieg-Tillman skin friction formula
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 

function cf = cfturb(rtheta, h)

    cf = .246 * (10 ^(-.678*h)) * rtheta^(-.268);

end



%% turbulent integration: derivatives
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 

function ypr = derivs(ii, yt, yp, ue, ugrad, Re)

    h1 = yt(2);

    if h1 <= 3
        ypr = yp;
        warning('h1 < 3; function is returning default value')
        return
    end

    h = h_of_h1(h1);
    rtheta = Re * ue(ii) * yt(1);

    ypr(1) = -(h+2)*yt(1)*ugrad(ii)/ue(ii) + .5*cfturb(rtheta,h);
    ypr(2) = -h1*(ugrad(ii)/ue(ii) + yp(1)/yt(1)) + .0306*(h1-3)^(-.6169)/yt(1);

end



%% turbulent integration: Runge-Kutta 2
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 

function yy_out = runge2(i0, i1, dx, yy, n, ue, ugrad, Re)

    intvls = i1 - i0;
    yp = [0,0];
    
    if intvls < 1
        yy_out = yy;
        return
    end

    for ii = 1:intvls
        for jj = 1:n
            yt(jj) = yy(jj);
        end
        yp = derivs(i0+ii-1, yt, yp, ue, ugrad, Re);
        for jj = 1:n 
            yt(jj) = yy(jj) + dx * yp(jj);
            ys(jj) = yy(jj) + .5*dx*yp(jj);
        end
        yp = derivs(i0+1, yt, yp, ue, ugrad, Re);
        for jj = 1:n
            yy_out(jj) = ys(jj) + .5*dx*yp(jj);
        end
    end

end