function neuralNetEV_Training(LongTermpastData, colPredictors, path)
    disp('Training the Neraul network....');
    %% PastData
    trainData = LongTermpastData(1:(end-96*7),:);    % PastData load
    
    %% Train the model for Energy Transition
    % Training for Energy Trantision
    colTarget = 9; % the column of Energy Transition
    trainedNet_EnergTrans = NeuralNet_train(trainData, colPredictors, colTarget);
    % Training for SOC
    colTarget = 10; % the column of SOC
    trainedNet_SOC = NeuralNet_train(trainData, colPredictors, colTarget);
    
    %% save result mat file
    clearvars input;
    clearvars shortTermPastData;
    building_num = num2str(LongTermpastData(2,1));
    save_name = '\EV_NeuralNetwork_';
    save_name = strcat(path,save_name,building_num,'.mat');
    clearvars path;
    save(save_name,'EVnetworks');
    disp('Training the Neraul network....Done!');
end

function trainedNet = NeuralNet_train(trainData, columnPredictors, columnTarget)
    % Iterete 3 times to make average of them. (more than 3 is also acceptable)
    % The forecasting error from randomness of neural network is reduced.
    maxLoop = 3;
    % Number of instances in the training data set
    n_instance = size(trainData,1);        
    % Training
    for i = 1:maxLoop
        x = transpose(trainData(1:n_instance, columnPredictors)); % input(feature)
        t = transpose(trainData(1:n_instance, columnTarget)); % target
        % Create and display the network
        net = fitnet([20,20,20,15],'trainscg');
        net.trainParam.showWindow = false;
        net = train(net,x,t); % Train the network using the data in x and t
        trainedNet{i} = net;             % save result
    end   

end