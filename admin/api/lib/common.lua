local _apiCommon = {}
local json = require("cjson")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")

function _apiCommon:api_output(data, code, msg)
    -- 跨域
    ngx.header["Content-Type"] = "application/json;charset=UTF-8"
    ngx.header["Access-Control-Allow-Origin"] = "*"
    ngx.header["Access-Control-Allow-Headers"] = "*"
    ngx.header["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    ngx.header["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    ngx.header["Pragma"] = "no-cache"
    if ngx.var.request_method == "OPTIONS" then
        ngx.header["Access-Control-Max-Age"] = "1728000"
        ngx.header["Content-Length"] = "0"
    end
    local data = {
        code = code,
        msg = msg,
        data = data or '',
    }
    ngx.status = ngx.HTTP_OK
    ngx.say(json.encode(data))
    ngx.exit(ngx.status)
end

function _apiCommon:random_string(length)
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local charset_len = #charset
    local length = length or 16
    local ret = {}
    for i = 1, length do
        local r = math.random(1, charset_len)
        ret[i] = charset:sub(r, r)
    end
    return table.concat(ret)
end

function _apiCommon:validate(rules, data)
    local validate = require(ngx.ctx._gowafname .. ".admin.api.lib.validate")
    return validate:validate(rules, data)
end

function _apiCommon:value_true_false(value)
    if value ~= nil and value ~= "" and value ~= "null" and value ~= ngx.null and value ~= false then
        return true
    else
        return false
    end
end

-- 权限验证方法
-- 检查当前用户是否有写权限（超级管理员、普通管理员可以写，只读管理员只能读）
function _apiCommon:check_write_permission()
    local adminInfo = ngx.ctx._AdminInfo
    if not adminInfo then
        self:api_output(nil, 403, '未登录或登录已过期')
        return false
    end
    
    -- role: 1-超级管理员，2-普通管理员，3-只读管理员
    local role = adminInfo.role
    if role == 1 or role == 2 then
        return true
    elseif role == 3 then
        self:api_output(nil, 403, '只读管理员无权限执行此操作')
        return false
    else
        self:api_output(nil, 403, '权限不足')
        return false
    end
end

-- 检查当前用户是否为超级管理员
function _apiCommon:check_super_admin_permission()
    local adminInfo = ngx.ctx._AdminInfo
    if not adminInfo then
        self:api_output(nil, 403, '未登录或登录已过期')
        return false
    end
    
    -- role: 1-超级管理员
    local role = adminInfo.role
    if role == 1 then
        return true
    else
        self:api_output(nil, 403, '只有超级管理员才能执行此操作')
        return false
    end
end

return _apiCommon
