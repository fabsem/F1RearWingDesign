% Check if main and flap airfoils do not stall in both DRS-OFF and DRS-ON configuration


    cp_main = cp{1};
    cp_flap = cp{2};
    
    cpDRS_main = cp_DRS{1};
    cpDRS_flap = cp_DRS{2};

stall_or_not = [0 0; 0 0];    
%keyboard
    
% Main DRS-OFF
[stall_or_not(1,1),Re] = stall(cp_main, [], 1);

% Flap DRS-OFF
[stall_or_not(2,1),Re] = stall(cp_flap, [], 1);


% Main DRS-ON
[stall_or_not(1,2),Re] = stall(cpDRS_main, [], 1);

% Main DRS-ON
[stall_or_not(2,2),Re] = stall(cpDRS_flap, [], 1);

%keyboard
%Global check
if stall_or_not == 0
    % 0 = NO STALLO
    stall_flag = 0;
    
else
    % 1 = STALLO
    stall_flag = 1;
    
end
