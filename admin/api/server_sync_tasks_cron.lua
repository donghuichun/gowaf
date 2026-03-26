local _server_sync_tasks_cron = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _Func = require(ngx.ctx._gowafname .. ".core.func")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Servers = require(ngx.ctx._gowafname .. ".admin.api.servers")

--[[
    服务同步任务 cron 任务
]]

local function call(shared_name, method, arg)
    local obj = require(ngx.ctx._gowafname .. ".core.share." .. shared_name)
    local ok, obj = pcall(require, ngx.ctx._gowafname .. ".core.share." .. shared_name)
    if not ok or not obj then
        ngx.log(ngx.ERR, "require module error: " .. shared_name .. "." .. method)
        return nil, "method not found"
    end

    -- 安全判断
    if not method or type(obj[method]) ~= "function" then
        ngx.log(ngx.ERR, "服务同步任务 cron 任务执行失败: 方法不存在：" .. shared_name .. "." .. method)
        return nil, "method not found"
    end

    obj[method](obj, unpack(arg or {}))

    return true
end

-- 执行任务
local function run_task(task, server_record_id)
    local shared_name = task.shared_name
    local action = task.action
    local data = task.data
    if not data or data == "" then
        data = "{}"
    end
    local params = json.decode(data)

    local insert_id, err = ngx.ctx._ApiModel:insert("gowaf_server_sync_tasks_execution", {
        task_id = task.id,
        server_id = server_record_id,
        status = 3,
    })
    if not insert_id then
        ngx.log(ngx.ERR, "入执行记录表数据失败: " .. (err or 'unknown error'))
    end

    local ok, err = call(shared_name, action, params)

    local update_fields = {}
    local update_conditions = { id = insert_id }
    if not ok then
        update_fields.status = 2
    else
        update_fields.status = 1
    end

    -- 修改状态为成功
    local affected, err = ngx.ctx._ApiModel:update("gowaf_server_sync_tasks_execution", update_fields, update_conditions)
    
    return true
end

-- 执行服务同步任务 cron 任务
function _server_sync_tasks_cron:run()
    local server_record_id = _Lib:get_server_id()
    if not server_record_id then
        _ApiCommon:api_output(nil, 500, "未找到服务器记录")
    end
    -- 从数据库获取该服务器未同步的任务
    local sql = 'SELECT t.* FROM gowaf_server_sync_tasks t LEFT JOIN gowaf_server_sync_tasks_execution e ON t.id = e.task_id AND e.server_id = ' .. server_record_id .. ' WHERE e.id IS NULL ORDER BY t.id ASC LIMIT 20'
    local tasks = ngx.ctx._ApiModel:query(sql)
    if not tasks or #tasks == 0 then
        _ApiCommon:api_output(nil, 200, "没有未同步的服务同步任务")
        return
    end

    -- 遍历任务，执行每个任务
    for _, task in ipairs(tasks) do
        run_task(task, server_record_id)
    end

    _ApiCommon:api_output(nil, 200, "服务同步任务 cron 任务执行成功")
end

return _server_sync_tasks_cron