classdef specClass

    properties

        ID          {mustBeNumeric}
        taskObj     = []
        Observation = struct('Created',    '', ...                          % Datestring data type - Format: '24/02/2023 14:00:00'
                             'BeginTime',  [], ...                          % Datetime data type
                             'EndTime',    [], ...                          % Datetime data type
                             'StartUp',    [])                              % Datetime data type

        hReceiver                                                           % Handle to Receiver
        hStreaming                                                          % Handle to UDP socket (generated by R&S EB500)
        hGPS                                                                % Handle to GPS
        hSwitch                                                             % Handle to Antenna Switch (handles to ACUs will be deleted after task startup)

        lastGPS     = struct('Status',     0, ...
                             'Latitude',  -1, ...
                             'Longitude', -1)

        SCPI        = struct('scpiSet_Reset',   '', ...
                             'scpiSet_Startup', '', ...
                             'scpiSet_Sync',    '', ...
                             'scpiGet_Att',     '', ...
                             'scpiGet_Data',    '')

        Band        = struct('scpiSet_Config',  '', ...
                             'scpiSet_Att',     '', ...
                             'scpiSet_Answer',  '', ...
                             'Datagrams',       [], ...
                             'DataPoints',      [], ...
                             'SyncModeRef',     -1, ...
                             'Waterfall', struct('idx',      0,   ...
                                                 'Matrix',   []), ...
                             'Mask', struct('Array',         [],  ...
                                            'Count',         [],  ...
                                            'MainPeaks',     []), ...
                             'File', struct('Fileversion',   [],  ...
                                            'Basename',      '',  ...
                                            'Filecount',     [],  ...
                                            'WritedSamples', [],  ...
                                            'CurrentFile',   struct('FullPath',        '',   ...
                                                                    'AlocatedSamples', [],   ...
                                                                    'Handle',          [],   ...
                                                                    'MemMap',          [])), ...
                             'Antenna',         '', ...
                             'Status',          [])

        Status      = ''                                                    % 'Na fila...' | 'Em andamento...' | 'Concluída' | 'Cancelada' | 'Erro'
        LOG         = struct('type', '', ...
                             'time', '', ...
                             'msg',  '')

    end


    methods

        function [specObj, idx] = Fcn_AddTask(specObj, taskObj)

            if isempty([specObj.ID]); idx = 1;
            else;                     idx = numel(specObj)+1;
            end

            specObj(idx).ID          = idx;
            specObj(idx).taskObj     = taskObj;
            specObj(idx).Observation = struct('Created',   datestr(now, 'dd/mm/yyyy HH:MM:SS'),                                                                                         ...
                                              'BeginTime', datetime(taskObj.General.Task.Observation.BeginTime, 'InputFormat', 'dd/MM/yyyy HH:mm:ss', 'Format', 'dd/MM/yyyy HH:mm:ss'), ...
                                              'EndTime',   datetime(taskObj.General.Task.Observation.EndTime,   'InputFormat', 'dd/MM/yyyy HH:mm:ss', 'Format', 'dd/MM/yyyy HH:mm:ss'), ...
                                              'StartUp',   NaT);

            % HANDLES
            specObj(idx).hReceiver   = taskObj.Receiver.Handle;
            specObj(idx).hStreaming  = taskObj.Streaming.Handle;
            specObj(idx).hGPS        = taskObj.GPS.Handle;
            specObj(idx).hSwitch     = taskObj.Antenna.Switch.Handle;

            % GPS/SCPI/BAND
            specObj(idx).lastGPS     = struct('Status', 0, 'Latitude', -1, 'Longitude', -1);
            
            warnMsg  = {};
            errorMsg = '';
            try
                [specObj(idx).SCPI, specObj(idx).Band, warnMsg] = connect_Receiver_WriteReadTest(taskObj);
            catch ME
                errorMsg = ME.message;
            end
            
            % STATUS/LOG
            specObj(idx).LOG = struct('type', {}, 'time', {}, 'msg',  {});            
            if isempty(errorMsg)
                specObj(idx).Status = 'Na fila...';
            else
                specObj(idx).Status = 'Erro';
                specObj(idx).LOG(end+1) = struct('type', 'error', 'time', specObj(idx).Observation.Created, 'msg', errorMsg);
            end
            
            if ~isempty(warnMsg)
                specObj(idx).LOG{end+1} = struct('type', 'warning', 'time', specObj(idx).Observation.Created, 'msg', warnMsg);
            end

        end


        function specObj = Fcn_DelTask(specObj, idx)

            if (idx <= numel(specObj)) & (numel([specObj.ID]) > 1)
                specObj(idx) = [];

                for ii = 1:numel(specObj)
                    specObj(ii).ID = ii;
                end
            end

        end

    end
end