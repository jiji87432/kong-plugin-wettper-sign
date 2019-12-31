--插件核心文件，每个功能将由Kong在请求的生命周期中的所需时刻运行，由 init.lua 调起，必须
-- load library
local BasePlugin = require "kong.plugins.base_plugin"
local constants = require "kong.constants"
local tablex = require "pl.tablex"
local apikeys = require "kong.plugins.wettper-sign.apikeys"
local json = require "cjson"

local setmetatable = setmetatable
local concat = table.concat
local kong = kong
local ngx = ngx
local ngx_log = ngx.log
local NGX_DEBUG = ngx.DEBUG
local string = string
local fmt = string.format
local EMPTY = tablex.readonly {}
local mt_cache = { __mode = "k" }
local config_cache = setmetatable({}, mt_cache)

-- RESPONSE info
local UNAUTHSIGN = 401
local UNAUTHSIGN_CODE_FAIL = 401000
local UNAUTHSIGN_MEG_FAIL = "sign check fail"
local UNAUTHSIGN_MEG_NOFOUND = "secret is not found"

-- customize header
local WETTPERSIGNCHECK = "WETTPER-SignCheck"
local WETTPERSIGNCHECK_FAL = "not allowed"
local WETTPERSIGNCHECK_SUC = "allowed"

-- load this plugin`s handler module
local WETTPERSIGNHandler = BasePlugin:extend()

-- execution priority of plugins
WETTPERSIGNHandler.PRIORITY = 950
WETTPERSIGNHandler.VERSION = "1.0.0"

function WETTPERSIGNHandler:new()
    WETTPERSIGNHandler.super.new(self, "wettper-sign")
end

-- sort and join all params
local function sort_join_param(args)
    local keys = {}
    local param_str = ""
    for i in pairs(args) do
        table.insert(keys, i)
    end
    table.sort(keys)
    for i, v in pairs(keys) do
        param_str = string.format("%s%s", param_str, tostring(args[v]))
    end
    return param_str
end

-- encryption parameter by md5
local function signature(param_str, path, secret, apitime)
    local raw_string = nil
    if param_str == nil or type(param_str) == nil then
        raw_string = string.format("%s%s%s", path, secret, apitime)
    else
        raw_string = string.format("%s%s%s%s", param_str, path, secret, apitime)
    end
    local sign = ngx.md5(raw_string);
    return sign
end

function WETTPERSIGNHandler:access(conf)
    WETTPERSIGNHandler.super.access(self)
    kong.response.add_header(WETTPERSIGNCHECK, WETTPERSIGNCHECK_FAL);
    -- get verification data from header
    local accept_apikey = kong.request.get_header("Accept-ApiKey")
    local accept_apisign = kong.request.get_header("Accept-ApiSign")
    local accept_apitime = kong.request.get_header("Accept-ApiTime")

    if accept_apikey == nil or accept_apisign == nil or accept_apitime == nil then
        kong.response.exit(UNAUTHSIGN, { message = UNAUTHSIGN_MEG_FAIL, code = UNAUTHSIGN_CODE_FAIL })
    end

    -- get secret from pgsql storage by apikey
    local raw_secrets = apikeys.get_apikeys_secret_raw(accept_apikey);
    if raw_secrets == nil or raw_secrets.secret == nil then
        kong.response.exit(UNAUTHSIGN, { message = UNAUTHSIGN_MEG_NOFOUND, code = UNAUTHSIGN_CODE_FAIL })
    end

    local path = kong.request.get_path()
    if path ~= '/' then
        path = string.sub(path, 2)
    end

    local request_method = ngx.var.request_method
    local args = nil
    local param_str = nil
    if "GET" == request_method then
        args = ngx.req.get_uri_args()
        param_str = sort_join_param(args)
    else
        ngx.req.read_body()
        local body_str = ngx.req.get_body_data()
        if body_str == nil or type(body_str) == nil then
        else
            args = json.decode(body_str)
            param_str = sort_join_param(args)
        end
    end

    -- encryption parameter by md5
    local sign = signature(param_str, path, raw_secrets.secret, accept_apitime)
    if sign ~= accept_apisign then
        kong.response.exit(UNAUTHSIGN, { message = UNAUTHSIGN_MEG_FAIL, code = UNAUTHSIGN_CODE_FAIL })
    end

    kong.response.set_header(WETTPERSIGNCHECK, WETTPERSIGNCHECK_SUC)

end

return WETTPERSIGNHandler

