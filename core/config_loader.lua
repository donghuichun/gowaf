local _ConfigLoader = {}
local json = require("cjson")

local function init_model()
    if not ngx.ctx._ApiModel then
        local Model = require(ngx.ctx._gowafname .. ".admin.api.lib.model")
        ngx.ctx._ApiModel = Model:new(ngx.ctx._Config.config_gowaf_mysql)
    end
end

function _ConfigLoader:load_white_ip_from_db(limit, offset)
    init_model()

    if not ngx.ctx._ApiModel then
        return { list = {}, total = 0 }
    end
    
    local conditions = { state = 1 }
    local list, err = ngx.ctx._ApiModel:getMany("gowaf_whitelist", conditions, 
        {"type", "ip_address", "state", "expire_time"}, limit or 500, offset or 0, "id desc")
    
    if not list then
        return { list = {}, total = 0 }
    end
    
    return { list = list, total = #list }
end

function _ConfigLoader:load_black_ip_from_db(limit, offset)
    init_model()

    if not ngx.ctx._ApiModel then
        return { list = {}, total = 0 }
    end
    
    local conditions = { state = 1 }
    local list, err = ngx.ctx._ApiModel:getMany("gowaf_blacklist", conditions, 
        {"type", "ip_address", "state", "expire_time"}, limit or 500, offset or 0, "id asc")
    
    if not list then
        return { list = {}, total = 0 }
    end
    
    return { list = list, total = #list }
end

function _ConfigLoader:load_api_routes_from_db()
    init_model()

    if not ngx.ctx._ApiModel then
        return { type2_map = {}, type1_map = {} }
    end
    
    local list, err = ngx.ctx._ApiModel:getMany("gowaf_api_route", {}, 
        {"id", "type", "route_url", "tenant_config_open", "tenant_config", 
         "ip_limit_config_open", "ip_limit_config", "member_limit_config_open", 
         "member_limit_config"}, 1000, 0, "id desc")
    
    local type2_map = {}
    local type1_map = {}
    
    if list then
        for _, route in ipairs(list) do
            if route.tenant_config then
                local ok, config = pcall(json.decode, route.tenant_config)
                if ok then
                    route.tenant_config = config
                end
            end
            if route.ip_limit_config then
                local ok, config = pcall(json.decode, route.ip_limit_config)
                if ok then
                    route.ip_limit_config = config
                end
            end
            if route.member_limit_config then
                local ok, config = pcall(json.decode, route.member_limit_config)
                if ok then
                    route.member_limit_config = config
                end
            end
            
            if route.type == 1 then
                type1_map[route.route_url] = route
            elseif route.type == 2 then
                type2_map[route.route_url] = route
            end
        end
    end
    
    return { type2_map = type2_map, type1_map = type1_map }
end

function _ConfigLoader:load_api_routes_count_from_db()
    init_model()

    if not ngx.ctx._ApiModel then
        return nil
    end
    local conditions = { type = 2 }
    return ngx.ctx._ApiModel:count("gowaf_api_route", conditions)
end

function _ConfigLoader:load_settings_from_db()
    init_model()

    if not ngx.ctx._ApiModel then
        return {}
    end
    
    local settings = {}
    local list, err = ngx.ctx._ApiModel:getMany("gowaf_settings", {}, 
        {"type", "content"}, 100, 0, "id asc")
    
    if list then
        for _, item in ipairs(list) do
            if item.content then
                local ok, content = pcall(json.decode, item.content)
                if ok then
                    settings[item.type] = content
                end
            end
        end
    end
    
    return settings
end

return _ConfigLoader
