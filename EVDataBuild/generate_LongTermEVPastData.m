%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Date: 7th June 2020
% Editor: Daisuke Kodaira
% e-mail: daisuke.kodaira03@gmail.com
% Description for this code:
%   Make "LongTermEVPastData.csv" from "EVdata.csv" which is original dataset.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function generate_LongTermEVPastData(inputFileName, outputFileName)
    tic;
    
    %% Read and format input data    
    T = readtable(inputFileName,'Format','%d %s %d %d %{dd/MM/yyyy}D %{HH:mm}D %{dd/MM/yyyy}D %{HH:mm}D %f %f %s %s %s');
    % Convert charactor to the number for the k-means and NN
    T = convertCh2Num(T);
    % Add time part to the date data
    T.StartDate = datetime(T.StartDate,'Format','dd/MM/yyyy HH:mm');
    T.EndDate = datetime(T.EndDate,'Format','dd/MM/yyyy HH:mm');
    % Erase the record in case that the EndTime is missing (still connected)
    T = rmmissing(T,'DataVariables',{'EndTime'});
    % Combine the Start date and time
    StartTime = T.StartDate + timeofday(T.StartTime);
    EndTime = T.EndDate + timeofday(T.EndTime);

    %% Process the data; convert contanous time stamps into 15 min inverval data
    % Calculate kwh for 1min; each record has one 1min kwh
    ConnectionDuration = minutes(EndTime - StartTime);
    oneMinutUsage = T.TotalkWh./ConnectionDuration;
    for i = 1:size(ConnectionDuration,1) % erase Inf caused by the case that StartTime and EndTime have exact same time stamp 
        if oneMinutUsage(i) == Inf
            oneMinutUsage(i) = T.TotalkWh(i);
        end
    end

    % Calculate kwh for fragmented time 
    [energyAmount, modifiedStartTime, modifiedEndTime]   = calcFragmentTime(StartTime, EndTime, oneMinutUsage);

    % Make table for outputfiles; calculate 15min kwh for each record
    buildingIndex = 1; % any number is ok

    % Specify each column for each label
    col_building = 1;
    col_year = 2;
    col_month = 3;
    col_day = 4;
    col_hour = 5;
    col_quarter = 6;
    col_P1 = 7; % P1(Day in a week)
    col_P2 = 8; % P2(Holiday or not)
    col_energy = 9;
    col_soc = 10;
    
    % Put default values
    data_matrix = zeros(size(T,1),col_energy);
    steps = 1;

    % Configure matrix for LongTermPastData
    for record = 1:size(T,1)
        curerrentTime = StartTime;
        while curerrentTime(record) <= modifiedEndTime(record)
            data_matrix(steps,col_building) = buildingIndex;                                               % BuildingID; all 1
            data_matrix(steps,col_year) = year(curerrentTime(record));                         % year
            data_matrix(steps,col_month) = month(curerrentTime(record));                      % month
            data_matrix(steps,col_day) = day(curerrentTime(record));                          % Day
            data_matrix(steps,col_hour) = hour(curerrentTime(record));                         % hour
            data_matrix(steps,col_quarter) = floor(minute(curerrentTime(record))/15);      % Quarter
            data_matrix(steps,col_P1) = 0;                                                                         % P1(Day in a week)
            data_matrix(steps,col_P2) = 0;                                                                         % P2(Holiday or not)
            if curerrentTime(record) == StartTime(record)
               data_matrix(steps,col_energy) = energyAmount(record,1);      % Charge/Discharge[kwh]
               curerrentTime = modifiedStartTime;
               steps = steps+1;
            elseif curerrentTime(record) < modifiedEndTime(record)
                data_matrix(steps,col_energy) = 15*oneMinutUsage(record);
                curerrentTime = curerrentTime + minutes(15);
                steps = steps+1;
            else
                data_matrix(steps,col_building) = buildingIndex;                                               % BuildingID; all 1
                data_matrix(steps,col_year) = year(curerrentTime(record));                         % year
                data_matrix(steps,col_month) = month(curerrentTime(record));                      % month
                data_matrix(steps,col_day) = day(curerrentTime(record));                          % Day
                data_matrix(steps,col_hour) = hour(curerrentTime(record));                         % hour
                data_matrix(steps,col_quarter) = floor(minute(curerrentTime(record))/15);      % Quarter
                data_matrix(steps,col_P1) = 0;                                                                    % P1(Day in a week)
                data_matrix(steps,col_P2) = 0;                                                                    % P2(Holiday or not)
                data_matrix(steps,col_energy) = energyAmount(record,2);                         % Charge/Discharge[kwh]
                steps = steps+1;
                break;
            end
        end
        % Display the process for users
        if mod(record,1000) == 0
            fprintf('%.2f [%%]\n', 100*record/size(T,1));
        end
    end

    % Sort the records as time instances
    % sort by year, month, day, hour, quarter 
    data_matrix = sortrows(data_matrix, [col_year col_month col_day col_hour col_quarter]);         

    %% Consolidate energy consumptions for the same time instance -> no bug, confirmed 22th March
    % Define empty space for a duration; year, month, day
    currentDate = min(T.StartDate);
    i = 1;
    while currentDate <= max(T.EndDate)
        calendarMatrix.year(1+(i-1)*96:i*96,1) = ones(96,1).*year(currentDate);
        calendarMatrix.month(1+(i-1)*96:i*96,1) = ones(96,1).*month(currentDate);
        calendarMatrix.day(1+(i-1)*96:i*96,1) = ones(96,1).*day(currentDate);
        currentDate = currentDate + 1;        
        i = i+1;
    end
    % Define hour and quarter
    calendarMatrix.hour(1) = 0;
    calendarMatrix.quarter(1) = 0;       
    for i = 1:size(calendarMatrix.year,1)-1
        calendarMatrix.hour(i+1,1) = mod(i,24);
        calendarMatrix.quarter(i+1,1) = mod(i,4);      
    end
    for i = 1:size(calendarMatrix.year,1)
            calendarMatrix.energy(i,1) = 0;
    end
    
    % Fetch year, month, day, hour, quarter from the
    for record = 1:size(data_matrix,1)
        calendar = cellstr(strcat(num2str(calendarMatrix.year), ...
                                                      num2str(calendarMatrix.month), ...
                                                      num2str(calendarMatrix.day), ...
                                                      num2str(calendarMatrix.hour), ...
                                                      num2str(calendarMatrix.quarter)));
        data = cellstr(strcat(num2str(data_matrix(:,col_year)), ...
                                    num2str(data_matrix(:,col_month)), ...
                                    num2str(data_matrix(:,col_day)), ...
                                    num2str(data_matrix(:,col_hour)), ...
                                    num2str(data_matrix(:,col_quarter))));
        for i = 1:size(calendar,1)
            if data{record} == calendar{i}    
                calendarMatrix.energy(i,1) = calendarMatrix.energy(i,1) + sum(data_matrix(record, col_energy));
            end
        end
    end
        
    % Put SOC [%]
    calendarMatrix.soc= zeros(size(calendarMatrix.energy,1),1);
    
    %% output
    writetable(struct2table(calendarMatrix),'myPatientData.csv');

%     % Write the data to csv files
%     % Write header
%     hedder = {'BuildingIndex', 'Year', 'Month', 'Day', 'Hour', 'Quarter', 'P1(Day in a week)', 'P2(Holiday or not)',...
%                       'Charge/Discharge[kwh]', 'SOC [%]'};
%     fid = fopen(outputFileName,'wt');
%     fprintf(fid,'%s,',hedder{:});
%     fprintf(fid,'\n');
%     % Write data
%     fprintf(fid,['%d,', '%4d,', '%02d,', '%02d,', '%02d,', '%d,', '%d,', '%d,', '%f,', '%f,' '\n'], struct2table(calendarMatrix));
%     fclose(fid);
%     
    % Show the longTermData as an graph
    plot(calendarMatrix.energy);
    
    
    
    
    toc;
    
    
    
end