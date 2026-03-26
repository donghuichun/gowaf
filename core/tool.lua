-- 常用调试方法 --
local _Tool = {}

local json = require("cjson")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")

function _Tool:process()
    _Tool:callAdminApi()    -- 调用管理后台API接口
    _Tool:outIp()           -- 输出当前请求IP
    _Tool:outEnvName()      -- 输出服务环境名称
    _Tool:flushDuanlian()   -- 清除短链缓存
end

function _Tool:callAdminApi()
    local REQ_URI = ngx.var.uri
    local ADMIN_API_PREFIX = '/_gowaf_admin/admin-api/'
    if REQ_URI:sub(1, #ADMIN_API_PREFIX) == ADMIN_API_PREFIX then
        local _admin_main = require(ngx.ctx._gowafname .. ".admin.api.main")
        _admin_main:process()
        _Lib:waf_output('admin request ok')
    end
end

-- 输出ip
function _Tool:outIp()
    local args = ngx.req.get_uri_args()
    if args._gowaf_get_ip == '1' then
        _Lib:waf_output(ngx.ctx._gowaf_ip)
    end
end

-- 输出服务环境
function _Tool:outEnvName()
    local args = ngx.req.get_uri_args()
    if args._gowaf_get_envname == '1' then
        _Lib:waf_output(ngx.ctx._gowafname)

    end
end

-- 短链清除缓存
function _Tool:flushDuanlian()
    local args = ngx.req.get_uri_args()
    if args._gowaf_duanlian_flush == '1' then
        local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")
        local UID = 'duanlian:' .. args.uuid
        UID = _Lib:make_share_dict_key(UID)
        _share_limit:delete(UID)
        _Lib:waf_output('ok')
    end
end

-- 查询urllimit配置里当前状态
function _Tool:findUrlLimit()
    local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")
    local URLLIMIT_RULE = _Lib:get_rule('urllimit_rule')
    local UID, count_now, rets = '', 0, {}
    -- 循环urllimit配置
    for url, rule in pairs(URLLIMIT_RULE) do
        if type(rule) == 'table' then
            local ret = rule
            ret.url = url
            UID = 'ul:' .. url
            UID = _Lib:make_share_dict_key(UID)
            count_now = _share_limit:get(UID)
            ret.count_now = count_now or 0 -- 如果没值则为0
            -- 将ret加入到rets数组里
            table.insert(rets, ret)
        end
    end

    -- 增加全局qps
    UID = 'all_api_qps'
    UID = _Lib:make_share_dict_key(UID)
    count_now = _share_limit:get(UID)
    local ret_all = {
        open = true,
        check_time = 1,
        check_num = 1000,
        block_time = 0,
        url = '/all_api_qps',
        count_now = count_now or 0
    }
    table.insert(rets, ret_all)

    -- 按照url字段正序排序
    table.sort(rets, function(a, b)
        return a.url < b.url
    end)

    return rets
end

return _Tool
