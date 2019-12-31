--为 Admin API 增加可操作接口，以便于与插件处理的实体数据进行交互，达到数据管理的目的，非必须
-- load library
local typedefs = require "kong.db.schema.typedefs"
return {
    wettpersign_credentials = {
        name = "wettpersign_credentials",
        primary_key = { "id" },
        endpoint_key = "apikey",
        cache_key = { "apikey" },
        fields = {
            { id = typedefs.uuid },
            { created_at = typedefs.auto_timestamp_s },
            { consumer = { type = "foreign", reference = "consumers", default = ngx.null, on_delete = "cascade", }, },
            { apikey = { type = "string", unique = true, required = false, auto = true } },
            { secret = { type = "string", required = true } },
        },
    },
}
