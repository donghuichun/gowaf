local _ipWhite = {}

local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")

-- 白名单IP验证主处理函数
-- 先验证type=1的单个IP（单个key），再验证type=2的网段（单个key）
-- @return 如果IP在白名单中返回true，否则返回false
function _ipWhite:process()
    -- 先检查是否为内部通道
    if _ipWhite:inner_passage() then
        return true
    end

    local clientIp = ngx.ctx._gowaf_ip
    local clientIpSegment = _Func:get_ip_segment(clientIp)
    
    if _share_settings:check_white_ip(clientIp, clientIpSegment) then
        return true
    end
    
    return false
end

-- uri是否跳过gowaf检测
local function uri_skip_check()
    -- 检查请求URI是否在检测名单内
    local uri_prefix_to_check_list = ngx.ctx._Config.config_gowaf_uri_prefix_to_check

    local skip_check = true
    local request_uri = ngx.var.uri or ''
    for _, prefix in ipairs(uri_prefix_to_check_list) do
        if string.sub(request_uri, 1, #prefix) == prefix then
            skip_check = false
            break
        end
    end
    return skip_check
end

function _ipWhite:inner_passage()
    local request_method = ngx.var.request_method
    if request_method == "OPTIONS" then
        ngx.ctx._gowaf_req_access = false
        return true
    end

    -- 如果需要跳过检测，直接返回true
    local skip_check = uri_skip_check()
    if skip_check then
        return true
    end

    return false
end

return _ipWhite
