--[=[
    @within Logger
    @interface Object
    @field new (moduleName: string, debugEnabled: boolean) -> Logger
    @field Log (self: Logger, logLevel: number, message: string) -> ()
]=]
type Object = {
    new: (moduleName: string, debugEnabled: boolean) -> Logger,
    Log: (self: Logger, logLevel: number, message: string) -> (),
}

--[=[
    @within Logger
    @interface LoggerArguments
    @field _moduleName string
    @field _debugEnabled boolean
]=]
export type LoggerArguments = {
    _moduleName: string,
    _debugEnabled: boolean,
}

--[=[
    @within Logger
    @type Logger () -> Logger
]=]
export type Logger = typeof(setmetatable({} :: LoggerArguments, {} :: Object));

--[=[
    @class Logger
]=]
local Logger: Object = {} :: Object;
Logger.__index = Logger;

--[=[
    @param moduleName string
    @param debugEnabled boolean
    @return Logger

    Constructs a new Logger.
]=]
function Logger.new(moduleName, debugEnabled)
    local self = {};
    self._moduleName = moduleName;
    self._debugEnabled = debugEnabled;
    return setmetatable(self, Logger);
end

--[=[
    @param logLevel number
    @param message string
    @return nil

    Logs a message to the console.
]=]
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