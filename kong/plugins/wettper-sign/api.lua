--为 Admin API 增加可操作接口，以便于与插件处理的实体数据进行交互，达到数据管理的目的,非必须
-- load library
local endpoints = require "kong.api.endpoints"
local kong = kong
local wettpersign_schema = kong.db.wettpersign_credentials.schema
local consumers_schema = kong.db.consumers.schema
return {
    -- operating a single piece of data
    ["/wettper-sign/:wettpersign_credentials"] = {
        schema = wettpersign_schema,
        methods = {
            before = function(self, db, helpers)
                if self.req.method ~= "PUT" then
                    local wettpersign, _, err_t = endpoints.select_entity(self, db, wettpersign_schema)
                    if err_t then
                        return endpoints.handle_error(err_t)
                    end
                    if not wettpersign then
                        return kong.response.exit(HTTP_NOT_FOUND, { message = "Not found" })
                    end
                    self.wettpersign_credential = wettpersign
                    self.params.wettpersign_credential = wettpersign.apikey
                end
            end,
            GET = endpoints.get_entity_endpoint(wettpersign_schema),
            PUT = function(self, db, helpers)
                self.args.post.apikey = { apikey = self.params.wettpersign_credential }
                return endpoints.put_entity_endpoint(wettpersign_schema)(self, db, helpers)
            end,
            DELETE = endpoints.delete_entity_endpoint(wettpersign_schema),
        },
    },
    -- get all data or create new data
    ["/wettper-sign"] = {
        schema = wettpersign_schema,
        methods = {
            GET = endpoints.get_collection_endpoint(wettpersign_schema),
            POST = endpoints.post_collection_endpoint(wettpersign_schema),
        }
    },
}
