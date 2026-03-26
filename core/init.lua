local _Init = {}

function _Init:init()
    -- 初始化gowafname
    if ngx.ctx._gowafname == nil then
        ngx.say("init gowafname is nil")
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    -- 初始化配置
    ngx.ctx._Config = require(ngx.ctx._gowafname .. '.env')

    -- 获取当前访问ip，获取当前访问租户信息t_id
    local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
    local headerbase = _Lib:get_header_base()
    ngx.ctx._gowaf_ip = headerbase.client_ip
    ngx.ctx._gowaf_t_id = headerbase.t_id
    ngx.ctx._gowaf_user_id = headerbase.user_id

    -- 设置share dict的key前缀
    ngx.ctx._gowaf_share_dict_key_prefix = ngx.ctx._Config.config_share_dict.prefix .. ":"
    
end

return _Init
