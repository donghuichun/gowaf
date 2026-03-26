local _account = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _OperationLog = require(ngx.ctx._gowafname .. ".admin.api.lib.operation_log")
local _share_auth = require(ngx.ctx._gowafname .. ".core.share.share_auth")

function _account:query()
    local offset = ngx.ctx._Request.offset or 0
    local count = ngx.ctx._Request.count or 20
    local username = ngx.ctx._Request.username
    local state = ngx.ctx._Request.state

    local ok, err = _ApiCommon:validate({
        username = {
            type = "string",
            max_len = 30
        },
        state = {
            type = "number",
            min = 1,
            max = 2
        }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end

    -- 构建查询条件
    local conditions = {}
    if _ApiCommon:value_true_false(username) then
        conditions.username = {op="LIKE", value="%" .. username .. "%"}
    end
    if _ApiCommon:value_true_false(state) then
        conditions.state = tonumber(state)
    end

    local total, err = ngx.ctx._ApiModel:count("gowaf_admin_account", conditions)
    if not total then
        _ApiCommon:api_output(err, 500, 'query count failed')
        return
    end

    local list, err = ngx.ctx._ApiModel:getMany("gowaf_admin_account", conditions, {"id", "username", "real_name","phone","email","state","role","create_time"}, count,
        offset, "id desc")
    if not list then
        _ApiCommon:api_output(err, 500, 'query list failed')
        return
    end

    _ApiCommon:api_output({
        total = total,
        list = list
    }, 200, 'success')
end

function _account:create()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        username = {
            required = true,
            type = "string",
            min_len = 3,
            max_len = 30
        },
        password = {
            required = true,
            type = "string",
            min_len = 32,
            max_len = 32
        },
        real_name = {
            type = "string",
            max_len = 64
        },
        phone = {
            type = "string",
            max_len = 20
        },
        email = {
            type = "string",
            max_len = 64
        },
        role = {
            type = "number",
            min = 1,
            max = 3
        }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local username = ngx.ctx._Request.username
    local res = ngx.ctx._ApiModel:getOne("gowaf_admin_account", {
        username = username
    }, {"id"})
    if res then
        _ApiCommon:api_output('', 400, 'username already exists')
        return
    end
    local password = ngx.ctx._Request.password
    local salt = _ApiCommon:random_string(4)
    -- 前端传递的是MD5加密后的密码，这里需要再次MD5加密
    password = ngx.md5(password .. salt)
    local data = {
        username = username,
        password = password,
        salt = salt,
        real_name = ngx.ctx._Request.real_name or '',
        phone = ngx.ctx._Request.phone or '',
        email = ngx.ctx._Request.email or '',
        role = ngx.ctx._Request.role or 3
    }
    local insert_id, err = ngx.ctx._ApiModel:insert("gowaf_admin_account", data)
    if not insert_id then
        _OperationLog:add({
            operation_type = "创建账号",
            operation_module = "管理员账号管理",
            operation_content = {
                username = username,
                real_name = ngx.ctx._Request.real_name or '',
                phone = ngx.ctx._Request.phone or '',
                email = ngx.ctx._Request.email or '',
                role = ngx.ctx._Request.role or 3
            },
            operation_result = 2,
            error_msg = '创建账号失败: ' .. (err or 'unknown error')
        })
        _ApiCommon:api_output(err, 500, 'create account failed')
        return
    end
    _OperationLog:add({
        operation_type = "创建账号",
        operation_module = "管理员账号管理",
        operation_content = {
            username = username,
            real_name = ngx.ctx._Request.real_name or '',
            phone = ngx.ctx._Request.phone or '',
            email = ngx.ctx._Request.email or '',
            role = ngx.ctx._Request.role or 3,
            id = insert_id
        },
        operation_result = 1
    })
    _ApiCommon:api_output('', 200, 'success')
end

function _account:update()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        id = {
            required = true,
            label = "ID",
            type = "number",
            min = 1
        },
        password = {
            type = "string",
            min_len = 32,
            max_len = 32
        },
        real_name = {
            type = "string",
            max_len = 64
        },
        phone = {
            type = "string",
            max_len = 20
        },
        email = {
            type = "string",
            max_len = 64
        },
        role = {
            type = "number",
            min = 1,
            max = 3
        }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local id = ngx.ctx._Request.id
    local res = ngx.ctx._ApiModel:getOne("gowaf_admin_account", {
        id = id
    }, {"id"})
    if not res then
        _ApiCommon:api_output('', 400, 'account not exists')
        return
    end
    local data = {}
    local password = ngx.ctx._Request.password
    if password then
        local salt = _ApiCommon:random_string(4)
        -- 前端传递的是MD5加密后的密码，这里需要再次MD5加密
        data.password = ngx.md5(password .. salt)
        data.salt = salt
    end
    local real_name = ngx.ctx._Request.real_name
    if real_name ~= nil then
        data.real_name = real_name
    end
    local phone = ngx.ctx._Request.phone
    if phone ~= nil then
        data.phone = phone
    end
    local email = ngx.ctx._Request.email
    if email ~= nil then
        data.email = email
    end
    local role = ngx.ctx._Request.role
    if role ~= nil then
        data.role = role
    end
    if next(data) == nil then
        _ApiCommon:api_output('', 400, 'no data to update')
        return
    end
    local affected, err = ngx.ctx._ApiModel:update("gowaf_admin_account", data, {
        id = id
    })
    if not affected then
        _OperationLog:add({
            operation_type = "更新账号",
            operation_module = "管理员账号管理",
            operation_content = {
                id = id,
                update_data = data
            },
            operation_result = 2,
            error_msg = '更新账号失败: ' .. (err or 'unknown error')
        })
        _ApiCommon:api_output(err, 500, 'update failed')
        return
    end
    _OperationLog:add({
        operation_type = "更新账号",
        operation_module = "管理员账号管理",
        operation_content = {
            id = id,
            update_data = data
        },
        operation_result = 1
    })
    _ApiCommon:api_output('', 200, 'success')
end

function _account:delete()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        id = {
            required = true,
            label = "ID",
            type = "number",
            min = 1
        }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local id = ngx.ctx._Request.id
    local res = ngx.ctx._ApiModel:getOne("gowaf_admin_account", {
        id = id
    }, {"id"})
    if not res then
        _ApiCommon:api_output('', 400, 'account not exists')
        return
    end
    local affected, err = ngx.ctx._ApiModel:delete("gowaf_admin_account", {
        id = id
    })
    if not affected then
        _OperationLog:add({
            operation_type = "删除账号",
            operation_module = "管理员账号管理",
            operation_content = {
                id = id
            },
            operation_result = 2,
            error_msg = '删除账号失败: ' .. (err or 'unknown error')
        })
        _ApiCommon:api_output(err, 500, 'delete failed')
        return
    end
    _OperationLog:add({
        operation_type = "删除账号",
        operation_module = "管理员账号管理",
        operation_content = {
            id = id
        },
        operation_result = 1
    })
    _ApiCommon:api_output('', 200, 'success')
end

function _account:detail()
    local ok, err = _ApiCommon:validate({
        id = {
            required = true,
            label = "ID",
            type = "number",
            min = 1
        }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local id = ngx.ctx._Request.id
    local res, err = ngx.ctx._ApiModel:getOne("gowaf_admin_account", {
        id = id
    }, {"id", "username", "real_name", "phone", "email", "role", "create_time"})
    if not res then
        _ApiCommon:api_output('', 400, 'account not exists')
        return
    end
    _ApiCommon:api_output(res, 200, 'success')
end

function _account:lock()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end
    
    local ok, err = _ApiCommon:validate({
        id = {
            required = true,
            label = "ID",
            type = "number",
            min = 1
        },
        state = {
            required = true,
            label = "状态",
            type = "number",
            min = 1,
            max = 2
        }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    local id = ngx.ctx._Request.id
    local state = tonumber(ngx.ctx._Request.state)

    local res = ngx.ctx._ApiModel:getOne("gowaf_admin_account", {
        id = id
    }, {"id", "username", "state"})
    if not res then
        _ApiCommon:api_output('', 400, 'account not exists')
        return
    end

    local affected, err = ngx.ctx._ApiModel:update("gowaf_admin_account", {
        state = state
    }, {
        id = id
    })
    if not affected then
        _OperationLog:add({
            operation_type = state == 1 and "解锁账号" or "锁定账号",
            operation_module = "管理员账号管理",
            operation_content = {
                id = id,
                state = state,
                state_text = state == 1 and "正常" or "锁定"
            },
            operation_result = 2,
            error_msg = '更新账号状态失败: ' .. (err or 'unknown error')
        })
        _ApiCommon:api_output(err, 500, 'update failed')
        return
    end
    
    if state == 1 then
        _share_auth:delete_login_fail(res.username)
    end
    
    _OperationLog:add({
        operation_type = state == 1 and "解锁账号" or "锁定账号",
        operation_module = "管理员账号管理",
        operation_content = {
            id = id,
            state = state,
            state_text = state == 1 and "正常" or "锁定"
        },
        operation_result = 1
    })
    _ApiCommon:api_output('', 200, 'success')
end

return _account
