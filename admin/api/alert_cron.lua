-- 计划任务执行
local _alert_cron = {}
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local json = require("cjson")
local Model = require(ngx.ctx._gowafname .. ".admin.api.lib.model")
local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")
local _blacklist = require(ngx.ctx._gowafname .. ".admin.api.blacklist")
local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")
local _Func = require(ngx.ctx._gowafname .. ".core.func")

function _alert_cron:consume()
    local alert_queue_key = _Lib:make_share_dict_key('alert_queue')
    -- 获取队列长度
    local queue_len = _share_limit:llen(alert_queue_key)

    if queue_len == 0 then
        _ApiCommon:api_output({
            consumed = 0
        }, 200, "没有待消费的告警日志")
        return
    end

    local consumed = 0

    -- 消费最多100条告警日志
    local max_consume = 100
    local alerts_to_insert = {}

    for i = 1, max_consume do
        local alert_json = _share_limit:rpop(alert_queue_key)

        if not alert_json then
            break
        end

        table.insert(alerts_to_insert, alert_json)
    end

    if #alerts_to_insert == 0 then
        _ApiCommon:api_output({
            consumed = 0
        }, 200, "没有待消费的告警日志")
        return
    end

    -- 检查是否开启自动封禁
    local settings_auto_block = false
    local settings = _share_settings:get_settings()
    local config = settings.ip_single_global_limit
    local config = _Func:array_not_empty(config)
    if next(config) and config.auto_block then
        settings_auto_block = true
    end

    -- 批量插入告警日志
    local consumed = 0
    local data_list = {}
    local high_alert_list = {}
    local current_time = os.date("%Y-%m-%d %H:%M:%S")
    for _, alert_json in ipairs(alerts_to_insert) do
        local alert_data = json.decode(alert_json)

        -- 查询 IP 归属地
        local ip_area = _Lib:get_ip_area(alert_data.client_ip)

        local alert_insert_data = {
            t_id = alert_data.t_id,
            user_id = alert_data.user_id,
            alert_type = alert_data.alert_type,
            alert_level = alert_data.alert_level,
            client_ip = alert_data.client_ip,
            request_uri = alert_data.request_uri,
            request_method = alert_data.request_method,
            alert_detail = alert_data.alert_detail,
            user_agent = alert_data.user_agent,
            status = alert_data.status,
            province = ip_area and ip_area.province or '',
            city = ip_area and ip_area.city or '',
            area = ip_area and ip_area.area or '',
            created_at = alert_data.created_at
        }

        -- high类型处理
        if settings_auto_block and alert_data.alert_level and alert_data.alert_level == 'high' then
            alert_insert_data.status = 'handled'
            alert_insert_data.handled_by = ngx.ctx._AdminInfo.username
            alert_insert_data.handled_at = current_time
            table.insert(high_alert_list, alert_insert_data)
        end

        table.insert(data_list, alert_insert_data)
    end

    local insert_id, affected_rows = ngx.ctx._ApiModel:insertBatch('gowaf_alert_logs', data_list)
    if insert_id then
        consumed = affected_rows
    end

    -- 自动封禁处理，加入黑名单
    if settings_auto_block then
        local uri_prefix_to_check_list = {
            '/api/', '/mall-api/', '/game-api/', '/ugc-api/'
        }
        local expire_time = os.date("%Y-%m-%d %H:%M:%S", os.time() + 15 * 24 * 3600) -- 15天过期
        for _, alert_data in ipairs(high_alert_list) do
            local request_uri = alert_data.request_uri or ''
            local uri_to_block = false
            for _, prefix in ipairs(uri_prefix_to_check_list) do
                if string.sub(request_uri, 1, #prefix) == prefix then
                    uri_to_block = true
                    break
                end
            end
            -- 匹配到需要封禁的URI前缀
            if uri_to_block then
                local black_ip_data = {
                    ip = alert_data.client_ip,
                    state = 1,
                    expire_time = expire_time,
                    created_at = alert_data.created_at
                }
                local remark = '告警自动触发：alert_type:' .. alert_data.alert_type .. ', alert_detail:' .. alert_data.alert_detail
                _blacklist:set_black_ip(alert_data.client_ip, 2, expire_time, remark)
            end
        end
    end

    _ApiCommon:api_output({
        consumed = consumed
    }, 200, "消费告警日志成功")
end

return _alert_cron
