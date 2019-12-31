package = "kong-plugin-wettper-sign"
version = "1.0.0-0"

local pluginName = 'wettper-sign'

source = {
  url = "git://github.com/jiji87432/kong-plugin-wettper-sign",
  tag = "1.0.0"
}

supported_platforms = {"linux", "macosx"}
description = {
  summary = "Kong Wettper Sign Plugin",
}

build = {
  type = "builtin",
  modules = {
      ["kong.plugins."..pluginName..".api"] = "kong/plugins/"..pluginName.."/api.lua",
      ["kong.plugins."..pluginName..".daos"] = "kong/plugins/"..pluginName.."/daos.lua",
      ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
      ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
      ["kong.plugins."..pluginName..".migrations.postgres"] = "kong/plugins/"..pluginName.."/migrations/init.lua"
    }
}
