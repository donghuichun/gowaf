local _global_config = {}
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")

-- 白名单配置查询
-- 白名单类型1：单个IP白名单
-- 白名单类型2：IP网段白名单
local whiteReload = function()
    local conditions = {
        state = 1
    }
    local count = 1000
    local offset = 0
    local list, err = ngx.ctx._ApiModel:getMany("gowaf_whitelist", conditions, {"type", "ip_address", "state", "expire_time"}, count, offset, "id desc")
    if not list then
        return {}, {}
    end
    
    local type1 = {}
    local type2 = {}
    
    for _, item in ipairs(list) do
        if item.type == 1 then
            table.insert(type1, item)
        elseif item.type == 2 then
            table.insert(type2, item)
        end
    end
    
    return type1, type2
end

function _global_config:reload()
    -- 白名单配置加载
    local type1, type2 = whiteReload()
    return type1, type2
end

function _global_config:get()
    local type1, type2 = whiteReload()
    _ApiCommon:api_output({ type1 = type1, type2 = type2 }, 200, 'success')
end

return _global_config
