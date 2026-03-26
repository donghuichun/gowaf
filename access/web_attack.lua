local _webAttack = {}

local _Lib = require(ngx.ctx._gowafname .. ".core.lib")

local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _Alert = require(ngx.ctx._gowafname .. ".core.alert")

local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")

local RE_OPTS = "isjo"

local RULES = {
    -- 路径穿越：仅保留攻击特征最强的部分
    path_traversal = {
        [=[(?:\.\.\/|\.\.\\|%2e%2e%2f|%2e%2e%5c)]=],
        [=[\b(etc/passwd|etc/shadow|etc/hosts)\b]=],
        [=[\b(boot\.ini|win\.ini|web\.config)\b]=],
        [=[/proc/self/]=]
    },
    -- 命令注入：必须包含 管道/分号 + 危险指令 的组合，避免误杀单个单词
    command_injection = {
        [=[[|&;`$]\s*\b(id|whoami|ifconfig|ipconfig|uname|chmod|chown|wget|curl|nc|bash|sh|perl|python|php|lua)\b]=],
        [=[(?:\$\(|\$\{)]=], -- 子进程调用特征
    },
    -- 敏感文件泄露：仅检查后缀名，针对 URI
    info_leak = {
        [=[\.(env|git|svn|bak|sql|zip|tar\.gz|7z)$]=],
        [=[/(phpmyadmin|wp-config\.php|config\.php\.bak|database\.sql\.gz)]=]
    }
}

local MAX_RECURSION_DEPTH = 3
local MAX_STRING_LENGTH = 1024 -- 攻击载荷通常较短，1024 足够覆盖

-- 快速扫描函数：通过 Lua 原生 find 预检，减少正则调用
local function fast_match(content, rule_type)
    if not content or #content < 4 then return false end
    
    -- 预判：如果连核心符号都没有，直接跳过
    if rule_type == "path_traversal" and not string.find(content, "%.%.") and not string.find(content, "etc") then return false end
    if rule_type == "command_injection" and not string.find(content, "[|&;`$]") then return false end
    
    local patterns = RULES[rule_type]
    local decoded = string.find(content, "%%") and ngx.unescape_uri(content) or content
    
    for _, pat in ipairs(patterns) do
        local from, to = ngx.re.find(decoded, pat, RE_OPTS)
        if from then return true, string.sub(decoded, from, to) end
    end
    return false
end

-- 深度扫描函数：递归检查 Table 结构
local function deep_scan(self, data, rule_type, source, depth)
    if depth > MAX_RECURSION_DEPTH then return false end
    
    if type(data) == "table" then
        for k, v in pairs(data) do
            if deep_scan(self, v, rule_type, source .. ":" .. tostring(k), depth + 1) then return true end
        end
    elseif type(data) == "string" then
        if #data > MAX_STRING_LENGTH then
            data = string.sub(data, 1, MAX_STRING_LENGTH)
        end
        local ok, matched = fast_match(data, rule_type)
        if ok then
            self:handle_web_attack(rule_type, "high", source, data, matched)
            return true
        end
    end
    return false
end

function _webAttack:handle_web_attack(attack_type, severity, source, content, matched)
    local client_ip = ngx.ctx._gowaf_ip or ngx.var.remote_addr
    local req_uri = ngx.var.uri
    
    ngx.ctx._gowaf_req_blocked = true
    
    -- 记录日志，使用缓存节流防止日志爆破
    if _Lib:log_throt_check(attack_type .. ':' .. client_ip) then
        -- 告警
        _Alert:log_alert(attack_type, severity, 
        string.format('IP: %s, 来源: %s, 匹配: %s', client_ip, source, matched))
    end
    
    -- 拦截输出
    _Lib:waf_output(ngx.ctx._Config.config_output_html_6)
end

-- ... (deep_scan 逻辑保持，但调用 fast_match) ...

-- =============================================
-- CSRF 优化：仅针对 域名不一致 且 存在 Referer/Origin 的情况
-- =============================================
function _webAttack:check_csrf()
    local origin = ngx.var.http_origin
    local referer = ngx.var.http_referer
    local host = ngx.var.http_host or ngx.var.host
    
    local source = origin or referer
    if not source then return false end -- 宽松模式：缺失不拦截，防止部分老旧浏览器或无来源请求被杀

    -- 性能：先做字符串定位，再做正则确保边界
    if not string.find(source, host, 1, true) then
        local safe_host = host:gsub("%.", "%%.")
        local pattern = "^https?://" .. safe_host
        if not ngx.re.find(source, pattern, RE_OPTS) then
            self:handle_web_attack('csrf', 'high', 'Header', source, 'Mismatch Host')
            return true
        end
    end
    return false
end

-- =============================================
-- 主业务：合并循环提升效率
-- =============================================
function _webAttack:process(all_params)
    -- 暂时取消验证
    if true then
        return
    end

    local opts = _share_settings:get_settings().web_attack_settings
    if not opts then return end

    -- 1. URI 检查 (路径穿越 + 泄露)
    if opts.info_leak_open and fast_match(all_params.uri, "info_leak") then 
        local ok, matched = fast_match(all_params.uri, "info_leak")
        if ok then self:handle_web_attack("info_leak", "high", "URI", all_params.uri, matched) return end
    end

    -- 2. 参数深度检查 (合并为一次遍历提高性能)
    local targets = { 
        {o = opts.path_traversal_open, t = "path_traversal"}, 
        {o = opts.command_injection_open, t = "command_injection"} 
    }

    for _, check in ipairs(targets) do
        if check.o then
            if all_params.get_args and deep_scan(self, all_params.get_args, check.t, "GET", 1) then return end
            if all_params.post_args and deep_scan(self, all_params.post_args, check.t, "POST", 1) then return end
        end
    end

    -- 3. CSRF (仅 POST/PUT/DELETE)
    local method = ngx.var.request_method
    if opts.csrf_open and (method == "POST" or method == "PUT" or method == "DELETE") then
        if self:check_csrf() then return end
    end
end

return _webAttack