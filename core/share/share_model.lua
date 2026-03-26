local share_model = {}
local _share_model_dict = {}
local json = require "cjson"

local get_share_dict = function(shareName)
    if not _share_model_dict[shareName] then
        _share_model_dict[shareName] = ngx.shared[shareName]
        if not _share_model_dict[shareName] then
            ngx.log(ngx.ERR, "gowaf shared dict not found: ", shareName)
            return nil
        end
    end
    return _share_model_dict[shareName]
end

-- 设置共享内存中的键值对，可设置过期时间
function share_model:set(shareName, key, value, ttl)
    if not ttl or ttl == '' then
        ttl = 0
    end
    ttl = tonumber(ttl)
    local shareDict = get_share_dict(shareName)
    local succ, err, forcible = shareDict:set(key, value, ttl)
    if not succ then
        ngx.log(ngx.ERR, "set share failed, shareName: ", shareName, ", key: ", key, ", value: ", json.encode(value), ", ttl: ", ttl, ", err: ", tostring(err))
    end
    return succ
end

-- 获取共享内存中的键值
function share_model:get(shareName, key)
    local shareDict = get_share_dict(shareName)
    local value, flags = shareDict:get(key)
    return value
end

-- 删除共享内存中的键值对
function share_model:delete(shareName, key)
    local shareDict = get_share_dict(shareName)
    local succ, err = shareDict:delete(key)
    if not succ then
        ngx.log(ngx.ERR, "delete share failed, shareName: ", shareName, ", key: ", key, ", err: ", err)
    end
    return succ
end

-- 增加共享内存中键的值，可设置初始值
function share_model:incr(shareName, key, value, init, ttl)
    local shareDict = get_share_dict(shareName)
    if not init or init == '' then
        init = 0
    end
    init = tonumber(init)
    if not ttl or ttl == '' then
        ttl = 0
    end
    ttl = tonumber(ttl)
    local newval, err, forcible = shareDict:incr(key, value, init, ttl)
    if not newval and err then
        ngx.log(ngx.ERR, "incr share failed, shareName: ", shareName, ", key: ", key, ", value: ", value, ", init: ", init, ", ttl: ", ttl, ", err: ", err, ", stack trace: ", debug.traceback())
    end
    return newval
end


-- 向左推入元素到共享内存列表
function share_model:lpush(shareName, key, value)
    local shareDict = get_share_dict(shareName)
    local length, err = shareDict:lpush(key, value)
    if length == nil and err then
        ngx.log(ngx.ERR, "lpush share failed, shareName: ", shareName, ", key: ", key, ", value: ", value, ", err: ", err, ", stack trace: ", debug.traceback())
    end
    return length
end

-- 从共享内存列表右侧弹出元素
function share_model:rpop(shareName, key)
    local shareDict = get_share_dict(shareName)
    local value, err = shareDict:rpop(key)
    if value == nil and err then
        ngx.log(ngx.ERR, "rpop share failed, shareName: ", shareName, ", key: ", key, ", err: ", err)
    end
    return value
end

-- 获取共享内存列表的长度
function share_model:llen(shareName, key)
    local shareDict = get_share_dict(shareName)
    local length, err = shareDict:llen(key)
    if length == nil and err then
        ngx.log(ngx.ERR, "llen share failed, shareName: ", shareName, ", key: ", key, ", err: ", err)
    end
    return length
end

-- 获取共享内存中的所有键
function share_model:get_keys(shareName, max_count)
    if not max_count or max_count == '' then
        max_count = 1000
    end
    max_count = tonumber(max_count)
    local shareDict = get_share_dict(shareName)
    local keys = shareDict:get_keys(max_count)
    return keys
end

-- 清空共享内存中的所有键值对
function share_model:flush_all(shareName)
    local shareDict = get_share_dict(shareName)
    shareDict:flush_all()
end

-- 清空共享内存中已过期的键值对
function share_model:flush_expired(shareName)
    local shareDict = get_share_dict(shareName)
    shareDict:flush_expired()
end

return share_model
