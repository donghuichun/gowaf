local _share_settings = {}
local json = require("cjson")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _share_model = require(ngx.ctx._gowafname .. ".core.share.share_model")
local _ConfigLoader = require(ngx.ctx._gowafname .. ".core.config_loader")
local SHARE_DICT_NAME = ngx.ctx._Config.config_share_dict.settings
local DEFAULT_TTL = 0
local CACHE_KEYS = {
    SERVER_DETAIL = _Lib:make_share_dict_key("server:detail"),
    SERVER_IP = _Lib:make_share_dict_key("server:ip"),
    SERVER_UUID = _Lib:make_share_dict_key("server:uuid"),
    LAST_UPDATE_KEY = _Lib:make_share_dict_key("config:last_update"),
    API_ROUTE = _Lib:make_share_dict_key("config:api_route:list"),
    SETTINGS = _Lib:make_share_dict_key("config:settings:all"),
    ROUTE_TYPE2_COUNT = _Lib:make_share_dict_key("config:api_route:type2_count"),
    WHITE_IP_KEY_PREFIX = _Lib:make_share_dict_key("white:ip:"),
    WHITE_SEGMENT_KEY_PREFIX = _Lib:make_share_dict_key("white:segment:"),
    BLACK_IP_KEY_PREFIX = _Lib:make_share_dict_key("black:ip:"),
    BLACK_SEGMENT_KEY_PREFIX = _Lib:make_share_dict_key("black:segment:"),
    ROUTE_TYPE1_KEY_PREFIX = _Lib:make_share_dict_key("route:type1:"),
    ROUTE_TYPE2_KEY_PREFIX = _Lib:make_share_dict_key("route:type2:"),
}

-- 设置服务器ip缓存
function _share_settings:set_server_ip_cache(ip)
    local cache_key = CACHE_KEYS.SERVER_IP
    _share_model:set(SHARE_DICT_NAME, cache_key, ip, 3000)
end

-- 获取服务器ip缓存
function _share_settings:get_server_ip_cache()
    local cache_key = CACHE_KEYS.SERVER_IP
    local ip = _share_model:get(SHARE_DICT_NAME, cache_key)
    if not ip then
        return nil
    end
    return ip
end

-- 设置服务器UUID缓存
function _share_settings:set_server_uuid_cache(uuid)
    local cache_key = CACHE_KEYS.SERVER_UUID
    _share_model:set(SHARE_DICT_NAME, cache_key, uuid, 3000)
end

-- 获取服务器UUID缓存
function _share_settings:get_server_uuid_cache()
    local cache_key = CACHE_KEYS.SERVER_UUID
    local uuid = _share_model:get(SHARE_DICT_NAME, cache_key)
    if not uuid then
        return nil
    end
    return uuid
end

-- 设置服务器节点信息的缓存
function _share_settings:set_server_cache(server)
    local cache_key = CACHE_KEYS.SERVER_DETAIL
    _share_model:set(SHARE_DICT_NAME, cache_key, json.encode(server), 3000)
end

-- 获取服务器节点信息的缓存
function _share_settings:get_server_cache()
    local cache_key = CACHE_KEYS.SERVER_DETAIL
    local server_json = _share_model:get(SHARE_DICT_NAME, cache_key)
    if not server_json then
        return nil
    end
    local ok, data = pcall(json.decode, server_json)
    if ok then
        return data
    end
    return nil
end

-- 清除服务器节点信息的缓存
function _share_settings:clear_server_cache()
    _share_model:delete(SHARE_DICT_NAME, CACHE_KEYS.SERVER_DETAIL)
end

-- 初始化设置缓存
function _share_settings:init_request_context()
    if not ngx.ctx._config_cache then
        ngx.ctx._config_cache = {}
    end
end

-- 获取最后更新时间
function _share_settings:get_last_update()
    return _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.LAST_UPDATE_KEY) or 0
end

-- 设置最后更新时间
function _share_settings:set_last_update()
    local time = ngx.time()
    _share_model:set(SHARE_DICT_NAME, CACHE_KEYS.LAST_UPDATE_KEY, time)
end

-- [[***********管理设置*************]]
-- 清除所有配置缓存
function _share_settings:clear_config_cache()
    _share_model:flush_all(SHARE_DICT_NAME)
    return true
end

-- 获取所有配置
function _share_settings:get_settings()
    local cache_key = CACHE_KEYS.SETTINGS
    self:init_request_context()
    if ngx.ctx._config_cache[cache_key] then
        return ngx.ctx._config_cache[cache_key]
    end

    local data_json = _share_model:get(SHARE_DICT_NAME, cache_key)
    if data_json then
        local ok, data = pcall(json.decode, data_json)
        if ok then
            data = _Func:array_not_empty(data)
            ngx.ctx._config_cache[cache_key] = data
            return data
        end
    end
    return {}
end

-- 保存所有配置
function _share_settings:save_settings()
    local settings = _ConfigLoader:load_settings_from_db()
    local data_json = settings
    if type(settings) == "table" then
        data_json = json.encode(settings)
    end
    _share_model:set(SHARE_DICT_NAME, CACHE_KEYS.SETTINGS, data_json, DEFAULT_TTL)
end

-- [[***********黑白名单规则设置*************]]
-- 封装缓存设置，根据过期时间计算TTL
local function set_cache(key, value, expire_time)
    local ttl, should_cache = _Func:calculate_ttl(expire_time)
    -- 如果已过期，不缓存
    if not should_cache then
        return false
    end

    local value_json = value
    if type(value) == "table" then
        value_json = json.encode(value)
    end
    
    _share_model:set(SHARE_DICT_NAME, key, value_json, ttl)
    return true
end

-- 单个白名单缓存设置
function _share_settings:set_white_cache(item)
    if not item or item.state ~= 1 then
        return false
    end
    
    if item.type == 1 then
        return set_cache(CACHE_KEYS.WHITE_IP_KEY_PREFIX .. item.ip_address, "1", item.expire_time)
    elseif item.type == 2 then
        return set_cache(CACHE_KEYS.WHITE_SEGMENT_KEY_PREFIX .. item.ip_address, "1", item.expire_time)
    end
    return false
end

-- 单个黑名单缓存设置
function _share_settings:set_black_cache(item)
    if not item or item.state ~= 1 then
        return false
    end
    
    if item.type == 1 then
        return set_cache(CACHE_KEYS.BLACK_IP_KEY_PREFIX .. item.ip_address, item, item.expire_time)
    elseif item.type == 2 then
        return set_cache(CACHE_KEYS.BLACK_SEGMENT_KEY_PREFIX .. item.ip_address, item, item.expire_time)
    end
    return false
end

-- 单个白名单缓存删除
function _share_settings:delete_white_cache(item)
    if not item then
        return
    end
    
    if item.type == 1 then
        _share_model:delete(SHARE_DICT_NAME, CACHE_KEYS.WHITE_IP_KEY_PREFIX .. item.ip_address)
    elseif item.type == 2 then
        _share_model:delete(SHARE_DICT_NAME, CACHE_KEYS.WHITE_SEGMENT_KEY_PREFIX .. item.ip_address)
    end
end

-- 单个黑名单缓存删除
function _share_settings:delete_black_cache(item)
    if not item then
        return
    end
    
    if item.type == 1 then
        _share_model:delete(SHARE_DICT_NAME, CACHE_KEYS.BLACK_IP_KEY_PREFIX .. item.ip_address)
    elseif item.type == 2 then
        _share_model:delete(SHARE_DICT_NAME, CACHE_KEYS.BLACK_SEGMENT_KEY_PREFIX .. item.ip_address)
    end
end

-- 更新缓存中的白名单记录（先删除再添加）
function _share_settings:update_white_ip_cache(item)
    self:delete_white_cache(item)
    self:set_white_cache(item)
end

-- 更新缓存中的黑名单记录（先删除再添加）
function _share_settings:update_black_ip_cache(item)
    self:delete_black_cache(item)
    self:set_black_cache(item)
end

-- 批量保存白名单列表到缓存
function _share_settings:save_white_ip_list()
    local page_size = 500
    local offset = 0
    local has_more = true
    
    while has_more do
        local result = _ConfigLoader:load_white_ip_from_db(page_size, offset)
        if result.list and #result.list > 0 then
            for _, item in ipairs(result.list) do
                self:set_white_cache(item)
            end
            offset = offset + page_size
            has_more = #result.list == page_size
        else
            has_more = false
        end
    end
end

-- 批量保存黑名单列表到缓存
function _share_settings:save_black_ip_list()
    local page_size = 500
    local offset = 0
    local has_more = true
    
    while has_more do
        local result = _ConfigLoader:load_black_ip_from_db(page_size, offset)
        if result.list and #result.list > 0 then
            for _, item in ipairs(result.list) do
                self:set_black_cache(item)
            end
            offset = offset + page_size
            has_more = #result.list == page_size
        else
            has_more = false
        end
    end
end

-- 检查IP是否在白名单中
function _share_settings:check_white_ip(ip, ip_segment)
    if _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.WHITE_IP_KEY_PREFIX .. ip) then
        return true
    end
    if ip_segment and _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.WHITE_SEGMENT_KEY_PREFIX .. ip_segment) then
        return true
    end
    return false
end

-- 检查IP是否在黑名单中
function _share_settings:check_black_ip(ip, ip_segment)
    local item = _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.BLACK_IP_KEY_PREFIX .. ip)
    if item then
        local ok, data = pcall(json.decode, item)
        if ok then
            return data
        end
    end
    
    if ip_segment then
        item = _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.BLACK_SEGMENT_KEY_PREFIX .. ip_segment)
        if item then
            local ok, data = pcall(json.decode, item)
            if ok then
                return data
            end
        end
    end
    return nil
end

-- [[********路由配置相关***********]]
-- 新增路由配置到缓存
function _share_settings:add_api_route_to_cache(item, is_update_count)
    if not item then
        return
    end
    
    if item.type == 1 then
        _share_model:set(SHARE_DICT_NAME, CACHE_KEYS.ROUTE_TYPE1_KEY_PREFIX .. item.route_url, json.encode(item), DEFAULT_TTL)
    elseif item.type == 2 then
        _share_model:set(SHARE_DICT_NAME, CACHE_KEYS.ROUTE_TYPE2_KEY_PREFIX .. item.route_url, json.encode(item), DEFAULT_TTL)
    end
    if is_update_count then
        self:update_api_route_count_cache()
    end
end

-- 从缓存中删除路由配置
function _share_settings:remove_api_route_from_cache(item, is_update_count)
    if not item then
        return
    end
    
    if item.type == 1 then
        _share_model:delete(SHARE_DICT_NAME, CACHE_KEYS.ROUTE_TYPE1_KEY_PREFIX .. item.route_url)
    elseif item.type == 2 then
        _share_model:delete(SHARE_DICT_NAME, CACHE_KEYS.ROUTE_TYPE2_KEY_PREFIX .. item.route_url)
    end
    if is_update_count then
        self:update_api_route_count_cache()
    end
end

-- 更新缓存中的路由配置
function _share_settings:update_api_route_cache(item)
    if not item then
        return
    end

    self:add_api_route_to_cache(item, false)
end

-- 更新通配路由个数
function _share_settings:update_api_route_count_cache()
    local count = _ConfigLoader:load_api_routes_count_from_db()
    if not count then
        return
    end
    _share_model:set(SHARE_DICT_NAME, CACHE_KEYS.ROUTE_TYPE2_COUNT, count, DEFAULT_TTL)
end

-- 批量从数据库加载路由配置并保存到缓存
function _share_settings:save_api_routes()
    local list = _ConfigLoader:load_api_routes_from_db()
    if list.type1_map then
        for route_url, item in pairs(list.type1_map) do
            self:add_api_route_to_cache(item, false)
        end
    end
    if list.type2_map then
        for route_url, item in pairs(list.type2_map) do
            self:add_api_route_to_cache(item, false)
        end
    end
    self:update_api_route_count_cache()
end

-- 检查请求URI是否匹配路由配置
function _share_settings:check_api_route(request_uri)
    local item = _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.ROUTE_TYPE1_KEY_PREFIX .. request_uri)
    if item then
        local ok, data = pcall(json.decode, item)
        if ok then
            return data
        end
    end
    
    local type2_count = _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.ROUTE_TYPE2_COUNT) or 0
    if type2_count == 0 then
        return nil
    end
    
    local parts = {}
    for part in request_uri:gmatch("/[^/]*") do
        table.insert(parts, part)
    end
    
    for i = #parts, 1, -1 do
        local prefix = table.concat(parts, "", 1, i)
        item = _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.ROUTE_TYPE2_KEY_PREFIX .. prefix)
        if item then
            local ok, data = pcall(json.decode, item)
            if ok then
                return data
            end
        end
    end
    
    return nil
end

-- 重载所有配置缓存，先删除所有缓存，然后从数据库加载
function _share_settings:refresh_all()
    self:clear_config_cache()
    
    self:save_white_ip_list()
    
    self:save_black_ip_list()
    
    self:save_settings()
end

return _share_settings