local _operationLog = {}
local json = require("cjson")

function _operationLog:add(data)
    local Model = require(ngx.ctx._gowafname .. ".admin.api.lib.model")
    local db = Model:new(ngx.ctx._Config.config_gowaf_mysql)
    
    local adminInfo = ngx.ctx._AdminInfo or {}
    
    local log_data = {
        admin_username = data.admin_username or adminInfo.username or '',
        operation_type = data.operation_type or '',
        operation_module = data.operation_module or '',
        operation_content = data.operation_content and json.encode(data.operation_content) or '{}',
        operation_ip = data.operation_ip or ngx.var.remote_addr or '',
        operation_result = data.operation_result or 1,
        error_msg = data.error_msg or '',
        request_id = data.request_id or ngx.var.request_id or ''
    }
    
    local insert_id, err = db:insert("gowaf_admin_operation_log", log_data)
    return insert_id, err
end

function _operationLog:query(params)
    local offset = params.offset or 0
    local count = params.count or 20
    local conditions = {}
    
    if params.admin_username then
        conditions.admin_username = params.admin_username
    end
    if params.operation_type then
        conditions.operation_type = params.operation_type
    end
    if params.operation_module then
        conditions.operation_module = params.operation_module
    end
    if params.operation_result then
        conditions.operation_result = params.operation_result
    end
    
    local Model = require(ngx.ctx._gowafname .. ".admin.api.lib.model")
    local db = Model:new(ngx.ctx._Config.config_gowaf_mysql)
    
    local total, err = db:count("gowaf_admin_operation_log", conditions)
    if not total then
        return nil, err
    end
    
    local list, err = db:getMany("gowaf_admin_operation_log", conditions, {
        "id", "admin_username", "operation_type", "operation_module", "operation_content",
        "operation_ip", "create_time", "operation_result", "error_msg", "request_id"
    }, count, offset, "id desc")
    if not list then
        return nil, err
    end
    
    for _, item in ipairs(list) do
        if item.operation_content then
            item.operation_content = json.decode(item.operation_content)
        end
    end
    
    return { total = total, list = list }, nil
end

return _operationLog
