local _Stat = {}
local json = require("cjson")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")
local CACHE_KEYS = {
    ALL_QPS_KEY = _Lib:make_share_dict_key("all_qps:"),
    TODAY_REQUEST_KEY = _Lib:make_share_dict_key("today_request:"),
    TODAY_BLOCK_KEY = _Lib:make_share_dict_key("today_block:"),
    TODAY_LOCK_KEY = _Lib:make_share_dict_key("today_lock:"),
}

-- 全局QPS统计
-- 每秒记录一次缓存，每个缓存300秒过期，统计每秒的QPS
function _Stat:incr_all_qps()
    local check_time = 6
    local time_key = ngx.time()
    local UID = CACHE_KEYS.ALL_QPS_KEY .. time_key
    
    _share_limit:incr(UID, 1, 0, check_time)
end

-- 获取指定时间点的QPS统计
function _Stat:get_qps_by_time(time)
    local time_key = tostring(time)
    local UID = CACHE_KEYS.ALL_QPS_KEY .. time_key
    local qps, _ = _share_limit:get(UID)
    if not qps then
        qps = 0
    end
    return qps
end

-- 获取最近300条QPS统计
function _Stat:get_all_qps()
    local check_time = 60
    local current_time = ngx.time()
    local qps_data = {}
    
    for i = 0, check_time - 1 do
        local time_key = current_time - i
        local UID = CACHE_KEYS.ALL_QPS_KEY .. time_key
        local qps, _ = _share_limit:get(UID)
        if not qps then
            qps = 0
        end
        table.insert(qps_data, {
            time = time_key,
            qps = qps
        })
    end
    
    return qps_data
end

-- 增加今日统计
function _Stat:incr_today_stats()
    local today = ngx.today()
    local today_request_key = CACHE_KEYS.TODAY_REQUEST_KEY .. today
    local today_block_key = CACHE_KEYS.TODAY_BLOCK_KEY .. today
    local today_lock_key = CACHE_KEYS.TODAY_LOCK_KEY .. today
    
    -- 先存储在ngx.shared中，然后由定时任务同步到Redis
    _share_limit:incr(today_request_key, 1, 0, 86400)
    
    if ngx.ctx._gowaf_req_blocked then
        _share_limit:incr(today_block_key, 1, 0, 86400)
    end
    
    if ngx.ctx._gowaf_req_locked then
        _share_limit:incr(today_lock_key, 1, 0, 86400)
    end
end

-- 获取今日统计
function _Stat:get_today_stats()
    local today = ngx.today()
    local today_request_key = CACHE_KEYS.TODAY_REQUEST_KEY .. today
    local today_block_key = CACHE_KEYS.TODAY_BLOCK_KEY .. today
    local today_lock_key = CACHE_KEYS.TODAY_LOCK_KEY .. today
    
    local today_requests = _share_limit:get(today_request_key) or 0
    local today_blocks = _share_limit:get(today_block_key) or 0
    local today_locks = _share_limit:get(today_lock_key) or 0
    
    return {
        today_requests = today_requests,
        today_blocks = today_blocks,
        today_locks = today_locks
    }
end

return _Stat