local _share_auth = {}
local json = require("cjson")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _share_model = require(ngx.ctx._gowafname .. ".core.share.share_model")
local SHARE_DICT_NAME = ngx.ctx._Config.config_share_dict.limit
local CACHE_KEYS = {
    LOGIN_FAIL = _Lib:make_share_dict_key("login_fail:"),
    ACCESS_TOKEN = _Lib:make_share_dict_key("access_token:"),
}

-- 设置登录失败次数
function _share_auth:set_login_fail(loginFailKey, failCount, ttl)
    _share_model:set(SHARE_DICT_NAME, CACHE_KEYS.LOGIN_FAIL .. loginFailKey, failCount, ttl)
end

-- 获取登录失败次数
function _share_auth:get_login_fail(loginFailKey)
    return _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.LOGIN_FAIL .. loginFailKey)
end

-- 删除登录失败记录
function _share_auth:delete_login_fail(loginFailKey)
    _share_model:delete(SHARE_DICT_NAME, CACHE_KEYS.LOGIN_FAIL .. loginFailKey) 
end

-- 设置访问令牌
function _share_auth:set_access_token(accessToken, tokenData, ttl)
    _share_model:set(SHARE_DICT_NAME, CACHE_KEYS.ACCESS_TOKEN .. accessToken, tokenData, ttl)
end

-- 获取访问令牌
function _share_auth:get_access_token(accessToken)
    return _share_model:get(SHARE_DICT_NAME, CACHE_KEYS.ACCESS_TOKEN .. accessToken)
end

-- 删除访问令牌
function _share_auth:delete_access_token(accessToken)
    _share_model:delete(SHARE_DICT_NAME, CACHE_KEYS.ACCESS_TOKEN .. accessToken)
end

return _share_auth