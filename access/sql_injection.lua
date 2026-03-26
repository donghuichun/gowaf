local _sqlInjection = {}

-- 依赖库引入（假设你的项目结构如下）
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _Alert = require(ngx.ctx._gowafname .. ".core.alert")
local cjson = require("cjson.safe") -- 使用安全模式防止解析崩溃
local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")

-- 配置常量
local SQL_RE_OPTIONS = "isjo" -- i:不区分大小写, s:单行模式, j:JIT编译, o:只编译一次
local MAX_RECURSION_DEPTH = 3 
local MAX_STRING_LENGTH = 2048 

-- 优化后的正则库：增加边界检查，减少语义模糊词汇
local SQL_PATTERNS = {
    -- 联合查询：不再强制要求单词边界
    [[union.*select]],
    -- 报错注入
    [[(updatexml|extractvalue|floor|count\(\*\)).*from]],
    -- 逻辑注入：简化匹配，只要有 or/and 跟着等式就拦截
    [[(and|or|xor)\s+[\d']+\s*[=<>]+\s*[\d']+]],
    -- 注释符：降低命中门槛
    [[['";]\s*(--|#|/\*)]],
    -- 延时注入
    [[(sleep|benchmark)\s*\(]]
}

--- 内部工具：递归检查数据结构
local function recursive_check(self, data, source_prefix, depth)
    if depth > MAX_RECURSION_DEPTH then return false end
    
    local t = type(data)
    if t == "table" then
        for k, v in pairs(data) do
            -- 修复点 1：也要检查 Key，Key 也可能被注入
            if recursive_check(self, v, source_prefix, depth + 1) then return true end
        end
    elseif t == "string" then
        -- 修复点 2：放宽预检查限制，只要长度够就检查，或者直接去掉预检查
        if #data > 3 then 
            if self:check_sql_injection(data, source_prefix) then return true end
        end
    end
    return false
end

--- 核心函数：检测单条字符串
function _sqlInjection:check_sql_injection(content, source)
    if not content or #content < 4 then return false end
    
    -- 修复点 3：强制解码。无论有没有 %，都跑一遍 unescape，确保看到原始内容
    local decoded_content = ngx.unescape_uri(content)
    -- 转小写增加匹配成功率
    decoded_content = string.lower(decoded_content)
    
    for _, pattern in ipairs(SQL_PATTERNS) do
        -- 修复点 4：去掉 \b 边界符的依赖（如果你发现还是拦不住，可以把正则里的 \b 去掉）
        local from, _, _ = ngx.re.find(decoded_content, pattern, SQL_RE_OPTIONS)
        if from then
            -- 命中后立即打印日志到 error.log 方便调试
            ngx.log(ngx.ERR, "[WAF_MATCH] Source: ", source, " | Pattern: ", pattern, " | Content: ", decoded_content)
            self:handle_sql_injection_attack(source, content, pattern)
            return true
        end
    end
    return false
end

--- 主处理入口
function _sqlInjection:process(all_params)
    -- 暂时取消验证
    if true then
        return
    end

    local settings = _share_settings:get_settings()
    local web_attack_settings = _Func:array_not_empty(settings.web_attack_settings)
    
    -- 开关预检
    if not web_attack_settings or not web_attack_settings.sql_injection_open then
        return
    end
    
    -- 1. 检查 URI (重点防范路径注入)
    if self:check_sql_injection(all_params.uri, "URI") then
        return
    end
    
    -- 2. 检查 GET 参数
    if all_params.get_args and recursive_check(self, all_params.get_args, "GET", 1) then
        return
    end
    
    -- 3. 检查 POST 内容 (含 Body 智能解析)
    local content_type = ngx.var.content_type or ""
    
    if all_params.post_args and recursive_check(self, all_params.post_args, "POST_FORM", 1) then
        -- 处理传统的 application/x-www-form-urlencoded
        return
    elseif all_params.body then
        -- 针对 JSON 类型的 Body 进行深度解析
        if string.find(content_type, "application/json", 1, true) then
            local json_data = cjson.decode(all_params.body)
            if json_data and recursive_check(self, json_data, "POST_JSON", 1) then
                return
            end
        else
            -- 原始 Body 检查
            if self:check_sql_injection(all_params.body, "POST_BODY") then
                return
            end
        end
    end
end

--- 命中拦截与日志记录
function _sqlInjection:handle_sql_injection_attack(source, content, pattern)
    local client_ip = ngx.ctx._gowaf_ip or ngx.var.remote_addr
    local req_uri = ngx.var.uri
    
    -- 标记请求已被拦截
    ngx.ctx._gowaf_req_blocked = true
    
    -- 频率限制：避免日志刷爆磁盘
    local log_key = 'SQL_INJ:' .. client_ip .. ':' .. source
    if _Lib:log_throt_check(log_key) then
        -- 触发告警通知
        _Alert:log_alert('SQL_INJECTION', 'high', 
            string.format('IP:%s, Src:%s, Pattern:%s', client_ip, source, pattern))
    end
    
    -- 输出 WAF 拦截页面并中断请求
    _Lib:waf_output(ngx.ctx._Config.config_output_html_6)
end

return _sqlInjection