local _whitelist = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _OperationLog = require(ngx.ctx._gowafname .. ".admin.api.lib.operation_log")
local _share_sync_task = require(ngx.ctx._gowafname .. ".core.share.share_sync_task")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")

function _whitelist:query()
    local ok, err = _ApiCommon:validate({
        offset = { type = "number", min = 0 },
        count = { type = "number", min = 1, max = 100 },
        type = { type = "number", enum = {1, 2} },
        state = { type = "number", enum = {1, 2} },
        ip_address = { type = "string" },
        expire_status = { type = "string" },
        expire_time_start = { type = "string" },
        expire_time_end = { type = "string" }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local offset = ngx.ctx._Request.offset or 0
    local count = ngx.ctx._Request.count or 20
    local conditions = {}
    if ngx.ctx._Request.type then
        conditions.type = tonumber(ngx.ctx._Request.type)
    end
    if ngx.ctx._Request.state then
        conditions.state = tonumber(ngx.ctx._Request.state)
    end
    if ngx.ctx._Request.ip_address and ngx.ctx._Request.ip_address ~= "" then
        conditions.ip_address = {op = "LIKE", value = ngx.ctx._Request.ip_address}
    end
    if ngx.ctx._Request.expire_status and ngx.ctx._Request.expire_status ~= "" then
        local expire_status = ngx.ctx._Request.expire_status
        if expire_status == "permanent" then
            conditions.expire_time = {op = "IS NULL"}
        elseif expire_status == "expired" then
            conditions.expire_time = {op = "RAW", value = "IS NOT NULL AND expire_time < NOW()"}
        elseif expire_status == "not_expired" then
            conditions.expire_time = {op = "RAW", value = "IS NOT NULL AND expire_time >= NOW()"}
        end
    end
    if ngx.ctx._Request.expire_time_start and ngx.ctx._Request.expire_time_start ~= "" then
        if ngx.ctx._Request.expire_time_end and ngx.ctx._Request.expire_time_end ~= "" then
            conditions.expire_time = {
                op = "BETWEEN",
                value = {
                    ngx.ctx._Request.expire_time_start,
                    ngx.ctx._Request.expire_time_end
                }
            }
        else
            conditions.expire_time = {op = ">=", value = ngx.ctx._Request.expire_time_start}
        end
    elseif ngx.ctx._Request.expire_time_end and ngx.ctx._Request.expire_time_end ~= "" then
        conditions.expire_time = {op = "<=", value = ngx.ctx._Request.expire_time_end}
    end
    local total, err = ngx.ctx._ApiModel:count("gowaf_whitelist", conditions)
    if not total then
        _ApiCommon:api_output(err, 500, 'query count failed')
        return
    end
    local list, err = ngx.ctx._ApiModel:getMany("gowaf_whitelist", conditions, {
        "id", "type", "ip_address", "source", "state", "create_time", "create_user_name", "expire_time", "remark"
    }, count, offset, "id desc")
    if not list then
        _ApiCommon:api_output(err, 500, 'query list failed')
        return
    end

    -- 查询IP归属地（仅单个IP）
    for _, item in ipairs(list) do
        if item.type == 1 then
            local area_info = _Lib:get_ip_area(item.ip_address)
            if area_info then
                item.province = area_info.province or ''
                item.city = area_info.city or ''
                item.area = area_info.area or ''
            end
        end
    end

    _ApiCommon:api_output({ total = total, list = list }, 200, 'success')
end

function _whitelist:create()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        type = { required = true, label = "类型", type = "number", enum = {1, 2} },
        ip_address = { required = true, label = "IP地址", type = "string", min_len = 1, max_len = 64 },
        source = { type = "number", enum = {1, 2} },
        state = { type = "number", enum = {1, 2} },
        expire_time = { type = "string" },
        remark = { type = "string", max_len = 512 }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local type = tonumber(ngx.ctx._Request.type)
    local ip_address = ngx.ctx._Request.ip_address
    
    if type == 2 then
        local pattern = "^(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)$"
        local a, b, c = ip_address:match(pattern)
        if not a or not b or not c then
            _ApiCommon:api_output('', 400, 'IP网段格式不正确，只需输入前三段，如 192.168.1')
            return
        end
        
        local function check_ip_part(part)
            local num = tonumber(part)
            return num and num >= 0 and num <= 255
        end
        
        if not check_ip_part(a) or not check_ip_part(b) or not check_ip_part(c) then
            _ApiCommon:api_output('', 400, 'IP地址段数值必须在0-255之间')
            return
        end
    end
    local exist = ngx.ctx._ApiModel:getOne("gowaf_whitelist", {
        ip_address = ip_address,
        type = type
    }, {"id"})
    if exist then
        _ApiCommon:api_output('', 400, 'IP already exists in whitelist')
        return
    end
    local data = {
        type = type,
        ip_address = ip_address,
        source = tonumber(ngx.ctx._Request.source) or 1,
        state = tonumber(ngx.ctx._Request.state) or 1,
        remark = ngx.ctx._Request.remark or '',
        create_user_name = ngx.ctx._AdminInfo.username or '',
        create_user_id = tonumber(ngx.ctx._AdminInfo.id) or 0
    }
    if ngx.ctx._Request.expire_time and ngx.ctx._Request.expire_time ~= "" then
        data.expire_time = ngx.ctx._Request.expire_time
    else
        data.expire_time = ngx.null
    end
    local insert_id, err = ngx.ctx._ApiModel:insert("gowaf_whitelist", data)
    if not insert_id then
        _OperationLog:add({
            operation_type = "添加白名单",
            operation_module = "黑白名单管理",
            operation_content = {
                type = type,
                ip_address = ip_address,
                source = tonumber(ngx.ctx._Request.source) or 1,
                state = tonumber(ngx.ctx._Request.state) or 1,
                expire_time = ngx.ctx._Request.expire_time or '',
                remark = ngx.ctx._Request.remark or ''
            },
            operation_result = 2,
            error_msg = '添加白名单失败: ' .. (err or 'unknown error')
        })
        _ApiCommon:api_output(err, 500, 'create failed')
        return
    end
    _OperationLog:add({
        operation_type = "添加白名单",
        operation_module = "黑白名单管理",
        operation_content = {
            id = insert_id,
            type = type,
            ip_address = ip_address,
            source = tonumber(ngx.ctx._Request.source) or 1,
            state = tonumber(ngx.ctx._Request.state) or 1,
            expire_time = ngx.ctx._Request.expire_time or '',
            remark = ngx.ctx._Request.remark or ''
        },
        operation_result = 1
    })
    
    -- 实时更新缓存：查询完整记录后写入缓存
    local new_record = ngx.ctx._ApiModel:getOne("gowaf_whitelist", { id = insert_id }, 
        {"id", "type", "ip_address", "state", "expire_time"})
    if new_record then
        _share_sync_task:set_white_cache(new_record)
    end
    
    _ApiCommon:api_output({ id = insert_id }, 200, 'success')
end

function _whitelist:update()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        id = { required = true, label = "ID", type = "number", min = 1 },
        state = { type = "number", enum = {1, 2} },
        expire_time = { type = "string" },
        remark = { type = "string", max_len = 512 }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local id = tonumber(ngx.ctx._Request.id)
    local exist = ngx.ctx._ApiModel:getOne("gowaf_whitelist", { id = id }, {"id"})
    if not exist then
        _ApiCommon:api_output('', 400, 'record not exists')
        return
    end
    local data = {}
    if ngx.ctx._Request.state ~= nil then
        data.state = tonumber(ngx.ctx._Request.state)
    end
    if ngx.ctx._Request.expire_time ~= nil then
        if ngx.ctx._Request.expire_time == "" then
            data.expire_time = ngx.null
        else
            data.expire_time = ngx.ctx._Request.expire_time
        end
    end
    if ngx.ctx._Request.remark ~= nil then
        data.remark = ngx.ctx._Request.remark
    end
    if next(data) == nil then
        _ApiCommon:api_output('', 400, 'no data to update')
        return
    end
    local affected, err = ngx.ctx._ApiModel:update("gowaf_whitelist", data, { id = id })
    if not affected then
        _OperationLog:add({
            operation_type = "更新白名单",
            operation_module = "黑白名单管理",
            operation_content = {
                id = id,
                update_data = data
            },
            operation_result = 2,
            error_msg = '更新白名单失败: ' .. (err or 'unknown error')
        })
        _ApiCommon:api_output(err, 500, 'update failed')
        return
    end
    _OperationLog:add({
        operation_type = "更新白名单",
        operation_module = "黑白名单管理",
        operation_content = {
            id = id,
            update_data = data
        },
        operation_result = 1
    })
    
    -- 实时更新缓存
    local updated_record = ngx.ctx._ApiModel:getOne("gowaf_whitelist", { id = id }, 
        {"id", "type", "ip_address", "state", "expire_time"})
    if updated_record then
        _share_sync_task:update_white_ip_cache(updated_record)
    end
    
    _ApiCommon:api_output('', 200, 'success')
end

function _whitelist:delete()
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
    local exist = ngx.ctx._ApiModel:getOne("gowaf_whitelist", { id = id }, {"id", "type", "ip_address"})
    if not exist then
        _ApiCommon:api_output('', 400, 'record not exists')
        return
    end
    
    -- 先获取记录用于删除缓存
    local record_to_delete = {
        type = exist.type,
        ip_address = exist.ip_address
    }
    
    local affected, err = ngx.ctx._ApiModel:delete("gowaf_whitelist", { id = id })
    if not affected then
        _OperationLog:add({
            operation_type = "删除白名单",
            operation_module = "黑白名单管理",
            operation_content = {
                id = id
            },
            operation_result = 2,
            error_msg = '删除白名单失败: ' .. (err or 'unknown error')
        })
        _ApiCommon:api_output(err, 500, 'delete failed')
        return
    end
    _OperationLog:add({
        operation_type = "删除白名单",
        operation_module = "黑白名单管理",
        operation_content = {
            id = id
        },
        operation_result = 1
    })
    
    -- 实时更新缓存
    _share_sync_task:delete_white_cache(record_to_delete)
    
    _ApiCommon:api_output('', 200, 'success')
end

function _whitelist:detail()
    local ok, err = _ApiCommon:validate({
        id = { required = true, label = "ID", type = "number", min = 1 }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local id = tonumber(ngx.ctx._Request.id)
    local res, err = ngx.ctx._ApiModel:getOne("gowaf_whitelist", { id = id }, {
        "id", "type", "ip_address", "source", "state", "create_time", "create_user_name", "expire_time", "remark"
    })
    if not res then
        _ApiCommon:api_output('', 400, 'record not exists')
        return
    end
    _ApiCommon:api_output(res, 200, 'success')
end

return _whitelist
