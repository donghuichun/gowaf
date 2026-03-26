local _share_sync_task = {}
local json = require("cjson")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _Func = require(ngx.ctx._gowafname .. ".core.func")

--[[
    同步任务队列
]]

-- 插入任务
local function add_task(shared_name, title, action, ...)
    local insert_data = {
        shared_name = shared_name,
        title = title,
        action = action,
        data = json.encode({...}),
    }
    local insert_id, err = ngx.ctx._ApiModel:insert("gowaf_server_sync_tasks", insert_data)
    if not insert_id then
        ngx.log(ngx.ERR, "Failed to insert sync task: ", err)
        return false
    end
    return true
end

function _share_sync_task:clear_server_cache()
    add_task("share_settings", "清理服务器节点信息缓存", "clear_server_cache", {})
end

function _share_sync_task:set_black_cache(new_record)
    add_task("share_settings", "ip黑名单创建", "set_black_cache", new_record)
end

function _share_sync_task:update_black_ip_cache(updated_record)
    add_task("share_settings", "ip黑名单更新", "update_black_ip_cache", updated_record)
end

function _share_sync_task:delete_black_cache(record_to_delete)
    add_task("share_settings", "ip黑名单删除", "delete_black_cache", record_to_delete)
end

function _share_sync_task:set_white_cache(new_record)
    add_task("share_settings", "ip白名单创建", "set_white_cache", new_record)
end

function _share_sync_task:update_white_ip_cache(updated_record)
    add_task("share_settings", "ip白名单更新", "update_white_ip_cache", updated_record)
end

function _share_sync_task:delete_white_cache(record_to_delete)
    add_task("share_settings", "ip白名单删除", "delete_white_cache", record_to_delete)
end

function _share_sync_task:refresh_all()
    add_task("share_settings", "重载所有配置缓存", "refresh_all", {})
end

function _share_sync_task:set_last_update()
    add_task("share_settings", "设置最后更新时间", "set_last_update", {})
end

function _share_sync_task:clear_config_cache()
    add_task("share_settings", "清理配置缓存", "clear_config_cache", {})
end

function _share_sync_task:clear_limit_cache()
    add_task("share_limit", "清理用户限流缓存", "clear_limit_cache", {})
end

function _share_sync_task:save_settings()
    add_task("share_settings", "保存配置", "save_settings", {})
end

function _share_sync_task:add_api_route_to_cache(new_record, is_update_count)
    add_task("share_settings", "添加API路由到缓存", "add_api_route_to_cache", new_record, is_update_count)
end

function _share_sync_task:update_api_route_cache(updated_record)
    add_task("share_settings", "更新API路由缓存", "update_api_route_cache", updated_record)
end

function _share_sync_task:remove_api_route_from_cache(record_to_delete, is_update_count)
    add_task("share_settings", "删除API路由从缓存", "remove_api_route_from_cache", record_to_delete, is_update_count)
end

return _share_sync_task