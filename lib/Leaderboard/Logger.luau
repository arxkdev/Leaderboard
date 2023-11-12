type Object = {
    __index: Object,
    new: (moduleName: string, debugEnabled: boolean) -> Logger,
    log: (self: Logger, logLevel: number, message: string) -> (),
}

export type LoggerArguments = {
    _moduleName: string,
    _debugEnabled: boolean,
}

export type Logger = typeof(setmetatable({} :: LoggerArguments, {} :: Object));

local Logger: Object = {} :: Object;
Logger.__index = Logger;

function Logger.new(moduleName, debugEnabled)
    local self = {};
    self._moduleName = moduleName;
    self._debugEnabled = debugEnabled;
    return setmetatable(self, Logger);
end

function Logger:Log(logLevel, message)
    if (not self._debugEnabled) then
        return;
    end;
    if (logLevel == 1) then
        print(string.format("[%s] %s", self._moduleName, message));
    elseif (logLevel == 2) then
        warn(string.format("[%s] %s", self._moduleName, message));
    elseif (logLevel == 3) then
        error(string.format("[%s] %s", self._moduleName, message));
    end;
end

return table.freeze({
    Log = Logger.Log,
    new = Logger.new,
})