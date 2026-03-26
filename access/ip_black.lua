local _ipBlack = {}

local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local json = require("cjson")
local _Alert = require(ngx.ctx._gowafname .. ".core.alert")
local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")

-- 黑名单IP验证主处理函数
-- 先验证type=1的单个IP（单个key），再验证type=2的网段（单个key）
function _ipBlack:process()
    local clientIp = ngx.ctx._gowaf_ip
    local clientIpSegment = _Func:get_ip_segment(clientIp)
    
    -- 直接从ngx.shared.gowaf_settings读取单个key验证
    local item = _share_settings:check_black_ip(clientIp, clientIpSegment)
    if item then
        ngx.ctx._gowaf_req_blocked = true
        if item.type == 1 then
            if _Lib:log_throt_check('BLACKLIST_IP:' .. clientIp) then
                -- 告警
                _Alert:log_alert('BLACKLIST_IP', 'low', 
                string.format('IP黑名单，IP: %s', clientIp))
            end
        elseif item.type == 2 then
            if _Lib:log_throt_check('BLACKLIST_IP_SEGMENT:' .. clientIpSegment) then
                -- 告警
                _Alert:log_alert('BLACKLIST_IP_SEGMENT', 'low', 
                string.format('IP黑名单网段，IP: %s', clientIpSegment))
            end
        end
        _Lib:waf_output(ngx.ctx._Config.config_output_html_3)
    end
end

return _ipBlack
