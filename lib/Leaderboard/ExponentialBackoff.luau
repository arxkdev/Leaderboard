--!strict
-- Exponential backoff implementation
-- This algorithm will be used to find a good rate of requests to send to MemoryStoreService
local Promise = require(script.Parent.Promise);

local function RetryWithBackoff<T>(func: () -> T, maxRetries: number, baseBackoffDelay: number): Promise.TypedPromise<T>
    -- Use promise, Promise will be rejected if maxRetries is reached
    -- Promise will be resolved if func() returns a value
    return Promise.new(function(resolve, reject)
        local Retries = 0;
        local function retry()
            Retries += 1;
            if (Retries > maxRetries) then
                reject(`Current retries ({Retries}) exceeded max retries ({maxRetries})!`);
                return;
            end;

            -- Calculate backoff delay
            local BackoffDelay = baseBackoffDelay * math.pow(2, Retries);

            -- Run function
            local Success, Result = pcall(func);
            if (Success) then
                resolve(Result);
            else
                -- Retry after backoff delay
                task.delay(BackoffDelay, retry);
            end;
        end;

        retry();
    end);
end;

return RetryWithBackoff;