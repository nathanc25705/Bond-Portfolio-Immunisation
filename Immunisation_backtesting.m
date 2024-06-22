% clear 
% clc
% 
% rng default;
% load('LMM_model_calibrated');





% Title: FIN30160 - Derivatives Research Department - Immunization of Bond
% Portfolio of US bonds

% Project Name : Group 1 - US: Group Project FIN30160 -- April 2024
% Date : 25/04/2024

% Students:
% Nathan Clarke (20387306)
% Anna Blake (20447454)
% Patryk Adamczyk (20341201) 
% Austin Scott (23222234) 
% Joao Pedro Werneck Fraga (23223505)







% clearing variables is required for a code rerun if bonds which mature
% during the simulation are included
clear Maturity
clear bond_maturity_dates
clear coupon
clear face_value
clear coupons_per_year
clear bond_basis
clear value_of_matured_bond
clear bond_units
clear bonds_selected
clear num_total_bonds
clear years_to_maturity
clear c_spread
clear bond_weightings
clear maturity_month
clear risk_free
clear pv_liability







students_decide_to_do_optional_additional_section = false;
num_simulations = 1;
bonds_selected = 24;



for(k=1:num_simulations)
    m = 1;
    
    % Initialization 
    
    %(US)
    t                               = 1;
    AUM(t)                          = 18000000000; % AUM = Assets under management
    fixed_amount_extract            = 0.01*AUM(t); % monthly fixed ammount that investors extract every month
    
    
    %                            Section 2.a                                  %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Beginning with selection of start date as most other sections depend on
    %this
    
    
    first_date = RateSpecG2{1}.Settle+1; %1st date of period between 10-May-2005 -> 06-July-2011
    
    % Load data from Excel file
    filename = 'BondRates_0510.xlsx';
    sheet = 1; % Data is in the first sheet
    range_data = 'B3:F1306'; % Data is in columns A to E starting from row 2
    range_constants = 'I2:M2'; % Constants are in columns F to J starting from row 2
    data = xlsread(filename, sheet, range_data);
    constants = xlsread(filename, sheet, range_constants);
    
    % Calculate cumulative differences for each row
    cumulative_diff = sum(abs(data - constants), 2);
    
    % Find the row with the lowest cumulative difference
    [min_diff, min_index] = min(cumulative_diff);
    
    % Read the date corresponding to the row with the lowest difference
    date_range = 'A';
    date_column = datetime(xlsread(filename, sheet, [date_range, num2str(min_index+2)]), 'ConvertFrom', 'excel');
    min_date = datestr(date_column);
    
    % Display the result
    disp(['The row with the lowest cumulative difference is row ', num2str(min_index), '.']);
    disp(['The date on which this occurred is ', num2str(min_date), '.']);
    
    date = min_date; % This is the date we carry forward
    
    
    
    starting_date = datenum(date); %Converting to datenum
    current_day_ir_simulation = starting_date - first_date; %current # of days into the simulation period
    
    disp(strcat('Selected Start Date : ', char(date)));
    
    
    
    
    
    %         Assigning variables which are dependant on the start date       %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    N = 3;      % # of years for the simulation
    
    list_days_simulation = busdays(starting_date+1,starting_date+(365*N)); % from next day to the next N years 
    
    initial_day             = list_days_simulation(1);
    current_month           = month(initial_day);
    
    % Generating an array containing all payment days for the fixed liabilities
    first_fixed_date = datenum(dateshift(datetime(initial_day, 'ConvertFrom','datenum'), 'start','month','next')); %Date of first fixed liability
    last_fixed_date = datenum(dateshift(datetime(initial_day, 'ConvertFrom','datenum') + calyears(N) , 'start','month')); %Date of last fixed liability
    
    months_remaining_simulation = N*12; %time remaining in the simulation
    
    fixed_dates = datenum(dateshift(datetime(first_fixed_date, 'ConvertFrom', 'datenum'):calmonths(1):datetime(last_fixed_date, 'ConvertFrom', 'datenum'), 'end', 'month')); %array of the dates on which the fixed liabilities will be paid (first day of each month)
    
    %Generating an array of the remaining payment dates for the fixed extracts
    ZeroDates = fixed_dates(m:end);
    
    %Generating an array of spot rates from the current day to each fixed
    %payment date
    ZeroRates = RateSpecG2{current_day_ir_simulation}.getZeroRates(ZeroDates);
    
    
    %                   Section 1 - How much to invest in bonds               % 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Calculating the present value of each liability at the start of the
    %simulation, then summing them to get the PV of all liabilities
    
    
    
    
    for (i=1:length(ZeroDates))
        discounted_fixed_liabilities(i) = fixed_amount_extract/((1+ZeroRates(i)/12)^i); 
    end
    pv_liability = sum(discounted_fixed_liabilities);
    
    
    % The initial invested sum should be equal to the initial AUM - Present
    % value of liability, therefore the proportion to remain in cash is
    % given by:
    
    portion_to_maintain_in_cash = 1-(pv_liability/AUM(1));
    
    
    
    % Assigning inital cash and invest amounts as well as the values of the
    % floating extract
    actual_cash_amount              = AUM(t)*portion_to_maintain_in_cash;
    actual_investment_amount        = AUM(t)*(1-portion_to_maintain_in_cash); % cash + bonds investment = AUM 
    amount_to_subtract_interest_up  = 100000;
    amount_to_add_interest_down     = 100000;
    
    
    %size_historical_term_structure = length(RateSpecG2); %From 2005 to 2013 
    
    
    
    % Note, before simulating the credit spread (2.b) Our bonds first need to be loaded
    
    %                 Section 3 - Loading the real bonds                      %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    bond_data = readtable('bonds.xlsx',VariableNamingRule='preserve'); %Reading bond data from excel file and keeping the column headers
    data_date = datetime('2024-04-01', 'InputFormat', 'yyyy-MM-dd'); %Date at which the bond prices were recorded
    
    % pointing vectors to the columns of the bond_data object
    P = table2array(bond_data(1:end,1))';
    coupon = table2array(bond_data(1:end,2))';
    face_value = table2array(bond_data(1:end,3))';
    bond_maturities = datenum(table2array(bond_data(1:end,4))');
    coupons_per_year = table2array(bond_data(1:end,5))';
    bond_basis = table2array(bond_data(1:end,6))';
    w = table2array(bond_data(1:end,7))';
    notional_coupon = (face_value .* coupon) ./ coupons_per_year;
    
    
    % Calculating the time to maturity for each bond
    time_to_mat = days(bond_maturities-datenum(data_date));
    
    % Adding the time to maturity to the start date of the simulation
    % This essentially shifts the data_date back to the start of the simulation
    bond_maturity_dates = datenum(list_days_simulation(1)+time_to_mat);
    years_to_maturity = days((time_to_mat)/365);
    
    
    % Calculating initial bond prices
    P = prbyzero([bond_maturity_dates' coupon' face_value' coupons_per_year' bond_basis'],starting_date,ZeroRates,ZeroDates)'/10;
    
    % Now that we have the bond data it is possible to carry out the
    % simulation of Credit Spread
    
    %                              Section 2.b                                %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Assigning the yield curve data for the current day in simulation
    y_data = RateSpecG2{current_day_ir_simulation}.Data;
    
    
    %The tenure of the RateSpecG2 Data 
    maturity = 1:length(y_data);
    
    % Here we have used Pchip to calculate a cubic interpolation of the risk free rate
    % In practise we expect this to yield a better result (smoother than linear interpolation) 
    risk_free(t,:) = transpose(pchip(maturity, y_data, years_to_maturity));
    
    
    
    % Now we use the Nelson Siegel model to calcuate bond yields
    
    
    % Assigning the inputs for the model
    Settle = repmat(starting_date, [length(coupon), 1]); %array of the initial date
    Maturity = bond_maturity_dates';                     %array of the maturity dates
    CleanPrice = P';                                     %array of prices
    CouponRate = coupon';                                %array of coupons
    Instruments = [Settle Maturity CleanPrice CouponRate];
    Price_t = P;
    
    % Fitting the NS model
    NSModel = IRFunctionCurve.fitNelsonSiegel('Zero',starting_date,Instruments);
    
    % Retrieving the yields
    NSYields = getParYields(NSModel, Maturity);
    
    
    yield = NSYields';
    
    % Finally we calculating credit spread with zero as a lower bound, see
    % report for why we floored the spreads at zero
    c_spread(t,:) = max(yield - risk_free,0);
    
    
    % Plot of initial term yields
    % plot(Maturity, yield,'r')
    % hold on
    % scatter(Maturity,yield,'black')
    % datetick('x')
    
    
    
    %   Section 3 - Selecting the amount to invest in each bond at the start  %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %Implementing the portfolio selection process from Q5 in order to select
    %the initial portfolio weights, see Q5 for more detailed commentary
    
    % Calculating Duration
    for(i=1:length(coupon))
        [ModDuration(i),Duration(i),PerDuration(i)] = bnddury(yield(i),coupon(i),starting_date,bond_maturity_dates(i),coupons_per_year(i),bond_basis(i),'Face', face_value(i));
    end
    
    
    % Calculating Convexity
    for(i=1:length(coupon))
        [Convexity(i),PerConvexity(i)] = bndconvy(yield(i),coupon(i),starting_date,bond_maturity_dates(i),coupons_per_year(i),bond_basis(i),'Face', face_value(i));
    end
    
    % Assigning the number of bonds and the combinations of them
    num_total_bonds         = length(coupon);
    num_combination_bonds   = bonds_selected; 
    index_bond = nchoosek([1:num_total_bonds],num_combination_bonds); 
    
    % years to portfolio maturity
    Maturity_Portfolio  = months_remaining_simulation/12;
    
    
    % Filling the variables used in the loop as MATLAB can update values more
    % quickly than assigning a new variable
    
    W = zeros(size(index_bond, 1), num_combination_bonds);
    Units = zeros(size(index_bond, 1), num_combination_bonds);
    Value_portfolio = zeros(size(index_bond, 1), num_combination_bonds);
    TE = zeros(t, size(index_bond, 1));
    
    % Pre-filling the Duration and Convexity related functions
    Duration_selected = Duration(index_bond);
    Convexity_selected = Convexity(index_bond);
    Maturity_Portfolio_squared = Maturity_Portfolio.^2;
    
    % Finding the tracking error for each portfolio
    for j = 1:size(index_bond, 1)
        A = [ones(1, num_combination_bonds);
             1/pv_liability * Duration_selected(j,:);
             1/pv_liability * Convexity_selected(j,:)];
    
        b = [pv_liability;
             Maturity_Portfolio;
             Maturity_Portfolio_squared];
    
        W(j,:) = A\b;
    
        Units(j,:) = round(W(j,:) ./ Price_t(index_bond(j,:)));
        Value_portfolio(j,:) = Price_t(index_bond(j,:)) .* Units(j,:);
        TE(t:j) = sum(Value_portfolio(j,:)) - pv_liability;
    
    end
    
    % Selecting the portfolio with the smallest absolute tracking error and
    % assigning the number of each bond to the bond_units variable
    [~, immunisation_strategy_selected] = min(abs(TE(t,:)));
    
    if(~any(isnan(Units(immunisation_strategy_selected,:))))
        list_of_bonds_to_use            = index_bond(immunisation_strategy_selected,:);
        list_of_bonds_not_to_use        = setdiff(1:num_total_bonds,index_bond(immunisation_strategy_selected,:));
        bond_units(t,list_of_bonds_to_use) =  Units(immunisation_strategy_selected,:);
        bond_units(t,list_of_bonds_not_to_use) =  0;
    
    end
    
    
    % Assigning the initial portfolio values
    amount_to_invest        = sum(bond_units(t,:).*P);
    bond_weightings         = bond_units(t,:).*P/amount_to_invest;
    actual_cash_amount      = actual_cash_amount + (actual_investment_amount-amount_to_invest); 
    cash(t)                 = actual_cash_amount;
    actual_investment_amount= amount_to_invest; 
    portfolio_bonds_current_value(t) = actual_investment_amount;
    
    % Storing variables to be used for performance analysis
    TE_final(t) = portfolio_bonds_current_value(t) - pv_liability;
    dates(t)                            =  list_days_simulation(t);
    PV_liability(t)                     = pv_liability;
    
    
    
    % Calculating the current portfolio weighted average yield including the
    % credit spread
    
    portfolio_yield = bond_weightings*(risk_free+c_spread(t,:))';
    
    previous_py = portfolio_yield; 
    current_py = portfolio_yield;
    
    
    
    disp(['Day ' datestr(list_days_simulation(t)) ' -- AUM: $'  num2str(AUM(t)) ' -- Cash amount: ' num2str(cash(t)) ' -- Bonds Portfolio Value:' num2str(portfolio_bonds_current_value(t)) ' -- Tracking Error: $' num2str(TE_final(t))]);
    
    
    
    
    maturity_month = 0; %this variable is used for the removal of bonds which mature in simulation
    
    t = 2; % Starting now from day 2
    for(current_date = list_days_simulation(2:end)') 
        
        
    
    
        if(month(current_date)~= current_month)
            m=m+1;
            maturity_month = 0;
    
            % Adjusting our current positiom in the simulation
            current_month = month(current_date);
            months_remaining_simulation = months_remaining_simulation-1; % we subtract one month from the remaining months of the simulation
            fixed_dates = fixed_dates(2:end); %removing next fixed payment date as it will be paid below
          
            %            Section 4 - Cash Inflows and Outflows                %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %4.a, simulation of credit spread, same process as before %
    
            % Recalculating the credit spreads monthly using the same process
            % as before
            y_data = RateSpecG2{current_day_ir_simulation}.Data;
             
            maturity = 1:length(y_data);
            years_to_maturity = years_to_maturity-(1/12);
            risk_free = (pchip(maturity, y_data, years_to_maturity));
        
         
            NSDate = current_date;
        
            Settle = repmat(NSDate, [num_total_bonds, 1]);
            Maturity = bond_maturity_dates';
            CleanPrice = Price_t';
            CouponRate = coupon';
            Instruments = [Settle Maturity CleanPrice CouponRate];
        
            % Fit Nelson-Siegel    
            NSModel = IRFunctionCurve.fitNelsonSiegel('Zero',NSDate,Instruments);
        
            NSYields = getParYields(NSModel, Maturity);
        
            yield = NSYields';
    
            %recalculating the credit spread, once again flooring at zero
            c_spread(t,:) = max(yield - risk_free,0);
    
            yield = risk_free + c_spread(t,:);
    
            current_py = dot(bond_weightings, yield); %updating current portfolio yield
            
            previous_py  = current_py; % updates current rate. Only changes once per month
            
            
    
    
            %Plotting the monthly yield curves
            % fig = figure;
            % plot(Maturity, yield,'r')
            % hold on
            % scatter(Maturity,yield,'black')
            % datetick('x')
            % title(['Plot ', num2str(current_day_ir_simulation)]);
            % all_plots{current_day_ir_simulation} = fig;
    
    
    
            % 4.b Cash Out %
    
          
    
            if(current_py-previous_py>0.001) % Increase of more than 10bp
                disp('Interest rate increase of greater than 10 bps')
                rate_change = (current_py-previous_py); 
                cash_change = (rate_change/0.001)*amount_to_subtract_interest_up;
                if(actual_cash_amount>cash_change) % We need to check we can extract such amount of cash
                    actual_cash_amount = actual_cash_amount-cash_change; % Extract from cash reserve
                    fprintf('Interest rate changed by %f resulting in a cash outflow of %f\n', rate_change, -cash_change);
                    
    
                else
                    %Selling bonds to pay liability  
                    required_cash = cash_change - actual_cash_amount;
                    bond_value = sum(Price_t.*bond_units(t,:)); % uses the updated bond prices
                    bond_sales = required_cash / bond_value;
                    bond_units(t,:) = (1 - bond_sales) * bond_units(t,:); % update bond units
                    actual_cash_amount = 0; % the cash we did have was all used up before bonds were sold to cover the rest
                    disp('Bonds sold to pay floating extract, no cash remaining')
                 
    
                end
                 
            %4.c, if rate drops by 10 bps we recieve the inflow %    
            elseif(current_py-previous_py<-0.001) % Decrease of more than 10bp
                disp('Interest rate decrease of greater than 10 bps')
                rate_change = previous_py-current_py;
                cash_change = (rate_change/0.001)*amount_to_add_interest_down;
                actual_cash_amount = actual_cash_amount+cash_change;
    
                fprintf('Interest rate changed by %f resulting in a cash inflow of %f\n', -rate_change, cash_change);
            else
                disp('Less than 10bp absolute move in rates')
                
            end
     
     
            % Paying Fixed Extract
            if(actual_cash_amount-fixed_amount_extract>0)% We need to check we can extract such amount of cash
                actual_cash_amount = actual_cash_amount - fixed_amount_extract;
                disp('Fixed Extract Paid with Cash Reserve')
            else
                % If fixed extract is larger than cash reserve, sell bonds to
                % pay
                required_cash = fixed_amount_extract - actual_cash_amount;
                bond_value = sum(Price_t.*bond_units(t,:));
                bond_sales = required_cash / bond_value;
                bond_units(t,:) = (1 - bond_sales) * bond_units(t,:);
                actual_cash_amount = 0; 
                disp('Bonds sold to pay fixed extract, no cash remaining')
    
            end
    
            
    
    
    
    
            
            
            %          Section 5 - Re-immunisation of trhe portfolio          %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
            % 5a. Update Bond Prices %
            
            
            % Updating the remaining payment dates and the corresponding rates
            ZeroDates   = [(current_date+1):365:Maturity];
            ZeroRates   = RateSpecG2{current_day_ir_simulation}.getZeroRates(ZeroDates);
    
    
            Settle      = current_date;
    
            % Using prbyzero to price the bonds based on their future cash flow
            Price_t = prbyzero([bond_maturity_dates' coupon' face_value' coupons_per_year' bond_basis'],Settle,ZeroRates,ZeroDates)'/10;
            
    
           
    
    
    
            % 5b. Improve the calculation of the duration %
            
            % Calculating duration using bnddury
            for(i=1:length(coupon))
                % Additional variables added and calc is done using a more
                % accurate value for yield so calculation has been improved
                [ModDuration(i),Duration(i),PerDuration(i)] = bnddury(yield(i),coupon(i),Settle,bond_maturity_dates(i),coupons_per_year(i),bond_basis(i),[],[],[],[],[],face_value(i));
            end
            
            % Calculating duration using our function, we decided to use
            % bnddury instead, see report
            % Duration = duration_calculation(list_days_simulation, coupons_per_year, bond_maturity_dates, current_date, face_value, coupon, current_day_ir_simulation, c_spread,Price_t, RateSpecG2);
            
    
    
        
    
            % 5c. Improve the estimation of the PV of Liability %
    
            % Imporved Pv of liability using our yields
    
            diff = fixed_dates - current_date;
            if length(diff) ~= 0
                rate =  getZeroRates(RateSpecG2{current_day_ir_simulation},RateSpecG2{current_day_ir_simulation}.Settle + diff); % using RateSpec Rates 
                months_left_vector = 1:months_remaining_simulation;
                value = fixed_amount_extract./(1+rate'/12).^months_left_vector; % discounting the fixed extracts
                pv_liability                    = sum(value); % summing the present values
            else 
                %PV_liability goes to 0 during last month when we have made all
                %payments
                pv_liability = 0;
            end
    
     
    
    
           % 5d. Include convexity in the immunisation  %
    
           % Using bndconvy to calculate convexity
    
            for(i=1:length(coupon))
                [Convexity(i),PerConvexity(i)] = bndconvy(yield(i),coupon(i),Settle,bond_maturity_dates(i),coupons_per_year(i),bond_basis(i),[],[],[],[],[],face_value(i));
            end
    
            %Calculating convexity using our function, we decided to use
            % bndconvy instead, see report
            % Convexity = convexity_calculation(list_days_simulation, coupons_per_year, bond_maturity_dates, current_date, face_value, coupon, current_day_ir_simulation, c_spread,Price_t, RateSpecG2)
         
    
    
            % 5e - Selecting the immunized portfolio %
           
               
            num_total_bonds         = length(coupon);
            num_combination_bonds   = bonds_selected ; % Here we select the number of bonds of our portfolio
            index_bond = nchoosek([1:num_total_bonds],num_combination_bonds); % This creates the list of ALL the possible combinations of bonds to immunise the portfolio
    
            Maturity_Portfolio  = months_remaining_simulation/12;
            
            % Filling the variables used in the loop as MATLAB can update values more
            % quickly than assigning a new variable
            W = zeros(size(index_bond, 1), num_combination_bonds);
            Units = zeros(size(index_bond, 1), num_combination_bonds);
            Value_portfolio = zeros(size(index_bond, 1), num_combination_bonds);
            TE = zeros(t, size(index_bond, 1));
    
            % Calculate A and b outside the loop to improve efficiency and
            % runtime
            Duration_selected = Duration(index_bond);
            Convexity_selected = Convexity(index_bond);
            Maturity_Portfolio_squared = Maturity_Portfolio.^2;
            
    
            % Finding the tracking error for each portfolio
            for j = 1:size(index_bond, 1)
                % Matrix for solutions
                A = [ones(1, num_combination_bonds);
                     1/pv_liability * Duration_selected(j,:);
                     1/pv_liability * Convexity_selected(j,:)];
    
                b = [pv_liability;
                     Maturity_Portfolio;
                     Maturity_Portfolio_squared];
    
                W(j,:) = A\b;
    
                Units(j,:) = round(W(j,:) ./ Price_t(index_bond(j,:)));
                Value_portfolio(j,:) = Price_t(index_bond(j,:)) .* Units(j,:);
                TE(t:j) = sum(Value_portfolio(j,:)) - pv_liability;
    
               
            end
    
    
    
            % Selecting the portfolio with the smallest absolute tracking error and
            % assigning the number of each bond to the bond_units variable
            [~, immunisation_strategy_selected] = min(abs(TE(t,:)));
            
            if(~any(isnan(Units(immunisation_strategy_selected,:))))
                list_of_bonds_to_use            = index_bond(immunisation_strategy_selected,:);
                list_of_bonds_not_to_use        = setdiff(1:num_total_bonds,index_bond(immunisation_strategy_selected,:));
                bond_units(t,list_of_bonds_to_use) =  Units(immunisation_strategy_selected,:);
                bond_units(t,list_of_bonds_not_to_use) =  0;
                
                % Change in number of bonds
                cash_change = sum((bond_units(t,:)-bond_units(t-1,:)).*Price_t);
                actual_cash_amount = actual_cash_amount - cash_change;
            else
                % No change is made. It's not possible
                bond_units(t,:) = bond_units(t-1,:);
            end
            
            % Assigning the initial portfolio values
            amount_to_invest        = sum(bond_units(t,:).*Price_t);
            bond_weightings         = bond_units(t,:).*Price_t/amount_to_invest;
          
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
            %%%============================================================
    
            if(students_decide_to_do_optional_additional_section)
                
    
                nPeriods = 10;
                nTrials  = 10000;
                [LMMZeroRatesSimPaths, LMMForwardRatesSimPaths] = LMM{current_day_ir_simulation}.simTermStructs(nPeriods+1,'nTrials',nTrials,'antithetic',true);
    
    
    
                %%%============================================================
            end
        else
            bond_units(t,:) = bond_units(t-1,:);
        end
        
    
        %Removing any matured bonds from sim and replacing with cas
        %%%%%%%%%%%%%%%%%%%%%%%%%
        if current_date >= Maturity(1)
            Maturity = Maturity(2:end);
            bond_maturity_dates = bond_maturity_dates(2:end);
            coupon = coupon(2:end);
            face_value = face_value(2:end);
            coupons_per_year = coupons_per_year(2:end);
            bond_basis = bond_basis(2:end);
            value_of_matured_bond  = bond_units(t,1)*Price_t(1);
            bond_units = bond_units(:,2:end);
            bonds_selected = bonds_selected-1;
            num_total_bonds = num_total_bonds-1;
            years_to_maturity = years_to_maturity(2:end)
            c_spread = c_spread(:,2:end);
            bond_weightings = bond_weightings(2:end);
            maturity_month = 1;
            disp('BOND MATURED AND CONVERTED TO CASH')
    
        end
        
        
        if maturity_month == 0
            value_of_matured_bond = 0;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    
        %         Section 6 - Daily updates to the portfolio value            %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        % 6a. Adjusting the bond prices using same process as before %
        Settle      = current_date;
        ZeroDates   = [(current_date+1):365:Maturity];
        ZeroRates   = RateSpecG2{current_day_ir_simulation}.getZeroRates(ZeroDates);
        Price_t = prbyzero([bond_maturity_dates' coupon' face_value' coupons_per_year' bond_basis'],Settle,ZeroRates,ZeroDates)'/10;
    
        
        % Current Valuation:
        portfolio_bonds_current_value(t)= sum(bond_units(t,:).*Price_t); % Where Price_t is the price of bonds today
        cash(t)                         = actual_cash_amount+value_of_matured_bond;
        
        
        % 6b. Improve the estimation of the PV of Liability %
    
        %Using same process as 
        Liability                       = months_remaining_simulation*fixed_amount_extract; % total fixed extracts per month remainings;
        Maturity_Portfolio              = months_remaining_simulation/12;
        n                               = 12; % compounds per year        
    
        diff = fixed_dates - current_date;
    
        if length(diff) ~= 0
            rate =  getZeroRates(RateSpecG2{current_day_ir_simulation},RateSpecG2{current_day_ir_simulation}.Settle + diff); % getting rates
            months_left_vector = 1:months_remaining_simulation;
            value = fixed_amount_extract./(1+rate'/12).^months_left_vector; % discounting
            pv_liability                    = sum(value); % summing discounted values
        else 
            % if its the end of the sim
            pv_liability = 0;
        end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Tracking Error recording and displaying %
    
        TE_final(t)                         =  portfolio_bonds_current_value(t) - pv_liability + value_of_matured_bond; %accounting for any bonds that went to cash
        dates(t)                            =  list_days_simulation(t);
        PV_liability(t)                     = pv_liability;
        
        AUM(t) = portfolio_bonds_current_value(t) + cash(t);
    
        
        disp(['Day ' datestr(list_days_simulation(t)) ' -- AUM: $'  num2str(AUM(t)) ' -- Cash amount: ' num2str(cash(t)) ' -- Bonds Portfolio Value:' num2str(portfolio_bonds_current_value(t)) ' -- Tracking Error: $' num2str(TE_final(t))]);
        
    
    
        % We increase the simulation day counters by the change in current_date
    
        if current_date ~= list_days_simulation(end)
            change_in_days = list_days_simulation(t+1) - list_days_simulation(t);
            current_day_ir_simulation = current_day_ir_simulation + change_in_days; 
        else
            disp('Simulation Complete');
        end
       
        t = t+1;
    end

% Storing the tracking errors from each sim 
TE_simulation{k} = TE_final;


end


% Tracking Error Stats %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%AUM tracking error
aum_te = mean(abs(TE_simulation{1}./AUM))*10000;

%Bond Portfolio Value tracking error
bpv_te = mean(abs(TE_simulation{1}./portfolio_bonds_current_value))*10000;

%PV Liability tracking error
pvl_te = mean(abs(TE_simulation{1}./PV_liability))*10000;

fprintf('AUM TE: %.4f\n', aum_te);
fprintf('BPV TE: %.4f\n', bpv_te);
fprintf('PVL TE: %.4f\n', pvl_te);

% Tracking Error Distribution
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Calculate statistics
TE_array = TE_simulation{1};
mean_TE = mean(TE_array);
min_TE = min(TE_array);
max_TE = max(TE_array);
std_TE = std(TE_array);
skewness_TE = skewness(TE_array);
kurtosis_TE = kurtosis(TE_array);

% Display calculated statistics
fprintf('Mean: %.4f\n', mean_TE);
fprintf('Min: %.4f\n', min_TE);
fprintf('Max: %.4f\n', max_TE);
fprintf('Standard Deviation: %.4f\n', std_TE);
fprintf('Skewness: %.4f\n', skewness_TE);
fprintf('Kurtosis: %.4f\n', kurtosis_TE);

% Plot distribution (histogram)
figure;
histogram(TE_array, 'Normalization', 'probability');
title('Distribution of TE\_simulation');
xlabel('Value');
ylabel('Probability');


% Plots
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Tracking Error plot against AUM
plot(list_days_simulation,(TE_simulation{1}./AUM),'LineWidth',1.0);
title('Tracking Error Over Time against AUM');
xlabel('Dates');
ylabel('Tracking Error');
datetick('x', 'mm/dd/yyyy', 'keepticks')
grid on;

% Calculate percentage of cash and invested weight
percentage_cash = cash ./ (cash + portfolio_bonds_current_value) * 100;
invested_weight = portfolio_bonds_current_value ./ (cash + portfolio_bonds_current_value) * 100;

% Plot both curves on the same plot
plot(list_days_simulation, percentage_cash, 'LineWidth', 1.0);
hold on; % Allow multiple plots on the same axis
plot(list_days_simulation, invested_weight, 'LineWidth', 1.0);

% Customize plot
title('Cash and Invested Weight Over Time');
xlabel('Dates');
ylabel('Percentage');
datetick('x', 'mm/dd/yyyy', 'keepticks');
legend('Cash Percentage', 'Invested Weight');
grid on;
hold off; % Release hold




% Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function duration = duration_calculation(list_days_simulation, coupons_per_year, bond_maturity_dates, current_date, face_value, coupon, current_day_ir_simulation, c_spread,Price_t, RateSpecG2)
    for(i=1:length(coupon))

        % Find all coupon dates which have not passed
        coupon_dates = list_days_simulation(1):ceil(365/coupons_per_year(i)):bond_maturity_dates(i);
        coupon_indices = find(coupon_dates>current_date);
        index_of_first_coupon = min(coupon_indices);
        upcoming_coupon_dates = coupon_dates(index_of_first_coupon:end);
        cash_flows = upcoming_coupon_dates;


        % Calculating the cash flows of each of the bonds including their
        % face value on the very last payment
        cash_flows(:) = face_value(i)*coupon(i);
        cash_flows(end) = cash_flows(end) + face_value(i);


        % Calculating the discount factors
        cf_discounts = 1-((RateSpecG2{current_day_ir_simulation}.getDiscountFactors(upcoming_coupon_dates))-c_spread(i))

        %Discounting future cash flows
        duration_array = [];
        discounted_cf_array = [];
        time_sequence = (1/coupons_per_year(i)):(1/coupons_per_year(i)):length(coupon);
        for(j=1:length(cash_flows))
            discounted_cf_array(j) = cash_flows(1,j)./(1+cf_discounts(j,1)/coupons_per_year(i)).^(j);
            duration_array(j) = (discounted_cf_array(j)./Price_t(i)).*time_sequence(j);
        end

        % Finally getting the sum of duration array to return the final
        % duration value for the bond and storing it in the duration
        % variable
        duration(i) = sum(duration_array); 
    end
end


function convexity = convexity_calculation(list_days_simulation, coupons_per_year, bond_maturity_dates, current_date, face_value, coupon, current_day_ir_simulation, c_spread,Price_t, RateSpecG2)
    for(i=1:length(coupon))

        % Find all coupon dates which have not passed
        coupon_dates = list_days_simulation(1):ceil(365/coupons_per_year(i)):bond_maturity_dates(i);
        coupon_indices = find(coupon_dates>current_date);
        index_of_first_coupon = min(coupon_indices);
        upcoming_coupon_dates = coupon_dates(index_of_first_coupon:end);
        cash_flows = upcoming_coupon_dates;


        % Calculating the cash flows of each of the bonds including their
        % face value on the very last payment
        cash_flows(:) = face_value(i)*coupon(i);
        cash_flows(end) = cash_flows(end) + face_value(i);


        % Calculating the discount factors
        cf_discounts = 1-((RateSpecG2{current_day_ir_simulation}.getDiscountFactors(upcoming_coupon_dates))-c_spread(i))

        %Discounting future cash flows
        convexity_array = [];
        discounted_cf_array = [];
        time_sequence = (1/coupons_per_year(i)):(1/coupons_per_year(i)):length(coupon);
        for(j=1:length(cash_flows))
            discounted_cf_array(j) = cash_flows(1,j)./(1+cf_discounts(j,1)/coupons_per_year(i)).^(j);
            convexity_array(j) = (discounted_cf_array(j)./Price_t(i)).*time_sequence(j)^2; %squaring so we calc convexity and not duration
        end

        % Finally getting the sum of convexity array to return the final
        % convexity value for the bond and storing it in the convexity
        % variable
        convexity(i) = sum(convexity_array); 
    end
end
