local _stat = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _OperationLog = require(ngx.ctx._gowafname .. ".admin.api.lib.operation_log")

--- 获取访问统计数据
-- @return table 访问统计数据
function _stat:getAccessStatData()
    local args = ngx.req.get_uri_args()
    local server_id = tonumber(args.server_id) or 0
    local start_date = tonumber(args.start_date) or 0
    local end_date = tonumber(args.end_date) or 0
    
    -- 计算默认时间范围（一个月）
    local current_time = ngx.time()
    local current_date = tonumber(os.date("%Y%m%d", current_time))
    
    if start_date == 0 or end_date == 0 then
        local one_month_ago = current_time - 30 * 24 * 3600
        start_date = tonumber(os.date("%Y%m%d", one_month_ago))
        end_date = current_date
    end
    
    -- 构建查询条件
    local conditions = {
        type = {op = "IN", value = {2, 3, 4, 5}},
        time = {op = "BETWEEN", value = {start_date, end_date}}
    }
    
    if server_id > 0 then
        conditions.server_id = server_id
    end
    
    -- 查询统计数据
    local stat_records = ngx.ctx._ApiModel:getMany("gowaf_stat_records", conditions, {"server_id", "type", "time", "num"}, 1000, 0, "time ASC")
    
    -- 处理数据
    local stat_data = {
        dates = {},
        requests = {},
        blocks = {},
        locks = {},
        peak_qps = {}
    }
    
    -- 生成日期列表
    local date_map = {}
    for date = start_date, end_date do
        table.insert(stat_data.dates, date)
        date_map[tostring(date)] = true
    end
    
    -- 初始化数据数组
    for i = 1, #stat_data.dates do
        stat_data.requests[i] = 0
        stat_data.blocks[i] = 0
        stat_data.locks[i] = 0
        stat_data.peak_qps[i] = 0
    end
    
    -- 填充数据
    for _, record in ipairs(stat_records) do
        local time_str = tostring(record.time)
        local date_index = nil
        for i, date in ipairs(stat_data.dates) do
            if tostring(date) == time_str then
                date_index = i
                break
            end
        end
        
        if date_index then
            if record.type == 2 then
                stat_data.requests[date_index] = record.num
            elseif record.type == 3 then
                stat_data.blocks[date_index] = record.num
            elseif record.type == 4 then
                stat_data.locks[date_index] = record.num
            elseif record.type == 5 then
                stat_data.peak_qps[date_index] = record.num
            end
        end
    end
    
    _ApiCommon:api_output(stat_data, 200, 'success')
end

--- 获取服务器列表
-- @return table 服务器列表
function _stat:getServerList()
    local server_list = ngx.ctx._ApiModel:getMany("gowaf_servers", {}, {"id", "name", "ip", "type"}, 100, 0, "name ASC")
    _ApiCommon:api_output(server_list, 200, 'success')
end

return _stat
