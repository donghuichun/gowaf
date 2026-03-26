-- ip访问频率和限制 --
local _ipLimit = {}

local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local json = require("cjson")
local _Alert = require(ngx.ctx._gowafname .. ".core.alert")
local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")
local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")

function _ipLimit:process()
    -- ip访问频率和限制
    self:checkIpLimit()
    -- ip网段全局访问频率和限制
    self:checkIpSegmentLimit()
end

-- ip访问频率和限制
function _ipLimit:checkIpLimit()
    local settings = _share_settings:get_settings()
    local config = settings.ip_single_global_limit
    local config = _Func:array_not_empty(config)
    if next(config) == nil or not config.open then
        return
    end

    local check_time = _Func:to_number(config.check_time, 2)
    local check_num = _Func:to_number(config.check_num, 30)
    local block_time = _Func:to_number(config.block_time, 5)

    local clientIp = ngx.ctx._gowaf_ip
    local UID = 'ipgl:' .. clientIp
    UID = _Lib:make_share_dict_key(UID)
    _Lib:limit_block_check(UID, ngx.ctx._Config.config_output_html_4)
    local count_now = _share_limit:incr(UID, 1, 0, check_time)
    if count_now > check_num then
        ngx.ctx._gowaf_req_blocked = true
        _Lib:limit_block_add(UID, block_time, count_now, 'IP_LIMIT_GLOBAL')
        if _Lib:log_throt_check(UID) then
            -- 告警
            _Alert:log_alert('IP_LIMIT_GLOBAL', 'medium',
                string.format('IP: %s, 命中模式: %s, 访问次数: %d', clientIp, 'global', count_now))
        end
        _Lib:waf_output(ngx.ctx._Config.config_output_html_4)
    end
end

-- ip网段全局访问频率和限制
function _ipLimit:checkIpSegmentLimit()
    local settings = _share_settings:get_settings()
    local config = settings.ip_segment_global_limit

    if not config or not config.open then
        return
    end

    local check_time = _Func:to_number(config.check_time, 2)
    local check_num = _Func:to_number(config.check_num, 150)
    local block_time = _Func:to_number(config.block_time, 60)

    local clientIp = ngx.ctx._gowaf_ip
    local clientIpSegment = _Func:get_ip_segment(clientIp)

    if clientIpSegment then
        local UID = 'ipsgl:' .. clientIpSegment
        UID = _Lib:make_share_dict_key(UID)
        _Lib:limit_block_check(UID, ngx.ctx._Config.config_output_html_4)
        local count_now = _share_limit:incr(UID, 1, 0, check_time)
        if count_now > check_num then
            _Lib:limit_block_add(UID, block_time, count_now, 'IP_SEGMENT_LIMIT_GLOBAL')
            if _Lib:log_throt_check(UID) then
                -- 告警
                _Alert:log_alert('IP_SEGMENT_LIMIT_GLOBAL', 'medium',
                    string.format('IP: %s, 命中模式: %s, 访问次数: %d', clientIpSegment, 'global', count_now))
            end
            _Lib:waf_output(ngx.ctx._Config.config_output_html_4)
        end
    end
end

return _ipLimit
