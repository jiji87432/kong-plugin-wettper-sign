--提取的公共模块
-- load library
local tablex = require "pl.tablex"
local EMPTY = tablex.readonly {}
local kong = kong
local type = type
local mt_cache = { __mode = "k" }
local setmetatable = setmetatable
local consumer_apikeys_cache = setmetatable({}, mt_cache)
local consumer_in_apikeys_cache = setmetatable({}, mt_cache)
local apikeys_secret_cache = setmetatable({}, mt_cache)
local function load_secret_into_memory(apikey)
    local secrets, err = kong.db.wettpersign_credentials:select_by_apikey(apikey)
    if err or secrets == nil then
        return nil, err
    end
    return secrets
end
local function get_apikeys_secret_raw(apikey)
    local cache_key = kong.db.wettpersign_credentials:cache_key(apikey)
    local raw_secret, err = kong.cache:get(cache_key, nil, load_secret_into_memory, apikey)
    if err then
        return nil, err
    end
    -- use EMPTY to be able to use it as a cache key, since a new table would
    -- immediately be collected again and not allow for negative caching.
    return raw_secret or EMPTY
end
local function load_apikeys_into_memory(consumer_pk)
    local apikeys = {}
    local len = 0
    for row, err in kong.db.wettpersign_credentials:each_for_consumer(consumer_pk, 1000) do
        if err then
            return nil, err
        end
        len = len + 1
        apikeys[len] = row
    end
    return apikeys
end
--- Returns the database records with apikeys the consumer belongs to
-- @param consumer_id (string) the consumer for which to fetch the apikeys it belongs to
-- @return table with apikey records (empty table if none), or nil+error
local function get_consumer_apikeys_raw(consumer_id)
    local cache_key = kong.db.wettpersign_credentials:cache_key(consumer_id)
    local raw_apikeys, err = kong.cache:get(cache_key, nil, load_apikeys_into_memory, { id = consumer_id })
    if err then
        return nil, err
    end
    -- use EMPTY to be able to use it as a cache key, since a new table would
    -- immediately be collected again and not allow for negative caching.
    return raw_apikeys or EMPTY
end
--- Returns a table with all apikey names a consumer belongs to.
-- The table will have an array part to iterate over, and a hash part
-- where each apikey name is indexed by itself. Eg.
-- {
--   [1] = "users",
--   [2] = "admins",
--   users = "users",
--   admins = "admins",
-- }
-- If there are no apikeys defined, it will return an empty table
-- @param consumer_id (string) the consumer for which to fetch the apikeys it belongs to
-- @return table with apikeys (empty table if none) or nil+error
local function get_consumer_apikeys(consumer_id)
    local raw_apikeys, err = get_consumer_apikeys_raw(consumer_id)
    if not raw_apikeys then
        return nil, err
    end
    local apikeys = consumer_apikeys_cache[raw_apikeys]
    if not apikeys then
        apikeys = {}
        consumer_apikeys_cache[raw_apikeys] = apikeys
        for i = 1, #raw_apikeys do
            local apikey = raw_apikeys[i].apikey
            apikeys[i] = apikey
            apikeys[apikey] = apikey
        end
    end
    return apikeys
end
--- checks whether a consumer-apikey-list is part of a given list of apikeys.
-- @param apikeys_to_check (table) an array of apikey names. Note: since the
-- results will be cached by this table, always use the same table for the
-- same set of apikeys!
-- @param consumer_apikeys (table) list of consumer apikeys (result from
-- `get_consumer_apikeys`)
-- @return (boolean) whether the consumer is part of any of the apikeys.
local function consumer_in_apikeys(apikeys_to_check, consumer_apikeys)
    -- 1st level cache on "apikeys_to_check"
    local result1 = consumer_in_apikeys_cache[apikeys_to_check]
    if result1 == nil then
        result1 = setmetatable({}, mt_cache)
        consumer_in_apikeys_cache[apikeys_to_check] = result1
    end
    -- 2nd level cache on "consumer_apikeys"
    local result2 = result1[consumer_apikeys]
    if result2 ~= nil then
        return result2
    end
    -- not found, so validate and populate 2nd level cache
    result2 = false
    for i = 1, #apikeys_to_check do
        if consumer_apikeys[apikeys_to_check[i]] then
            result2 = true
            break
        end
    end
    result1[consumer_apikeys] = result2
    return result2
end
--- Gets the currently identified consumer for the request.
-- Checks both consumer and if not found the credentials.
-- @return consumer_id (string), or alternatively `nil` if no consumer was
-- authenticated.
local function get_current_consumer_id()
    return (kong.client.get_consumer() or EMPTY).id or (kong.client.get_credential() or EMPTY).consumer_id
end
--- Returns a table with all apikey names.
-- The table will have an array part to iterate over, and a hash part
-- where each apikey name is indexed by itself. Eg.
-- {
--   [1] = "users",
--   [2] = "admins",
--   users = "users",
--   admins = "admins",
-- }
-- If there are no authenticated_apikeys defined, it will return nil
-- @return table with apikeys or nil
local function get_authenticated_apikeys()
    local authenticated_apikeys = kong.ctx.shared.authenticated_apikeys
    if type(authenticated_apikeys) ~= "table" then
        authenticated_apikeys = ngx.ctx.authenticated_apikeys
        if authenticated_apikeys == nil then
            return nil
        end
        if type(authenticated_apikeys) ~= "table" then
            kong.log.warn("invalid authenticated_apikeys, a table was expected")
            return nil
        end
    end
    local apikeys = {}
    for i = 1, #authenticated_apikeys do
        apikeys[i] = authenticated_apikeys[i]
        apikeys[authenticated_apikeys[i]] = authenticated_apikeys[i]
    end
    return apikeys
end
--- checks whether a apikey-list is part of a given list of apikeys.
-- @param apikeys_to_check (table) an array of apikey names.
-- @param apikeys (table) list of apikeys (result from
-- `get_authenticated_apikeys`)
-- @return (boolean) whether the authenticated apikey is part of any of the
-- apikeys.
local function apikey_in_apikeys(apikeys_to_check, apikeys)
    for i = 1, #apikeys_to_check do
        if apikeys[apikeys_to_check[i]] then
            return true
        end
    end
end
return {
    get_current_consumer_id = get_current_consumer_id,
    get_consumer_apikeys = get_consumer_apikeys,
    get_authenticated_apikeys = get_authenticated_apikeys,
    consumer_in_apikeys = consumer_in_apikeys,
    apikey_in_apikeys = apikey_in_apikeys,
    get_apikeys_secret_raw = get_apikeys_secret_raw,
}
