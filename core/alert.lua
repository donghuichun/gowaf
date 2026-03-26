local _Alert = {}
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")

function _Alert:log_alert(alert_type, alert_level, detail)
    local alert_data = {
        t_id = ngx.ctx._gowaf_t_id or 0,
        user_id = ngx.ctx._gowaf_user_id or '',
        alert_type = alert_type,
        alert_level = alert_level,
        client_ip = ngx.ctx._gowaf_ip or ngx.var.remote_addr,
        request_uri = ngx.var.uri or '',
        request_method = ngx.var.request_method or '',
        alert_detail = detail or '',
        -- user_agent = _Lib:get_user_agent() or '',
        status = 'unread',
        created_at = ngx.localtime()
    }
    
    local json = require("cjson")
    local alert_json = json.encode(alert_data)

    _Lib:log_write(alert_json, false) -- 写文件日志 ***临时强制打印***
    
    local alert_queue_key = _Lib:make_share_dict_key('alert_queue')
    
    -- 获取当前队列长度
    local queue_len = _share_limit:llen(alert_queue_key)
    
    -- 如果队列已满（超过1000条），则丢弃最旧的一条
    if queue_len >= 1000 then
        _share_limit:rpop(alert_queue_key)
    end
    
    -- 将新的告警日志添加到队列头部
    _share_limit:lpush(alert_queue_key, alert_json)
end

return _Alert
