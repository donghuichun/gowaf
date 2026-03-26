-- 全局通用计划任务执行
local _general_cron = {}
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local Model = require(ngx.ctx._gowafname .. ".admin.api.lib.model")
local _Stat = require(ngx.ctx._gowafname .. ".core.stat")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")

--[[
服务器ping任务，每分钟执行一次，记录服务器触达在线时间
]]
function _general_cron:server_ping()
    local server_uuid = _Lib:get_server_uuid()

    -- 获取服务器信息
    local server_name = ngx.var.hostname or ""
    local server_ip = _Lib:get_server_ip() or ""
    local update_time = ngx.time()
    
    -- 检查服务器是否存在
    local existing_server, err = ngx.ctx._ApiModel:getOne("gowaf_servers", { server_uuid = server_uuid })
    
    if err then
        ngx.log(ngx.ERR, "general_cron 查询服务器失败: " .. err)
        _ApiCommon:api_output('', 500, "查询服务器失败")
    end
    
    if existing_server then
        -- 服务器存在，检查是否需要更新
        local need_update = false
        local update_data = { update_time = update_time }
        
        if existing_server.name ~= server_name then
            update_data.name = server_name
        end
        
        if existing_server.ip ~= server_ip then
            update_data.ip = server_ip
        end
        
        local affected, err = ngx.ctx._ApiModel:update("gowaf_servers", update_data, { server_uuid = server_uuid })
        if err then
            ngx.log(ngx.ERR, "更新服务器失败: " .. err)
        end
    else
        -- 服务器不存在，创建新记录
        -- 检查是否是第一条记录
        local count, err = ngx.ctx._ApiModel:count("gowaf_servers")
        if err then
            ngx.log(ngx.ERR, "统计服务器失败: " .. err)
            _ApiCommon:api_output('', 500, "统计服务器失败")
        end
        
        local server_type = count == 0 and "master" or "slave"
        
        local insert_data = {
            name = server_name,
            server_uuid = server_uuid,
            ip = server_ip,
            update_time = update_time,
            type = server_type
        }
        
        local insert_id, affected, err = ngx.ctx._ApiModel:insert("gowaf_servers", insert_data)
        if err then
            ngx.log(ngx.ERR, "创建服务器记录失败: " .. err)
        end
    end
    _ApiCommon:api_output('', 200, "服务器记录更新完成")
end

--[[
检查并更新过期的IP黑白名单记录
将过期时间已到且state=1的记录更新为state=2
]]
function _general_cron:ip_check_expire()
    -- 检查是否为主节点
    if not _Lib:is_master_server() then
        _ApiCommon:api_output('', 200, "检查过期IP记录-非主节点")
    end

    local now = os.date("%Y-%m-%d %H:%M:%S")
    
    -- 批量更新黑名单过期记录
    local blacklist_conditions = {
        state = 1,
        expire_time = {op = "RAW", value = "IS NOT NULL AND expire_time < '" .. now .. "'"}
    }
    local blacklist_affected, err = ngx.ctx._ApiModel:update("gowaf_blacklist", { state = 2 }, blacklist_conditions)
    
    -- 批量更新白名单过期记录
    local whitelist_conditions = {
        state = 1,
        expire_time = {op = "RAW", value = "IS NOT NULL AND expire_time < '" .. now .. "'"}
    }
    local whitelist_affected, err = ngx.ctx._ApiModel:update("gowaf_whitelist", { state = 2 }, whitelist_conditions)
    
    _ApiCommon:api_output({
        blacklist_updated = blacklist_affected or 0,
        whitelist_updated = whitelist_affected or 0,
        total_updated = (blacklist_affected or 0) + (whitelist_affected or 0)
    }, 200, "检查过期IP记录完成")
end

return _general_cron
