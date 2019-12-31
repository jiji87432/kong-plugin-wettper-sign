--插件 config 配置的 数据结构约束，必须
-- load library
local typedefs = require "kong.db.schema.typedefs"
-- plugin configuration constraints
return {
    name = "wettper-sign",
    fields = {
        { consumer = typedefs.no_consumer },
        { run_on = typedefs.run_on_first },
        { config = {
            type = "record",
            fields = {
                --{ encry_method = { type = "string", default = "md5" }, },
                { header_apikey = { type = "string", default = "Accept-ApiKey" }, },
                { header_apisign = { type = "string", default = "Accept-ApiSign" }, },
                { header_apitime = { type = "string", default = "Accept-ApiTime" }, },
            }
        }
        }
    },
}
