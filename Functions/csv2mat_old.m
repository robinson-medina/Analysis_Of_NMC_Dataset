% clear; close all; clc;
clear; clc;
% %% Check cell data
% cellNum = ["A2.01_Cell_11" "A2.02_Cell_12" "A2.02_Cell_89" "A2.02_Cell_93" "A2.03_Cell_16" "A2.04_Cell_30" "A2.05_Cell_27" "A2.06_Cell_23" "A2.07_Cell_34" "A2.09_Cell_43" "A2.10_Cell_46" "A2.11_Cell_42"]
for cellNum = ["A1.01_Cell_57"]
    cellNum = char(cellNum);
    % cellNum = 'A1.05_Cell_68';
    path = ['\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\Data\', cellNum, '\raw\detail\'];
    files = dir(strcat(path));

    %% Load data
    % Select relevant files
    idx = [];
    for i=0:9
        idx = [idx; startsWith({files.name},'N')];
    end
    foldersOfInterest = natsortfiles(files(logical(sum(idx))));

    % Load files
    data = [];
    dateTime = [];
    for n=1:numel(foldersOfInterest)
        tic
        temp = table2array(importfile(strcat(files(1).folder,'\',foldersOfInterest(n).name)));
        dataTemp = str2double(temp(:,1:6));
        dataTemp(:,1) = gradient(dataTemp(:,1))/1000;
        if sum(dataTemp(:,1)<0)>0
            dataTemp(dataTemp(:,1)<0,1)=1;
        end
        data = [data; dataTemp];
        dateTime = [dateTime; temp(:,7)];
        toc
        disp(n)
    end
    % figure;plot(cumtrapz(data(:,1)))

    timeYYMMDD = datetime(dateTime(:,1), 'InputFormat', 'yyyy/MM/dd HH:mm:ss'); 

    % Combine the datetime and data into a table
    T = table(timeYYMMDD, data);

    % Sort the table based on the datetime column
    T_sorted = sortrows(T, 'timeYYMMDD');

    % Extract the sorted data
    sorted_data = T_sorted;

    dataCopy = sorted_data.data;
    % dataCopy(data_sorted.data(:,1)<0) = 0;

    sorted_data.data = dataCopy;
    % sorted_data.data(:,1) = cumtrapz(sorted_data.data(:,1));
    %
    % sorted_data.data(:,1) = cumtrapz(sorted_data.data(:,1));
    %
    % % rename headers
    sorted_data.dwellTimeS = cumtrapz(sorted_data.data(:,1));
    sorted_data.stepTimeS = sorted_data.data(:,2)/1000;
    sorted_data.voltageV = sorted_data.data(:,3);
    sorted_data.currentA = sorted_data.data(:,4);
    sorted_data.cellTempC = sorted_data.data(:,5);
    sorted_data.chamberTempC = sorted_data.data(:,6);
    sorted_data(:,{'data'}) = [];

    % figure;plot(sorted_data.timeYYMMDD,sorted_data.data(:,1)/3600)
    % figure;plot(sorted_data.data(:,1)/3600,sorted_data.data(:,3))
    % figure;plot(sorted_data.timeYYMMDD,sorted_data.data(:,3))
    % figure;hold on;plot(sorted_data.timeYYMMDD,cumtrapz(sorted_data.data(:,1),sorted_data.data(:,4))/3600)


    saveName = ['\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\Data\', cellNum, '\processed\full\sorted_data.mat'];
    save(saveName, 'sorted_data');
    saveName = ['\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\Data\', cellNum, '\processed\full\sorted_data_v73.mat'];
    save(saveName, 'sorted_data', '-v7.3');
end