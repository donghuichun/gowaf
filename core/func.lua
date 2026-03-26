local _Func = {}

-- 获取ip的前三段
-- @param ip 要处理的ip地址
-- @return ip的前三段，如 192.168.1
function _Func:get_ip_segment(ip)
    local segment = ip:match("^(%d+%.%d+%.%d+)")
    return segment
end

-- 数组强类型判断和空值判断
-- @param arr 要判断的数组
-- @return 如果数组是table类型且非空，则返回该数组，否则返回空数组
function _Func:array_not_empty(arr)
    if arr and type(arr) == "table" and next(arr) ~= nil then
        return arr
    end
    return {}
end

-- 通用值判断
-- @param value 要判断的值
-- @return 如果值为true、非空字符串、非"0"、非"null"、非0、非ngx.null，且不是空数组/表，则返回true，否则返回false
function _Func:value_true_false(value)
    if value and value ~= "" and value ~= "0" and value ~= "null" and value ~= 0 and value ~= ngx.null then
        if type(value) == "table" then
            if not next(value) then
                return false
            end
        end
        return true
    else
        return false
    end
end

-- 变量转成数字，如果不是数字则返回默认值
-- @param value 要转换的值
-- @param default 默认值
-- @return 如果值是数字，则返回该数字，否则返回默认值
function _Func:to_number(value, default)
    if not value then
        return default
    end
    local num = tonumber(value)
    if num then
        return num
    else
        return default
    end
end

-- 获取table的所有key，返回数组
-- @param t 要处理的table
-- @return table的所有key组成的数组
function _Func:table_keys(t)
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

-- 判断 value 是否在 table 数组中
function _Func:is_in_array(value, arr)
    for _, v in ipairs(arr) do
        if v == value then
            return true
        end
    end
    return false
end

-- 路由地址匹配通配符验证
-- @param route_url 路由URL，用于生成缓存键
-- @param req_uri 请求URI，用于匹配路由URL
-- @return 如果路由URL匹配请求URI，则返回true，否则返回false
function _Func:route_url_match(route_url, req_uri)
    if not route_url or not req_uri then
        return false
    end
    local route_len = #route_url
    local req_len = #req_uri
    if route_len > 0 and req_len >= route_len then
        local req_sub = req_uri:sub(1, route_len)
        if req_sub == route_url then
            return true
        end
    end
    return false
end

--[[
解析MySQL DATETIME格式时间字符串
@param time_str: 时间字符串，格式为 "YYYY-MM-DD HH:MM:SS"
@return: 时间戳（秒）或nil
]]
function _Func:parse_mysql_datetime(time_str)
    if not time_str or time_str == "" then
        return nil
    end
    
    local year, month, day, hour, min, sec = time_str:match("^(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)$")
    if not year then
        return nil
    end
    
    return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    })
end

--[[
计算缓存的TTL（秒）
@param expire_time: 过期时间字符串，格式为 "YYYY-MM-DD HH:MM:SS"
@return: ttl, should_cache
    - ttl: 过期秒数，0表示永久
    - should_cache: 是否应该记录缓存
        - 当expire_time有值且未过期：返回剩余秒数，记录缓存
        - 当expire_time有值但已过期：返回0，不记录缓存
        - 当expire_time为NULL/空/0：返回0（永久），记录缓存
]]
function _Func:calculate_ttl(expire_time)
    if not expire_time or expire_time == "" or expire_time == ngx.null or expire_time == 0 then
        return 0, true
    end
    
    local expire_ts = self:parse_mysql_datetime(expire_time)
    if not expire_ts or expire_ts <= 0 then
        return 0, true
    end
    
    local now = ngx.time()
    local ttl = expire_ts - now
    
    if ttl <= 0 then
        return 0, false
    end
    
    return ttl, true
end

return _Func