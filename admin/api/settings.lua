local _settings = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _OperationLog = require(ngx.ctx._gowafname .. ".admin.api.lib.operation_log")
local _share_sync_task = require(ngx.ctx._gowafname .. ".core.share.share_sync_task")

function _settings:query()
    local ok, err = _ApiCommon:validate({
        offset = { type = "number", min = 0 },
        count = { type = "number", min = 1, max = 100 },
        type = { type = "string", max_len = 64 }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local offset = ngx.ctx._Request.offset or 0
    local count = ngx.ctx._Request.count or 20
    local conditions = {}
    if ngx.ctx._Request.type then
        conditions.type = ngx.ctx._Request.type
    end
    local total, err = ngx.ctx._ApiModel:count("gowaf_settings", conditions)
    if not total then
        _ApiCommon:api_output(err, 500, 'query count failed')
        return
    end
    local list, err = ngx.ctx._ApiModel:getMany("gowaf_settings", conditions, {
        "id", "type", "content", "update_time", "update_user_name"
    }, count, offset, "id desc")
    if not list then
        _ApiCommon:api_output(err, 500, 'query list failed')
        return
    end
    for _, item in ipairs(list) do
        if item.content then
            item.content = json.decode(item.content)
        end
    end
    _ApiCommon:api_output({ total = total, list = list }, 200, 'success')
end

function _settings:create()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        type = { required = true, label = "设置类型", type = "string", min_len = 1, max_len = 64 },
        content = { required = true, label = "设置内容" }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local setting_type = ngx.ctx._Request.type
    local exist = ngx.ctx._ApiModel:getOne("gowaf_settings", { type = setting_type }, {"id"})
    local content = ngx.ctx._Request.content
    if type(content) == "table" then
        content = json.encode(content)
    end
    local data = {
        type = setting_type,
        content = content,
        update_user_id = tonumber(ngx.ctx._AdminInfo.id) or 0,
        update_user_name = ngx.ctx._AdminInfo.username or ''
    }
    local affected, err
    if exist then
        data.id = exist.id
        affected, err = ngx.ctx._ApiModel:update("gowaf_settings", data, { id = exist.id })
        if not affected then
            _OperationLog:add({
                operation_type = "更新设置",
                operation_module = "系统设置",
                operation_content = {
                    id = exist.id,
                    type = setting_type,
                    content = content
                },
                operation_result = 2,
                error_msg = '更新设置失败: ' .. (err or 'unknown error')
            })
            _ApiCommon:api_output(err, 500, 'update failed')
            return
        end
        _OperationLog:add({
            operation_type = "更新设置",
            operation_module = "系统设置",
            operation_content = {
                id = exist.id,
                type = setting_type,
                content = content
            },
            operation_result = 1
        })
        
        -- 实时更新缓存：查询完整记录后更新缓存
        _share_sync_task:save_settings()
        
        _ApiCommon:api_output('', 200, 'success')
    else
        local insert_id, err = ngx.ctx._ApiModel:insert("gowaf_settings", data)
        if not insert_id then
            _OperationLog:add({
                operation_type = "创建设置",
                operation_module = "系统设置",
                operation_content = {
                    type = setting_type,
                    content = content
                },
                operation_result = 2,
                error_msg = '创建设置失败: ' .. (err or 'unknown error')
            })
            _ApiCommon:api_output(err, 500, 'create failed')
            return
        end
        _OperationLog:add({
            operation_type = "创建设置",
            operation_module = "系统设置",
            operation_content = {
                id = insert_id,
                type = setting_type,
                content = content
            },
            operation_result = 1
        })
        
        -- 实时更新缓存：查询完整记录后更新缓存
        _share_sync_task:save_settings()
        
        _ApiCommon:api_output({ id = insert_id }, 200, 'success')
    end
end

function _settings:update()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        id = { required = true, label = "ID", type = "number", min = 1 },
        content = { label = "设置内容" }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local id = tonumber(ngx.ctx._Request.id)
    local exist = ngx.ctx._ApiModel:getOne("gowaf_settings", { id = id }, {"id"})
    if not exist then
        _ApiCommon:api_output('', 400, 'record not exists')
        return
    end
    local data = {
        update_user_id = tonumber(ngx.ctx._AdminInfo.id) or 0,
        update_user_name = ngx.ctx._AdminInfo.username or ''
    }
    if ngx.ctx._Request.content ~= nil then
        local content = ngx.ctx._Request.content
        if type(content) == "table" then
            content = json.encode(content)
        end
        data.content = content
    end
    local affected, err = ngx.ctx._ApiModel:update("gowaf_settings", data, { id = id })
    if not affected then
        _OperationLog:add({
            operation_type = "更新设置",
            operation_module = "系统设置",
            operation_content = {
                id = id,
                update_data = data
            },
            operation_result = 2,
            error_msg = '更新设置失败: ' .. (err or 'unknown error')
        })
        _ApiCommon:api_output(err, 500, 'update failed')
        return
    end
    _OperationLog:add({
        operation_type = "更新设置",
        operation_module = "系统设置",
        operation_content = {
            id = id,
            update_data = data
        },
        operation_result = 1
    })
    
    -- 实时更新缓存：查询完整记录后更新缓存
    _share_sync_task:save_settings()
    
    _ApiCommon:api_output('', 200, 'success')
end

function _settings:delete()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        id = { required = true, label = "ID", type = "number", min = 1 }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local id = tonumber(ngx.ctx._Request.id)
    local exist = ngx.ctx._ApiModel:getOne("gowaf_settings", { id = id }, {"id"})
    if not exist then
        _ApiCommon:api_output('', 400, 'record not exists')
        return
    end
    local affected, err = ngx.ctx._ApiModel:delete("gowaf_settings", { id = id })
    if not affected then
        _OperationLog:add({
            operation_type = "删除设置",
            operation_module = "系统设置",
            operation_content = {
                id = id
            },
            operation_result = 2,
            error_msg = '删除设置失败: ' .. (err or 'unknown error')
        })
        _ApiCommon:api_output(err, 500, 'delete failed')
        return
    end
    _OperationLog:add({
        operation_type = "删除设置",
        operation_module = "系统设置",
        operation_content = {
            id = id
        },
        operation_result = 1
    })
    _ApiCommon:api_output('', 200, 'success')
end

function _settings:detail()
    local ok, err = _ApiCommon:validate({
        id = { required = true, label = "ID", type = "number", min = 1 }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local id = tonumber(ngx.ctx._Request.id)
    local res, err = ngx.ctx._ApiModel:getOne("gowaf_settings", { id = id }, {
        "id", "type", "content", "update_time", "update_user_name"
    })
    if not res then
        _ApiCommon:api_output('', 400, 'record not exists')
        return
    end
    if res.content then
        res.content = json.decode(res.content)
    end
    _ApiCommon:api_output(res, 200, 'success')
end

function _settings:getByType()
    local ok, err = _ApiCommon:validate({
        type = { required = true, label = "设置类型", type = "string", min_len = 1, max_len = 64 }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local setting_type = ngx.ctx._Request.type
    local res, err = ngx.ctx._ApiModel:getOne("gowaf_settings", { type = setting_type }, {
        "id", "type", "content", "update_time", "update_user_name"
    })
    if not res then
        _ApiCommon:api_output('', 404, 'setting not found')
        return
    end
    if res.content then
        res.content = json.decode(res.content)
    end
    _ApiCommon:api_output(res, 200, 'success')
end

return _settings
