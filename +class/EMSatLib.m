classdef EMSatLib

    % Author.: Eric Magalhães Delgado & Vinicius Puga
    % Date...: July 4, 2023
    % Version: 1.00

    properties
        switchCommand
        switchSocket
        Antenna
        LNB
    end


    methods
        %-----------------------------------------------------------------%
        function obj = EMSatLib(RootFolder)
            % Antenna switch (Matrix)
            Switch = table('Size', [32, 3], ...
                           'VariableTypes', {'double', 'string', 'string'}, ...
                           'VariableNames', {'Port', 'set', 'get'});
            sTerminator = {'[', '\', ']', '^', '_', '`', 'a', 'b', 'c'};
            for ii = 1:height(Switch)
                nPort = num2str(ii);
                if numel(nPort) == 1; nPort = "0" + nPort;
                end
                nTerminator = mod(ii-1, 9);

                Switch(ii,:) = {ii, sprintf("{*zs,012,0%s}%.0f", nPort, nTerminator), sprintf("{zBs?012,0%s}%s", nPort, sTerminator{nTerminator+1})};
            end
            
            % Antenna/LNB list
            tempStruct = jsondecode(fileread(fullfile(RootFolder, 'Settings', 'EMSatLib.json')));

            tempStruct.LNB        = struct2table(tempStruct.LNB);
            tempStruct.LNB.Name   = string(tempStruct.LNB.Name);
            tempStruct.LNB.Offset = uint64(tempStruct.LNB.Offset);

            % Object
            obj.switchCommand = Switch;
            obj.switchSocket  = tempStruct.Switch;
            obj.Antenna       = tempStruct.Antenna;
            obj.LNB           = tempStruct.LNB;
        end


        %-----------------------------------------------------------------%
        function msgError = PositionValueChanged(obj, Antenna, Type)
            msgError = '';

            idx  = find(strcmp({obj.Antenna.Name}, Antenna.Name), 1);
            IP   = obj.Antenna(idx).IP;
            Port = obj.Antenna(idx).Port;

            try
                hACU = SocketCreation(obj, IP, Port);

                switch Type
                    case 'Target'
                        writeline(hACU, sprintf('TT %s T', Antenna.TargetID));

                    case 'LookAngles'
                        % 'IA AAAAA EEEEE PPP.P'
                        % Range: IA AAAAA EEEEE PPPP
                        % Azimuth: 0.00 to 360.00
                        % Elevation: -180.00 to 180.00
                        % Polarization: -180.0 to 180.0
                        writeline(hACU, sprintf('IA %s', Antenna.TargetPosition))
                end
                pause(class.Constants.antACUPause)

            catch  ME
                msgError = ME.message;
            end

            if exist('hACU', 'var'); clear hACU
            end
        end


        %-----------------------------------------------------------------%
        function [pos, msgError] = PositionValueChanging(obj, Antenna)
            pos = [];
            msgError = '';

            idx  = find(strcmp({obj.Antenna.Name}, Antenna.Name), 1);
            IP   = obj.Antenna(idx).IP;
            Port = obj.Antenna(idx).Port;

            try
                hACU = SocketCreation(obj, IP, Port);

                writeline(hACU, '/ CONFIGS ENCODERS CURRENT')
                pause(class.Constants.antACUPause)

                pos = regexp(read(hACU, hACU.NumBytesAvailable, 'char'), '(?<Azimuth>\d{1,3}.\d{1,3}) (?<Elevation>\d{1,3}.\d{1,3}) (?<Polarization>[-]?\d{1,3}.\d{1,3})', 'names');
                if ~isempty(pos)
                    pos = pos(end);
                    
                    pos.Azimuth      = str2double(pos.Azimuth);
                    pos.Elevation    = str2double(pos.Elevation);
                    pos.Polarization = str2double(pos.Polarization);
                    if pos.Polarization < 0; pos.Polarization = 360 + pos.Polarization;
                    end
                end

            catch  ME
                msgError = ME.message;
            end

            if exist('hACU', 'var'); clear hACU
            end
        end


        %-----------------------------------------------------------------%
        function msgError = AntennaSwitch(obj, antennaName)
            % As of July 4, 2023, the L-Band Matrix is not switching to the
            % ports 19, 28 and 29.
            msgError = '';
            
            try
                idx = obj.LNB.Port(find(strcmp(obj.LNB.Name, antennaName), 1));
                hSwitch = tcpclient(obj.switchSocket.IP, obj.switchSocket.Port);

                for ii = 1:class.Constants.switchTimes
                    writeline(hSwitch, obj.switchCommand.set(idx));

                    pause(class.Constants.switchPause)
                    if strcmp(obj.switchCommand.get(idx), read(hSwitch, hSwitch.NumBytesAvailable, 'char'))
                        break
                    else
                        if ii == class.Constants.switchTimes
                            error('A matrix não aceitou a programação...')
                        end
                    end
                end
            catch ME
                msgError = ME.message;
            end
        end


        %-----------------------------------------------------------------%
        function ConfigFile_Update(obj, RootFolder)
            PAUSE = 1;

            % Switch
            switchStruct = struct('IP', '192.168.0.116', 'Port', 4000);

            % Antenna
            antStruct(1) = struct('Name', 'MCL-1', 'ACU', 'GD-7200', 'IP', '10.21.205.45', 'Port', 4002, 'Target', [], 'LOG', '');
            antStruct(2) = struct('Name', 'MCL-2', 'ACU', 'GD-7200', 'IP', '10.21.205.45', 'Port', 4003, 'Target', [], 'LOG', '');
            antStruct(3) = struct('Name', 'MCL-3', 'ACU', '',        'IP', '',             'Port', -1,   'Target', [], 'LOG', '');
            antStruct(4) = struct('Name', 'MCC-1', 'ACU', 'GD-7200', 'IP', '10.21.205.45', 'Port', 4006, 'Target', [], 'LOG', '');
            antStruct(5) = struct('Name', 'MKU-1', 'ACU', 'GD-7200', 'IP', '10.21.205.45', 'Port', 4004, 'Target', [], 'LOG', '');
            antStruct(6) = struct('Name', 'MKU-2', 'ACU', 'GD-7200', 'IP', '10.21.205.45', 'Port', 4005, 'Target', [], 'LOG', '');
            antStruct(7) = struct('Name', 'MKA-1', 'ACU', 'GD-123T', 'IP', '',             'Port', -1,   'Target', [], 'LOG', '');            

            for ii = 1:numel(antStruct)
                IP   = antStruct(ii).IP;
                Port = antStruct(ii).Port;

                try
                    hACU = SocketCreation(obj, IP, Port);

                    writeline(hACU, '/ CONFIGS SITE ANTENNA')
                    pause(PAUSE)

                    if ~contains(read(hACU, hACU.NumBytesAvailable, 'char'), antStruct(ii).Name)
                        error('Não se trata da antena correta...')
                    end

                    writeline(hACU, '/ TRACKING TRACK LS')
                    pause(PAUSE)
                    
                    tgtList = regexp(read(hACU, hACU.NumBytesAvailable, 'char'), '\d{1,2} X (?<ID>T\d{2}) "(?<Name>.*)"', 'names', 'dotexceptnewline');
                    if ~isempty(tgtList)
                        tgtList(deblank({tgtList.Name}) == "") = [];
                        
                        antStruct(ii).Target = struct('ID', {}, 'Name', {}, 'Azimuth', {}, 'Elevation', {}, 'Polarization', {});
                        for jj = 1:numel(tgtList)
                            writeline(hACU, sprintf('TT %s', extractAfter(tgtList(jj).ID, 'T')))
                            pause(PAUSE)

                            tgtInfo = regexp(read(hACU, hACU.NumBytesAvailable, 'char'), '\d{2} \d{2} \d{4} (?<Azimuth>\d{6}) (?<Elevation>\d{6}) (?<Polarization>\d{6})', 'names');
                            if ~isempty(tgtInfo)
                                tgtInfo = tgtInfo(end);
                                
                                tgtInfo.Azimuth      = str2double(tgtInfo.Azimuth)      / 1000;
                                tgtInfo.Elevation    = str2double(tgtInfo.Elevation)    / 1000;
                                tgtInfo.Polarization = str2double(tgtInfo.Polarization) / 1000;
                                if tgtInfo.Polarization < 0; tgtInfo.Polarization = 360+tgtInfo.Polarization;
                                end
                                
                                antStruct(ii).Target(end+1) = struct('ID',           tgtList(jj).ID,    ...
                                                                   'Name',         tgtList(jj).Name,  ...
                                                                   'Azimuth',      tgtInfo.Azimuth,   ...
                                                                   'Elevation',    tgtInfo.Elevation, ...
                                                                   'Polarization', tgtInfo.Polarization);
                            end
                        end
                    end

                    clear hACU

                catch ME
                    antStruct(ii).LOG{end+1} = ME.message;

                    if exist('hACU', 'var'); clear hACU
                    end
                end                
            end

            % LNB
            lnbTable         = table('Size', [24, 4] ,                                        ...
                                     'VariableNames', {'Name', 'Offset', 'Inverted', 'Port'}, ...
                                     'VariableTypes', {'string', 'uint64', 'double', 'double'});
            lnbTable(1:24,:) = {'MCL-1 V',         5150000050, 1,  1; ...
                                'MCL-1 H',         5150000050, 1,  2; ...
                                'MCL-2 V',         5150000050, 1,  3; ...
                                'MCL-2 H',         5150000050, 1,  4; ...
                                'MCC-1 L',         5150000050, 1,  5; ...
                                'MCC-1 R',         5150000050, 1,  6; ...
                                'MCL-3 V',         5760000050, 1,  7; ...
                                'MCL-3 H',         5760000050, 1,  8; ...
                                'MKU-1 LO_V',      9750000000, 0,  9; ...
                                'MKU-1 HI_V',     10750000000, 0, 10; ...
                                'MKU-1 LO_H',      9750000000, 0, 11; ...
                                'MKU-1 HI_H',     10750000000, 0, 12; ...
                                'MKU-2 LO_V',      9750000000, 0, 13; ...
                                'MKU-2 HI_V',     10750000000, 0, 14; ...
                                'MKU-2 LO_H',      9750000000, 0, 15; ...
                                'MKU-2 HI_H',     10750000000, 0, 16; ...
                                'MKA-1 LO_R',     16200000000, 0, 23; ...
                                'MKA-1 MID_R',    17200000000, 0, 23; ...
                                'MKA-1 MID_HI_R', 18200000000, 0, 23; ...
                                'MKA-1 HI_R',     19200000000, 0, 23; ...
                                'MKA-1 LO_L',     16200000000, 0, 24; ...
                                'MKA-1 MID_L',    17200000000, 0, 24; ...
                                'MKA-1 MID_HI_L', 18200000000, 0, 24; ...
                                'MKA-1 HI_L',     19200000000, 0, 24};

            % JSON file
            writematrix(jsonencode(struct('Switch', switchStruct', 'Antenna', antStruct, 'LNB', lnbTable), 'PrettyPrint', true), fullfile(RootFolder, 'Settings', 'EMSatLib.json'), "FileType", "text", "QuoteStrings", false)
        end
    end


    methods (Access = protected)
        %-----------------------------------------------------------------%
        function hACU = SocketCreation(obj, IP, Port)
            hACU = tcpclient(IP, Port);
            configureTerminator(hACU, "CR/LF")

            pause(class.Constants.antACUPause)
            if hACU.NumBytesAvailable
                clear hACU
                error('A ACU deve estar sendo controlada pelo Compass, o que impede o apontamento da antena e giro do LNB de forma automática...')
            end
        end
    end
end
        