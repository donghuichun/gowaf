local _M = {}

local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _Alert = require(ngx.ctx._gowafname .. ".core.alert")
local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")

-- ==============================================================================
-- 100% 高置信度规则池（已剔除易误报词汇，仅保留恶意工具特征）
-- ==============================================================================
local BAD_AGENTS = {
    -- 漏洞扫描与黑客工具
    "sqlmap", "nmap", "nikto", "wpscan", "dirbuster", "burpcli", "acunetix", "netsparker", "wfuzz", "ffuf",
    -- 压测工具
    "apachebench", "jmeter", "loadrunner", "vegeta", "artillery", "wrk", "bombardier", "locust",
    -- 自动化驱动/爬虫框架
    "headlesschrome", "phantomjs", "webdriver", "playwright", "puppeteer", "selenium",
    -- 特定恶意/高频扫描 Bot
    "ahrefsbot", "dotbot", "mj12bot", "exabot", "rogerbot"
}

-- 模块加载时预编译：使用 \b 确保单词边界，防止误伤（如 downloadrunner）
-- 使用 jo 模式：JIT 编译并缓存
local COMBINED_PATTERN = [[\b(]] .. table.concat(BAD_AGENTS, "|") .. [[\b)]]

-- ==============================================================================
-- 内部处理逻辑
-- ==============================================================================

local function handle_user_agent_attack(user_agent, matched_pattern)
    local client_ip = ngx.ctx._gowaf_ip or ngx.var.remote_addr
    ngx.ctx._gowaf_req_blocked = true

    -- 日志节流与记录
    if _Lib:log_throt_check('UA_BLOCK:' .. client_ip) then
        local clean_ua = #user_agent > 128 and (string.sub(user_agent, 1, 128) .. "...") or user_agent
        _Alert:log_alert('USER-AGENT', 'high', string.format('IP: %s, 命中攻击模式: %s', client_ip, matched_pattern))
    end

    _Lib:waf_output(ngx.ctx._Config and ngx.ctx._Config.config_output_html_6 or nil)
end

function _M:process()
    local settings = _share_settings:get_settings()
    local opts = settings and settings.web_attack_settings
    if not opts or not opts.user_agent_check_open then return end

    local ua = ngx.var.http_user_agent
    if not ua or #ua < 5 then return end

    -- 【极致性能优化】
    -- 1. 先用 Lua 原生 string.find 做快速扫描（非正则，极快）
    -- 2. 只有发现 UA 中包含这些工具的“线索”时，才进入复杂的正则引擎
    local low_ua = string.lower(ua)
    local has_threat = false
    
    -- 快速检查最常见的几种威胁关键字
    if string.find(low_ua, "loadrunner", 1, true) or 
       string.find(low_ua, "jmeter", 1, true) or 
       string.find(low_ua, "sqlmap", 1, true) or
       string.find(low_ua, "bot", 1, true) or
       string.find(low_ua, "python", 1, true) then
        has_threat = true
    end

    -- 如果是标准浏览器（Mozilla 开头）且没有明显的威胁线索，直接放行，不走正则
    if string.sub(ua, 1, 7) == "Mozilla" and not has_threat then
        return
    end

    -- 【精确匹配】执行正则检测 (ijo 模式)
    -- 注意：这里使用预编译的 COMBINED_PATTERN
    local from, to = ngx.re.find(ua, COMBINED_PATTERN, "ijo")
    if from then
        local matched = string.sub(ua, from, to)
        handle_user_agent_attack(ua, matched)
    end
end

return _M