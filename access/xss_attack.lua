local _xssAttack = {}

local _Lib = require(ngx.ctx._gowafname .. ".core.lib")

local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _Alert = require(ngx.ctx._gowafname .. ".core.alert")

local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")

local XSS_RE_OPTIONS = "isjo" 
local XSS_PATTERNS = {
    -- 1. 危险标签：必须以 < 开头，确保是标签注入
    [=[<(script|iframe|object|embed|applet|canvas|video|audio)\b]=],
    
    -- 2. 事件监听器：必须包含 onxxx= 且前面有空格或标签特征，减少单词误杀
    [=[<\w+\s+[^>]*\bon[a-z]+\s*=\s*['"]?]=],
    
    -- 3. 执行伪协议：javascript/data 后面紧跟冒号，且通常出现在引号内
    [=[['"]\s*(javascript|vbscript|data):]=],
    
    -- 4. 样式表注入：利用 expression 或 url(javascript)
    [=[\bstyle\s*=\s*['"].*?\b(expression|javascript|url\s*)\b]=],
    
    -- 5. 具体的 SVG 注入特征
    [=[<svg\b[^>]*?\bonload\b]=],
}

local MAX_RECURSION_DEPTH = 3
local MAX_STRING_LENGTH = 2048

local function recursive_check(self, data, source_prefix, depth)
    if depth > MAX_RECURSION_DEPTH then return false end
    
    local t = type(data)
    if t == "table" then
        for k, v in pairs(data) do
            if recursive_check(self, v, source_prefix, depth + 1) then return true end
        end
    elseif t == "string" then
        -- 性能门槛：如果字符串里连 < 或 : 或 = 都没有，直接跳过正则
        if #data > 6 and (string.find(data, "<") or string.find(data, ":") or string.find(data, "=")) then
            if self:check_xss_attack(data, source_prefix) then return true end
        end
    end
    return false
end

function _xssAttack:check_xss_attack(content, source)
    if not content or #content < 7 then return false end
    
    -- 只有发现 % 时才解码，减少 CPU 损耗
    local decoded_content = content
    if string.find(content, "%%") then
        decoded_content = ngx.unescape_uri(content)
    end
    
    -- 预检：如果不包含 < 且不包含引号，基本无法构成 XSS
    if not string.find(decoded_content, "<") and not string.find(decoded_content, "['\"]") then
        return false
    end

    for _, pattern in ipairs(XSS_PATTERNS) do
        local from, to = ngx.re.find(decoded_content, pattern, XSS_RE_OPTIONS)
        if from then
            local matched = string.sub(decoded_content, from, to)
            self:handle_xss_attack(source, content, matched)
            return true
        end
    end
    return false
end

function _xssAttack:process(all_params)
    -- 暂时取消验证
    if true then
        return
    end
    
    local settings = _share_settings:get_settings()
    local web_attack_settings = _Func:array_not_empty(settings.web_attack_settings)
    if not web_attack_settings or not web_attack_settings.xss_open then
        return
    end
    
    -- 1. 检查 URI
    if self:check_xss_attack(all_params.uri, "URI") then
        return
    end
    
    -- 2. 检查 GET 参数
    if all_params.get_args and recursive_check(self, all_params.get_args, "GET", 1) then
        return
    end
    
    -- 3. 检查 POST 参数
    if all_params.post_args and recursive_check(self, all_params.post_args, "POST_FORM", 1) then
        return
    end
    
    -- 4. 检查 Raw Body (JSON etc)
    if all_params.body and self:check_xss_attack(all_params.body, "POST_BODY") then
        return
    end
end

function _xssAttack:handle_xss_attack(source, content, pattern)
    local client_ip = ngx.ctx._gowaf_ip or ngx.var.remote_addr
    local req_uri = ngx.var.uri
    
    ngx.ctx._gowaf_req_blocked = true
    
    if _Lib:log_throt_check('XSS_ATTACK:' .. client_ip) then
        _Alert:log_alert('XSS_ATTACK', 'high', 
        string.format('IP: %s, 来源: %s, 命中: %s', client_ip, source, pattern))
    end
    
    
    
    _Lib:waf_output(ngx.ctx._Config.config_output_html_6)
end

return _xssAttack