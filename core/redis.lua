local _Redis = {}

local redis = require "resty.redis"
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")

-- 获取Redis连接
-- @return redis连接对象
function _Redis:get_connection()
    local red = redis:new()
    
    -- 设置超时时间
    red:set_timeout(1000)
    
    -- 连接Redis
    local ok, err = red:connect(ngx.ctx._Config.config_redis.host, ngx.ctx._Config.config_redis.port)
    if not ok then
        ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
        return nil
    end
    
    -- 认证
    if ngx.ctx._Config.config_redis.password and ngx.ctx._Config.config_redis.password ~= "" then
        local ok, err = red:auth(ngx.ctx._Config.config_redis.password)
        if not ok then
            ngx.log(ngx.ERR, "Failed to auth Redis: ", err)
            return nil
        end
    end
    
    -- 选择数据库
    if ngx.ctx._Config.config_redis.db then
        local ok, err = red:select(ngx.ctx._Config.config_redis.db)
        if not ok then
            ngx.log(ngx.ERR, "Failed to select Redis db: ", err)
            return nil
        end
    end
    
    return red
end

-- 回收Redis连接
-- @param red Redis连接对象
function _Redis:keepalive(red)
    if red then
        local ok, err = red:set_keepalive(ngx.ctx._Config.config_redis.keepalive_timeout, ngx.ctx._Config.config_redis.pool_size)
        if not ok then
            ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
        end
    end
end

-- 执行Redis命令
-- @param cmd 命令名
-- @param ... 命令参数
-- @return 命令执行结果
function _Redis:command(cmd, ...)
    local red = self:get_connection()
    if not red then
        return nil, "Failed to get Redis connection"
    end
    
    local res, err = red[cmd](red, ...)
    
    self:keepalive(red)
    
    return res, err
end

-- 递增计数器
-- @param key 键名
-- @param value 递增的值
-- @param expire 过期时间（秒）
-- @return 递增后的值
function _Redis:incr(key, value, expire)
    local red = self:get_connection()
    if not red then
        return nil, "Failed to get Redis connection"
    end
    
    local res, err = red:incrby(key, value)
    if not res then
        self:keepalive(red)
        return nil, err
    end
    
    if expire then
        red:expire(key, expire)
    end
    
    self:keepalive(red)
    
    return res
end

-- 获取键值
-- @param key 键名
-- @return 键值
function _Redis:get(key)
    return self:command("get", key)
end

-- 设置键值
-- @param key 键名
-- @param value 值
-- @param expire 过期时间（秒）
-- @return 设置结果
function _Redis:set(key, value, expire)
    if expire then
        return self:command("setex", key, expire, value)
    else
        return self:command("set", key, value)
    end
end

-- 添加到列表
-- @param key 键名
-- @param value 值
-- @return 添加结果
function _Redis:lpush(key, value)
    return self:command("lpush", key, value)
end

-- 从列表获取
-- @param key 键名
-- @param start 起始位置
-- @param stop 结束位置
-- @return 列表元素
function _Redis:lrange(key, start, stop)
    return self:command("lrange", key, start, stop)
end

-- 从列表移除
-- @param key 键名
-- @param count 移除数量
-- @param value 值
-- @return 移除结果
function _Redis:lrem(key, count, value)
    return self:command("lrem", key, count, value)
end

-- 获取列表长度
-- @param key 键名
-- @return 列表长度
function _Redis:llen(key)
    return self:command("llen", key)
end

-- 有序集合添加
-- @param key 键名
-- @param score 分数
-- @param member 成员
-- @return 添加结果
function _Redis:zadd(key, score, member)
    return self:command("zadd", key, score, member)
end

-- 有序集合范围查询
-- @param key 键名
-- @param start 起始分数
-- @param stop 结束分数
-- @param withscores 是否返回分数
-- @return 有序集合元素
function _Redis:zrangebyscore(key, start, stop, withscores)
    if withscores then
        return self:command("zrangebyscore", key, start, stop, "WITHSCORES")
    else
        return self:command("zrangebyscore", key, start, stop)
    end
end

-- 有序集合按索引范围查询
-- @param key 键名
-- @param start 起始索引
-- @param stop 结束索引
-- @param withscores 是否返回分数
-- @return 有序集合元素
function _Redis:zrange(key, start, stop, withscores)
    if withscores then
        return self:command("zrange", key, start, stop, "WITHSCORES")
    else
        return self:command("zrange", key, start, stop)
    end
end

-- 有序集合移除
-- @param key 键名
-- @param start 起始分数
-- @param stop 结束分数
-- @return 移除结果
function _Redis:zremrangebyscore(key, start, stop)
    return self:command("zremrangebyscore", key, start, stop)
end

return _Redis