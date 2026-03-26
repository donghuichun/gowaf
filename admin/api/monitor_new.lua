local _monitor_new = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _OperationLog = require(ngx.ctx._gowafname .. ".admin.api.lib.operation_log")

--- 获取实时监控数据（合并接口）
-- @return table 实时监控数据
function _monitor_new:getRealtimeData()
    local current_time = ngx.time()
    -- local current_time = 1773246060
    local today = tonumber(os.date("%Y%m%d", current_time))
    local start_time = current_time - 60
    local current_qps_time = current_time - 2

    -- 取出所有服务器数据
    local server_list = ngx.ctx._ApiModel:getMany("gowaf_servers", {}, {
        "id", "name", "ip", "update_time", "type"
    }, 100, 0, "name ASC")

    -- 取出每日各类型数据
    local today_stat_conditions = {
        type = {op = "IN", value = {2, 3, 4, 5}},
        time = today
    }
    local today_stat_records = ngx.ctx._ApiModel:getMany("gowaf_stat_records", today_stat_conditions, {"server_id", "type", "num"}, 100, 0)

    -- 取出qps记录
    local qps_conditions = {
        type = 1,
        time = {op = "BETWEEN", value = {start_time, current_time}}
    }
    local qps_records = ngx.ctx._ApiModel:getMany("gowaf_stat_records", qps_conditions, {"server_id", "num", "time"}, 500, 0, "time ASC")

    -- 处理全局数据
    local global_data = {
        current_time = current_time,
        current_qps = 0,
        today_requests = 0,
        today_blocks = 0,
        today_locks = 0,
        peak_qps = 0,
        qps_trend = {},
    }
    local today_server = {}
    for _, record in ipairs(today_stat_records) do
        local str_server_id = tostring(record.server_id)
        today_server[str_server_id] = today_server[str_server_id] or {}
        if record.type == 2 then
            today_server[str_server_id].today_requests = record.num
            global_data.today_requests = global_data.today_requests + record.num
        elseif record.type == 3 then
            today_server[str_server_id].today_blocks = record.num
            global_data.today_blocks = global_data.today_blocks + record.num
        elseif record.type == 4 then
            today_server[str_server_id].today_locks = record.num
            global_data.today_locks = global_data.today_locks + record.num
        elseif record.type == 5 then
            today_server[str_server_id].peak_qps = record.num
            global_data.peak_qps = global_data.peak_qps + record.num
        end
    end

    -- 处理qps趋势数据
    local server_qps_trend = {}
    local global_qps_trend = {}
    local time_qps = {}
    local server_qps = {}
    local global_current_qps = 0
    local server_current_qps = {}
    for _, record in ipairs(qps_records) do
        local str_server_id = tostring(record.server_id)
        server_qps_trend[str_server_id] = server_qps_trend[str_server_id] or {}
        server_qps_trend[str_server_id][#server_qps_trend[str_server_id]+1] = {
            time = record.time,
            qps = record.num
        }
        local str_time = tostring(record.time)
        time_qps[str_time] = time_qps[str_time] or 0
        time_qps[str_time] = time_qps[str_time] + record.num

        if tostring(current_qps_time) == str_time then
            global_current_qps = global_current_qps + record.num
            server_current_qps[str_server_id] = record.num
        end
    end
    for str_time, qps in pairs(time_qps) do
        global_qps_trend[#global_qps_trend+1] = {
            time = tonumber(str_time),
            qps = qps
        }
    end
    global_data.current_qps = global_current_qps
    -- global_qps_trend 排序
    table.sort(global_qps_trend, function(a, b) return a.time < b.time end)
    global_data.qps_trend = global_qps_trend

    -- 处理服务器数据
    local server_all = {}
    for _, s in ipairs(server_list) do
        local str_server_id = tostring(s.id)
        local today_server_one = today_server[str_server_id] or {}
        local qps_trend = server_qps_trend[str_server_id] or {}
        local server_data = {
            current_qps = server_current_qps[str_server_id] or 0,
            today_requests = today_server_one.today_requests or 0,
            today_blocks = today_server_one.today_blocks or 0,
            today_locks = today_server_one.today_locks or 0,
            peak_qps = today_server_one.peak_qps or 0,
            server = s,
            qps_trend = qps_trend
        }
        server_data.server.online_status = current_time - s.update_time <= 65 and "online" or "offline"
        server_data.server.online_status_text = current_time - s.update_time <= 65 and "在线" or "离线"

        server_all[#server_all+1] = server_data
    end

    local result = {
        global_data = global_data,
        server_data = server_all
    }
    _ApiCommon:api_output(result, 200, 'success')
end
return _monitor_new
