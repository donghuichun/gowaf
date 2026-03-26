local _system = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _OperationLog = require(ngx.ctx._gowafname .. ".admin.api.lib.operation_log")
local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")
local _share_sync_task = require(ngx.ctx._gowafname .. ".core.share.share_sync_task")

--- 获取系统基本信息
-- @return table 系统基本信息
function _system:basicInfo()
    local last_update = _share_settings:get_last_update()
    last_update = tonumber(last_update)
    last_update = last_update or 0
    local last_update_str = last_update > 0 and os.date("%Y-%m-%d %H:%M:%S", last_update) or "从未更新"
    
    local info = {
        version = "1.0.0",
        nginx_version = ngx.config.nginx_version or "unknown",
        lua_version = "unknown",
        openresty_version = ngx.config.nginx_configure_arguments and string.match(ngx.config.nginx_configure_arguments, "openresty%-([%d%.]+)") or "unknown",
        server_time = os.date("%Y-%m-%d %H:%M:%S"),
        start_time = ngx.req.start_time() and os.date("%Y-%m-%d %H:%M:%S", math.floor(ngx.req.start_time())) or "unknown",
        uptime = '',
        cpu_cores = '',
        config_last_update = last_update_str
    }
    
    _ApiCommon:api_output(info, 200, "获取系统基本信息成功")
end



--- 重载配置
-- @return table 操作结果
function _system:reloadConfig()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end

    _share_sync_task:refresh_all()
    _share_sync_task:set_last_update()
    local last_update = _share_settings:get_last_update()
    local last_update_str = os.date("%Y-%m-%d %H:%M:%S", last_update)
    
    _OperationLog:add({
        operation_type = "重载配置",
        operation_module = "系统管理",
        operation_content = { action = "reload_config", last_update = last_update_str },
        operation_result = 1
    })
    
    _ApiCommon:api_output({ last_update = last_update_str }, 200, "配置重载成功")
end

--- 清理配置缓存（只删除gowafsettings）
-- @return table 操作结果
function _system:clearConfigCache()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end

    _share_sync_task:clear_config_cache()
    
    _OperationLog:add({
        operation_type = "清理配置缓存",
        operation_module = "系统管理",
        operation_content = { action = "clear_config_cache" },
        operation_result = 1
    })
    
    _ApiCommon:api_output({}, 200, "配置缓存清理成功")
end

--- 清理用户访问缓存（只删除gowaflimit）
-- @return table 操作结果
function _system:clearLimitCache()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end

    _share_sync_task:clear_limit_cache()
    
    _OperationLog:add({
        operation_type = "清理用户访问缓存",
        operation_module = "系统管理",
        operation_content = { action = "clear_limit_cache" },
        operation_result = 1
    })
    
    _ApiCommon:api_output({}, 200, "用户访问缓存清理成功")
end

return _system
