local _cache = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _OperationLog = require(ngx.ctx._gowafname .. ".admin.api.lib.operation_log")

-- 定义共享字典名称列表
local SHARED_DICT_NAMES = {
    ngx.ctx._Config.config_share_dict.settings,
    ngx.ctx._Config.config_share_dict.limit
}

-- 获取所有缓存类型
function _cache:getTypes()
    _ApiCommon:api_output(SHARED_DICT_NAMES, 200, "获取缓存类型成功")
end

--- 获取所有共享字典的统计信息
-- @return table 包含各字典统计信息的数组
function _cache:getStats()
    local stats = {}
    
    for _, dict_name in ipairs(SHARED_DICT_NAMES) do
        local dict = ngx.shared[dict_name]
        if dict then
            local dict_stats = {
                name = dict_name,
                key_count = 0,
                capacity = 0,
                used_slots = 0
            }
            
            -- 获取键的数量
            local keys = dict:get_keys(0)
            dict_stats.key_count = #keys
            
            -- 如果支持 get_stats 方法，获取更详细的统计信息
            if dict.get_stats then
                local detailed_stats = dict:get_stats()
                if detailed_stats then
                    dict_stats.capacity = detailed_stats.capacity or 0
                    dict_stats.used_slots = detailed_stats.used_slots or 0
                end
            end
            
            table.insert(stats, dict_stats)
        end
    end
    
    _ApiCommon:api_output(stats, 200, "获取缓存统计信息成功")
end

--- 获取所有缓存键列表（最多1000条）
-- @return table 缓存键列表
function _cache:getList()
    local dict_name = ngx.ctx._Request.dict
    local cache_list = {}
    
    local dicts_to_check = {}
    if dict_name then
        table.insert(dicts_to_check, dict_name)
    else
        dicts_to_check = SHARED_DICT_NAMES
    end
    
    for _, name in ipairs(dicts_to_check) do
        local dict = ngx.shared[name]
        if dict then
            local keys = dict:get_keys(1000)
            for _, key in ipairs(keys) do
                table.insert(cache_list, {
                    dict = name,
                    key = key
                })
                if #cache_list >= 1000 then
                    break
                end
            end
        end
        if #cache_list >= 1000 then
            break
        end
    end
    
    _ApiCommon:api_output(cache_list, 200, "获取缓存列表成功")
end

--- 查询指定缓存的详细信息
-- @param dict 共享字典名称
-- @param key 缓存键
-- @return table 缓存详细信息
function _cache:getDetail()
    local dict_name = ngx.ctx._Request.dict
    local key = ngx.ctx._Request.key
    
    if not dict_name or not key then
        _ApiCommon:api_output(nil, 400, "参数错误：缺少dict或key")
        return
    end
    
    local dict = ngx.shared[dict_name]
    if not dict then
        _ApiCommon:api_output(nil, 400, "共享字典不存在：" .. dict_name)
        return
    end
    
    -- 获取缓存值
    local value, flags = dict:get(key)
    if value == nil then
        _ApiCommon:api_output(nil, 404, "缓存键不存在")
        return
    end
    
    -- 获取过期剩余时间
    local ttl = dict:ttl(key) or 0
    
    -- 分析值的类型
    local value_type = type(value)
    local is_json = false
    local parsed_json = nil
    
    -- 尝试解析JSON
    if value_type == "string" then
        local ok, result = pcall(json.decode, value)
        if ok then
            is_json = true
            parsed_json = result
        end
    end
    
    local detail = {
        dict = dict_name,
        key = key,
        value = value,
        value_type = value_type,
        is_json = is_json,
        parsed_json = parsed_json,
        ttl = ttl,
        flags = flags
    }
    
    _ApiCommon:api_output(detail, 200, "获取缓存详情成功")
end

--- 删除指定缓存
-- @param dict 共享字典名称
-- @param key 缓存键
-- @return table 操作结果
function _cache:delete()
    -- 检查写权限
    if not _ApiCommon:check_write_permission() then
        return
    end

    local dict_name = ngx.ctx._Request.dict
    local key = ngx.ctx._Request.key

    if not dict_name or not key then
        _ApiCommon:api_output(nil, 400, "参数错误：缺少dict或key")
        return
    end
    
    local dict = ngx.shared[dict_name]
    if not dict then
        _ApiCommon:api_output(nil, 400, "共享字典不存在：" .. dict_name)
        return
    end
    
    -- 删除缓存
    local success = dict:delete(key)
    
    -- 记录操作日志
    _OperationLog:add({
        operation_type = "删除缓存",
        operation_module = "缓存工具",
        operation_content = { dict = dict_name, key = key },
        operation_result = success and 1 or 0
    })
    
    if success then
        _ApiCommon:api_output({}, 200, "缓存删除成功")
    else
        _ApiCommon:api_output(nil, 500, "缓存删除失败")
    end
end

return _cache
