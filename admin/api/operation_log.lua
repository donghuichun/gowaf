local _operationLog = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")

function _operationLog:query()
    local ok, err = _ApiCommon:validate({
        offset = { type = "number", min = 0 },
        count = { type = "number", min = 1, max = 100 },
        admin_username = { type = "string", max_len = 64 },
        operation_type = { type = "string", max_len = 64 },
        operation_module = { type = "string", max_len = 64 },
        operation_result = { type = "number", enum = {1, 2} },
        create_time_start = { type = "string" },
        create_time_end = { type = "string" }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    
    local offset = ngx.ctx._Request.offset or 0
    local count = ngx.ctx._Request.count or 20
    local conditions = {}
    
    if ngx.ctx._Request.admin_username and ngx.ctx._Request.admin_username ~= "" then
        conditions.admin_username = {op = "LIKE", value = ngx.ctx._Request.admin_username}
    end
    if ngx.ctx._Request.operation_type and ngx.ctx._Request.operation_type ~= "" then
        conditions.operation_type = {op = "LIKE", value = ngx.ctx._Request.operation_type}
    end
    if ngx.ctx._Request.operation_module and ngx.ctx._Request.operation_module ~= "" then
        conditions.operation_module = {op = "LIKE", value = ngx.ctx._Request.operation_module}
    end
    if ngx.ctx._Request.operation_result then
        conditions.operation_result = tonumber(ngx.ctx._Request.operation_result)
    end
    if ngx.ctx._Request.create_time_start and ngx.ctx._Request.create_time_start ~= "" then
        if ngx.ctx._Request.create_time_end and ngx.ctx._Request.create_time_end ~= "" then
            conditions.create_time = {
                op = "BETWEEN",
                value = {
                    ngx.ctx._Request.create_time_start,
                    ngx.ctx._Request.create_time_end
                }
            }
        else
            conditions.create_time = {op = ">=", value = ngx.ctx._Request.create_time_start}
        end
    elseif ngx.ctx._Request.create_time_end and ngx.ctx._Request.create_time_end ~= "" then
        conditions.create_time = {op = "<=", value = ngx.ctx._Request.create_time_end}
    end
    
    local total, err = ngx.ctx._ApiModel:count("gowaf_admin_operation_log", conditions)
    if not total then
        _ApiCommon:api_output(err, 500, 'query count failed')
        return
    end
    
    local list, err = ngx.ctx._ApiModel:getMany("gowaf_admin_operation_log", conditions, {
        "id", "admin_username", "operation_type", "operation_module", "operation_content",
        "operation_ip", "create_time", "operation_result", "error_msg", "request_id"
    }, count, offset, "id desc")
    if not list then
        _ApiCommon:api_output(err, 500, 'query list failed')
        return
    end
    
    for _, item in ipairs(list) do
        if item.operation_content then
            item.operation_content = json.decode(item.operation_content)
        end
    end
    
    _ApiCommon:api_output({ total = total, list = list }, 200, 'success')
end

function _operationLog:detail()
    local ok, err = _ApiCommon:validate({
        id = { required = true, label = "ID", type = "number", min = 1 }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    
    local id = tonumber(ngx.ctx._Request.id)
    local res, err = ngx.ctx._ApiModel:getOne("gowaf_admin_operation_log", { id = id }, {
        "id", "admin_username", "operation_type", "operation_module", "operation_content",
        "operation_ip", "create_time", "operation_result", "error_msg", "request_id"
    })
    if not res then
        _ApiCommon:api_output('', 400, 'record not exists')
        return
    end
    
    if res.operation_content then
        res.operation_content = json.decode(res.operation_content)
    end
    
    _ApiCommon:api_output(res, 200, 'success')
end

return _operationLog
