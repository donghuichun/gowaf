local _main = {}

local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")

-- WAF请求验证主入口
-- 按顺序执行所有验证模块：全局统计 -> 白名单 -> 黑名单 -> SQL注入检测 -> XSS检测 -> 其他Web攻击检测 -> 路由ip和用户限制 -> 全局ip限流 -> 全局路由限流
function _main:process()
    local settings = _share_settings:get_settings()
    local system_settings = _Func:array_not_empty(settings.system_settings)
    local waf_mode = system_settings.waf_mode or 'off'
    if waf_mode ~= 'on' or ngx.var.gowaf_limit_enable == 'off' then
        return
    end

    -- 设置进入WAF
    ngx.ctx._gowaf_req_access = true
    ngx.ctx._gowaf_req_blocked = false
    ngx.ctx._gowaf_req_locked = false

    local _whiteIp = require(ngx.ctx._gowafname .. ".access.ip_white")
    if _whiteIp:process() then
        return
    end

    local _blackIp = require(ngx.ctx._gowafname .. ".access.ip_black")
    _blackIp:process()

    -- 统一读取请求参数（避免重复读取）
    local all_params = {
        uri = ngx.var.request_uri,
        get_args = ngx.req.get_uri_args(),
        post_args = nil,
        body = nil
    }
    
    -- if ngx.var.request_method == "POST" then
    --     ngx.req.read_body()
    --     all_params.post_args = ngx.req.get_post_args()
    --     all_params.body = ngx.req.get_body_data()
    -- end

    local _sqlInjection = require(ngx.ctx._gowafname .. ".access.sql_injection")
    _sqlInjection:process(all_params)

    local _xssAttack = require(ngx.ctx._gowafname .. ".access.xss_attack")
    _xssAttack:process(all_params)

    local _webAttack = require(ngx.ctx._gowafname .. ".access.web_attack")
    _webAttack:process(all_params)

    local _userAgentCheck = require(ngx.ctx._gowafname .. ".access.user_agent_check")
    _userAgentCheck:process()

    local _routeOperateLimit = require(ngx.ctx._gowafname .. ".access.route_operate_limit")
    _routeOperateLimit:process()

    local _ipLimit = require(ngx.ctx._gowafname .. ".access.ip_limit")
    _ipLimit:process()

    local _routeLimit = require(ngx.ctx._gowafname .. ".access.route_limit")
    _routeLimit:process()

end

return _main
