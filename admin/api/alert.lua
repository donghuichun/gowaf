local _alert = {}
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _share_sync_task = require(ngx.ctx._gowafname .. ".core.share.share_sync_task")
local _blacklist = require(ngx.ctx._gowafname .. ".admin.api.blacklist")

function _alert:query()
    local alert_type = ngx.ctx._Request.alert_type
    local alert_level = ngx.ctx._Request.alert_level
    local status = ngx.ctx._Request.status
    local client_ip = ngx.ctx._Request.client_ip
    local start_time = ngx.ctx._Request.start_time
    local end_time = ngx.ctx._Request.end_time
    local offset = ngx.ctx._Request.offset or 0
    local count = ngx.ctx._Request.count or 20
    
    local conditions = {}
    
    if alert_type and alert_type ~= '' then
        conditions.alert_type = alert_type
    end
    
    if alert_level and alert_level ~= 'all' then
        conditions.alert_level = alert_level
    end
    
    if status and status ~= 'all' then
        conditions.status = status
    end
    
    if client_ip and client_ip ~= '' then
        conditions.client_ip = client_ip
    end
    
    if start_time then
        conditions.created_at = {op = ">=", value = start_time}
    end
    
    if end_time then
        if conditions.created_at then
            conditions.created_at.op = "BETWEEN"
            conditions.created_at.value = {start_time, end_time}
        else
            conditions.created_at = {op = "<=", value = end_time}
        end
    end
    
    local fields = {
        "id", "t_id", "user_id", "alert_type", "alert_level", "client_ip", "request_uri", "request_method",
        "alert_detail", "status", "created_at", "province", "city", "area"
    }
    
    local result, err = ngx.ctx._ApiModel:getMany('gowaf_alert_logs', conditions, fields, count, offset, "created_at DESC")
    
    if not result then
        _ApiCommon:api_output(nil, 500, "查询失败: " .. (err or "未知错误"))
        return
    end
    
    -- 一次性查询所有IP是否在黑名单中
    local ip_list = {}
    for _, alert in ipairs(result) do
        if alert.client_ip and alert.client_ip ~= "" then
            table.insert(ip_list, alert.client_ip)
        end
    end
    
    local blacklisted_ips = {}
    if #ip_list > 0 then
        local blacklist_records = ngx.ctx._ApiModel:getMany('gowaf_blacklist', {
            ip_address = {op = "IN", value = ip_list},
            type = 1,
            state = 1,
            expire_time = {op = ">", value = os.date("%Y-%m-%d %H:%M:%S")}
        }, {"ip_address"})
        
        for _, record in ipairs(blacklist_records) do
            blacklisted_ips[record.ip_address] = true
        end
    end
    
    -- 为每个告警记录设置黑名单标记和账号信息
    for i, alert in ipairs(result) do
        if alert.client_ip and blacklisted_ips[alert.client_ip] then
            result[i].is_blacklisted = true
        else
            result[i].is_blacklisted = false
        end

        -- 格式化账号信息为 "t_id/user_id"
        local t_id = alert.t_id or 0
        local user_id = alert.user_id or ""
        result[i].account_info = tostring(t_id) .. "/" .. user_id
    end
    
    local total, err = ngx.ctx._ApiModel:count('gowaf_alert_logs', conditions)
    if not total then
        total = 0
    end
    
    _ApiCommon:api_output({
        list = result,
        total = total,
        offset = offset,
        count = count
    }, 200, "查询告警记录成功")
end

function _alert:markRead()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ids = ngx.ctx._Request.ids
    if not ids then
        _ApiCommon:api_output(nil, 400, "缺少ids参数")
        return
    end
    
    -- 构建IN条件
    local id_list = {}
    for id in string.gmatch(ids, "[^,]+" ) do
        table.insert(id_list, tonumber(id))
    end
    
    local conditions = {id = {op = "IN", value = id_list}}
    local data = {status = "readed"}
    
    local affected_rows, err = ngx.ctx._ApiModel:update('gowaf_alert_logs', data, conditions)
    
    if not affected_rows then
        _ApiCommon:api_output(nil, 500, "标记失败: " .. (err or "未知错误"))
        return
    end
    
    _ApiCommon:api_output(nil, 200, "标记成功")
end

function _alert:getDetail()
    local id = ngx.ctx._Request.id
    
    if not id then
        _ApiCommon:api_output(nil, 400, "缺少id参数")
        return
    end
    
    local conditions = {id = tonumber(id)}
    local result, err = ngx.ctx._ApiModel:getOne('gowaf_alert_logs', conditions, {
        "id", "t_id", "user_id", "alert_type", "alert_level", "client_ip", "request_uri", "request_method",
        "alert_detail", "status", "created_at", "province", "city", "area"
    })
    
    if not result then
        _ApiCommon:api_output(nil, 404, "告警记录不存在")
        return
    end
    
    _ApiCommon:api_output(result, 200, "查询成功")
end

function _alert:handle()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local id = ngx.ctx._Request.id
    local action = ngx.ctx._Request.action
    
    if not id or not action then
        _ApiCommon:api_output(nil, 400, "缺少必要参数")
        return
    end
    
    local conditions = {id = tonumber(id)}
    local data = {
        status = "handled",
        handled_by = ngx.ctx._AdminInfo.username,
        handled_at = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    local affected_rows, err = ngx.ctx._ApiModel:update('gowaf_alert_logs', data, conditions)
    
    if not affected_rows then
        _ApiCommon:api_output(nil, 500, "处理失败: " .. (err or "未知错误"))
        return
    end
    
    if action == 'block' then
        local alert_data, err = ngx.ctx._ApiModel:getOne('gowaf_alert_logs', conditions, {"client_ip"})
        if alert_data and alert_data.client_ip then
            local ip = alert_data.client_ip
            local expire_time = os.date("%Y-%m-%d %H:%M:%S", os.time() + 7 * 24 * 60 * 60) -- 计算7天后的过期时间
            local remark = "告警手动封禁"
            _blacklist:set_black_ip(ip, 1, expire_time, remark)
        end
    end
    
    _ApiCommon:api_output(nil, 200, "处理成功")
end

return _alert
