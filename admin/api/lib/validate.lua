local _apiValidate = {}

--[[
参数验证方法
@param rules table 验证规则配置表
@param data table 待验证数据（可选，默认使用 ngx.ctx._Request）
@return boolean, string 验证成功返回 true,nil；失败返回 false,错误信息

规则配置项说明：
    required    boolean 是否必填
    label       string  字段中文名称
    type        string  类型：'number' 或 'string'
    min         number  数字最小值
    max         number  数字最大值
    min_len     number  字符串最小长度
    max_len     number  字符串最大长度
    pattern     string  正则匹配（Lua正则语法）
    enum        table   枚举值列表

使用示例：
    local _Validate = require(ngx.ctx._gowafname .. ".admin.api.lib.validate")
    local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
    
    -- 验证用户名和密码
    local ok, err = _Validate:validate({
        username = {
            required = true,
            label = "用户名",
            type = "string",
            min_len = 3,
            max_len = 20,
            pattern = "^[a-zA-Z0-9_-]+$"
        },
        password = {
            required = true,
            label = "密码",
            type = "string",
            min_len = 6,
            max_len = 32
        }
    })
    
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end

    -- 验证分页参数
    local ok, err = _Validate:validate({
        offset = {
            type = "number",
            min = 0
        },
        count = {
            type = "number",
            min = 1,
            max = 100
        }
    })

    -- 验证枚举
    local ok, err = _Validate:validate({
        status = {
            required = true,
            label = "状态",
            enum = {1, 2, 3}
        }
    })
]]
function _apiValidate:validate(rules, data)
    local data = data or ngx.ctx._Request or {}
    for field, rule in pairs(rules) do
        local value = data[field]
        if rule.required and (value == nil or value == '') then
            return false, (rule.label or field) .. ' is required'
        end
        if value ~= nil and value ~= '' then
            if rule.type == 'number' then
                local num = tonumber(value)
                if not num then
                    return false, (rule.label or field) .. ' must be a number'
                end
                if rule.min and num < rule.min then
                    return false, (rule.label or field) .. ' must be >= ' .. rule.min
                end
                if rule.max and num > rule.max then
                    return false, (rule.label or field) .. ' must be <= ' .. rule.max
                end
            end
            if rule.type == 'string' then
                local str = tostring(value)
                if rule.min_len and #str < rule.min_len then
                    return false, (rule.label or field) .. ' length must be >= ' .. rule.min_len
                end
                if rule.max_len and #str > rule.max_len then
                    return false, (rule.label or field) .. ' length must be <= ' .. rule.max_len
                end
                if rule.pattern and not str:match(rule.pattern) then
                    return false, (rule.label or field) .. ' format error'
                end
            end
            if rule.enum and type(rule.enum) == 'table' then
                local found = false
                for _, v in ipairs(rule.enum) do
                    if tostring(value) == tostring(v) then
                        found = true
                        break
                    end
                end
                if not found then
                    return false, (rule.label or field) .. ' must be one of: ' .. table.concat(rule.enum, ', ')
                end
            end
        end
    end
    return true, nil
end

return _apiValidate
