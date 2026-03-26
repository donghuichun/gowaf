local _servers = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _OperationLog = require(ngx.ctx._gowafname .. ".admin.api.lib.operation_log")
local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")
local _share_sync_task = require(ngx.ctx._gowafname .. ".core.share.share_sync_task")

--- 获取服务器列表
-- @return table 服务器列表
function _servers:list()
    local ok, err = _ApiCommon:validate({
        offset = {
            type = "number",
            min = 0
        },
        count = {
            type = "number",
            min = 1,
            max = 100
        },
        name = {
            type = "string"
        },
        ip = {
            type = "string"
        },
        type = {
            type = "string",
            enum = {"master", "slave"}
        },
        online_status = {
            type = "string",
            enum = {"online", "offline"}
        }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    
    local offset = ngx.ctx._Request.offset or 0
    local count = ngx.ctx._Request.count or 20
    
    local conditions = {}
    if ngx.ctx._Request.name and ngx.ctx._Request.name ~= "" then
        conditions.name = {op = "LIKE", value = ngx.ctx._Request.name}
    end
    if ngx.ctx._Request.ip and ngx.ctx._Request.ip ~= "" then
        conditions.ip = {op = "LIKE", value = ngx.ctx._Request.ip}
    end
    if ngx.ctx._Request.type and ngx.ctx._Request.type ~= "" then
        conditions.type = ngx.ctx._Request.type
    end
    if ngx.ctx._Request.online_status and ngx.ctx._Request.online_status ~= "" then
        local current_time = os.time()
        local offline_threshold = current_time - 65 -- 65秒以上认为离线
        if ngx.ctx._Request.online_status == "online" then
            conditions.update_time = {op = ">", value = offline_threshold}
        else
            conditions.update_time = {op = "<=", value = offline_threshold}
        end
    end
    
    local total, err = ngx.ctx._ApiModel:count("gowaf_servers", conditions)
    if not total then
        _ApiCommon:api_output(err, 500, 'query count failed')
        return
    end
    
    local list, err = ngx.ctx._ApiModel:getMany("gowaf_servers", conditions, {
        "id", "name", "server_uuid", "ip", "update_time", "type"
    }, count, offset, "id ASC")
    if not list then
        _ApiCommon:api_output(err, 500, 'query list failed')
        return
    end
    
    -- 添加在线状态
    local current_time = os.time()
    for i, server in ipairs(list) do
        local time_diff = current_time - server.update_time
        server.online_status = time_diff <= 65 and "online" or "offline"
        server.online_status_text = time_diff <= 65 and "在线" or "离线"
    end
    
    _ApiCommon:api_output({
        total = total,
        list = list
    }, 200, 'success')
end

--- 切换服务器主子节点类型
-- @param id 服务器ID
-- @param type 服务器类型 (master/slave)
-- @return table 操作结果
function _servers:switchType()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        id = {
            type = "number",
            required = true,
            min = 1
        },
        type = {
            type = "string",
            required = true,
            enum = {"master", "slave"}
        }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    
    local id = tonumber(ngx.ctx._Request.id)
    local new_type = ngx.ctx._Request.type
    
    -- 开始事务
    local transaction_ok = true
    local old_server, old_err = ngx.ctx._ApiModel:getOne("gowaf_servers", { id = id })
    if not old_server then
        _ApiCommon:api_output(nil, 500, '服务器不存在')
        return
    end
    
    -- 如果要切换为master，需要将其他master设为slave
    if new_type == "master" then
        local update_other_master, update_err = ngx.ctx._ApiModel:update("gowaf_servers", { type = "slave" }, { type = "master" })
        if not update_other_master then
            _ApiCommon:api_output(nil, 500, '更新其他主节点失败')
            return
        end
    end

    if new_type == "slave" and old_server.type == "master" then
        _ApiCommon:api_output(nil, 500, '主节点不能切换为子节点')
    end
    
    -- 更新当前服务器类型
    local update_current, update_err = ngx.ctx._ApiModel:update("gowaf_servers", { type = new_type }, { id = id })
    if not update_current then
        _ApiCommon:api_output(nil, 500, '更新服务器类型失败')
        return
    end

    -- 切换节点数据，需要更新各业务服务器缓存
    _share_sync_task:clear_server_cache()
    
    -- 记录操作日志
    _OperationLog:add({
        operation_type = "切换服务器类型",
        operation_module = "服务节点管理",
        operation_content = { 
            server_uuid = old_server.server_uuid,
            old_type = old_server.type,
            new_type = new_type,
            server_name = old_server.name
        },
        operation_result = 1
    })
    
    _ApiCommon:api_output({}, 200, '服务器类型切换成功')
end

-- 根据server_uuid查询服务器记录
function _servers:getByServerId(server_uuid)
    local server, err = ngx.ctx._ApiModel:getOne("gowaf_servers", { server_uuid = server_uuid })
    if not server then
        return nil
    end
    
    return server
end

-- 根据server_uuid查询服务器记录
function _servers:getByServerIdByCache(server_uuid)
    local server = _share_settings:get_server_cache()
    if server then
        return server
    end
    
    local server, err = ngx.ctx._ApiModel:getOne("gowaf_servers", { server_uuid = server_uuid })
    if not server then
        return nil
    end
    _share_settings:set_server_cache(server) --属于本地缓存，无需走异步任务
    return server
end

return _servers