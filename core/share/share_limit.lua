local _share_limit = {}
local json = require("cjson")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _share_model = require(ngx.ctx._gowafname .. ".core.share.share_model")
local SHARE_DICT_NAME = ngx.ctx._Config.config_share_dict.limit
local CACHE_KEYS = {
}

-- 清理用户参与缓存
function _share_limit:clear_limit_cache()
    _share_model:flush_all(SHARE_DICT_NAME)
end

function _share_limit:incr(key, value, init, ttl)
    return _share_model:incr(SHARE_DICT_NAME, key, value, init, ttl)
end

-- 设置共享内存中的键值对，可设置过期时间
function _share_limit:set(key, value, ttl)
    return _share_model:set(SHARE_DICT_NAME, key, value, ttl)
end

-- 获取共享内存中的键值
function _share_limit:get(key)
    return _share_model:get(SHARE_DICT_NAME, key)
end

-- 向左推入元素到共享内存列表
function _share_limit:lpush(key, value)
    return _share_model:lpush(SHARE_DICT_NAME, key, value)
end

-- 从共享内存列表右侧弹出元素
function _share_limit:rpop(key)
    return _share_model:rpop(SHARE_DICT_NAME, key)
end

-- 获取共享内存列表的长度
function _share_limit:llen(key)
    return _share_model:llen(SHARE_DICT_NAME, key)
end

return _share_limit