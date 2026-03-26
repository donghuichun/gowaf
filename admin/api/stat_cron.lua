local _stat_cron = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _Stat = require(ngx.ctx._gowafname .. ".core.stat")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local Model = require(ngx.ctx._gowafname .. ".admin.api.lib.model")
local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")
local _Servers = require(ngx.ctx._gowafname .. ".admin.api.servers")

--[[
记录类型:
1-qps
2-一天访问量
3-一天拦截量
4-一天锁定量
5-一天qps峰值
]]

-- qps查询和入库
local function qps_records(time, server_record_id, qps)
    local qps_record = {
        server_id = server_record_id,
        time = time,
        num = qps,
        type = 1,
        t_id = 0
    }
    local ok, err = ngx.ctx._ApiModel:insert("gowaf_stat_records", qps_record)
    if not ok then
        return false
    end
end

-- 访问、拦截、锁定等统计记录查询和入库
local function type_records(time_day, server_record_id, num, type)
    local stat_record = {
        server_id = server_record_id,
        time = time_day,
        num = num,
        type = type,
        t_id = 0
    }
    local ok, err = ngx.ctx._ApiModel:upsert("gowaf_stat_records", stat_record, {'time', 'type', 'server_id', 't_id'})
    if not ok then
        return false
    end
end

-- 检查并更新qps的统计记录
function _stat_cron:add_qps_records()
    local time = ngx.time() - 1 -- 上一秒的时间

    local server_record_id = _Lib:get_server_id()
    if not server_record_id then
        _ApiCommon:api_output(nil, 500, "未找到服务器记录")
    end

    -- 获取上一秒的QPS
    local time_qps = _Stat:get_qps_by_time(time)

    if time_qps and tonumber(time_qps) > 0 then
        qps_records(time, server_record_id, time_qps) -- 插入QPS记录
    end

    _ApiCommon:api_output('', 200, "检查qps统计记录完成")
end

-- 更新访问统计记录
function _stat_cron:update_acess_records()
    local time = ngx.time() - 1 -- 上一秒的时间
    local time_day = os.date("%Y%m%d", time) -- 今日时间如20260311

    local server_record_id = _Lib:get_server_id()
    if not server_record_id then
        _ApiCommon:api_output(nil, 500, "未找到服务器记录")
    end

    -- 获取今日统计
    local today_stats = _Stat:get_today_stats()
    local today_requests = today_stats.today_requests
    local today_blocks = today_stats.today_blocks
    local today_locks = today_stats.today_locks

    type_records(time_day, server_record_id, today_requests, 2) -- 插入请求记录
    type_records(time_day, server_record_id, today_blocks, 3) -- 插入拦截记录
    type_records(time_day, server_record_id, today_locks, 4) -- 插入锁定记录

    _ApiCommon:api_output('', 200, "检查过期统计记录完成")
end

-- qps记录每天峰值
function _stat_cron:qps_peak_records()
    local time = ngx.time()
    local time_day = os.date("%Y%m%d", time) -- 今日时间如20260311

    -- 根据time计算出今日的零点时间戳
    local time_day_start = os.time({year = os.date("%Y", time), month = os.date("%m", time), day = os.date("%d", time), hour = 0, min = 0, sec = 0})

    local server_record_id = _Lib:get_server_id()
    if not server_record_id then
        _ApiCommon:api_output(nil, 500, "未找到服务器记录")
    end

    -- 查询今日qps峰值记录
    local sql = "SELECT max(num) as max FROM gowaf_stat_records WHERE time >= " .. time_day_start .. " AND type = 1 AND server_id = '" .. server_record_id .. "' AND t_id = 0"
    local qps_peak_record, err = ngx.ctx._ApiModel:query(sql)
    if err then
        ngx.log(ngx.ERR, "stat_cron.qps_peak_records 查询qps峰值记录失败: " .. err)
        _ApiCommon:api_output('', 500, "查询qps峰值记录失败")
    end
    local qps = 0
    if qps_peak_record and qps_peak_record[1] and qps_peak_record[1].max then
        qps = qps_peak_record[1].max
    end
    qps = tonumber(qps) or 0
    type_records(time_day, server_record_id, qps, 5)
    _ApiCommon:api_output('', 200, "qps记录每天峰值完成")
end

-- 清理type=1的统计记录
function _stat_cron:clean_type_records()
    local time = ngx.time()
    local min_time = time - 86400 -- 1天前的时间
    local other_time = time - 86400 * 90 -- 90天前的时间
    local other_types = {2, 3, 4, 5}

    -- 查询出server_id对应的记录id
    if not _Lib:is_master_server() then
        _ApiCommon:api_output('', 200, "清理type的统计记录-非主节点")
    end

    -- 删除type=1的小于min_time 的记录
    while true do
        local sql = "DELETE FROM gowaf_stat_records WHERE time < " .. min_time .. " AND type = 1 LIMIT 1000"
        local affected, err = ngx.ctx._ApiModel:execute(sql)
        if not affected then
            ngx.log(ngx.ERR, "stat_cron.clean_type_records 删除qps记录失败: " .. err)
            break
        end
        ngx.log(ngx.ERR, "stat_cron.clean_type_records 删除qps记录成功: " .. affected)
        if affected < 1000 then
            break
        end
    end

    -- 删除type=2,3,4,5的小于other_time 的记录
    local sql = "DELETE FROM gowaf_stat_records WHERE time < " .. other_time .. " AND type in (" .. table.concat(other_types, ",") .. ") AND server_id = '" .. server_record_id .. "' AND t_id = 0"
    local affected, err = ngx.ctx._ApiModel:execute(sql)
    if not affected then
        ngx.log(ngx.ERR, "stat_cron.clean_type1_records 删除其他类型记录失败: " .. err)
    end
    _ApiCommon:api_output('', 200, "清理type的统计记录完成")
end

return _stat_cron
