local _main = {}
local json = require("cjson")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _account = require(ngx.ctx._gowafname .. ".admin.api.account")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _share_auth = require(ngx.ctx._gowafname .. ".core.share.share_auth")

local _initDB = function()
    local Model = require(ngx.ctx._gowafname .. ".admin.api.lib.model")
    ngx.ctx._ApiModel = Model:new(ngx.ctx._Config.config_gowaf_mysql)
end

local _verifyToken = function()
    -- 如果传值appid和appsecret，校验正确，则直接校验通过
    if ngx.ctx._Request.appid and ngx.ctx._Request.appid == ngx.ctx._Config.appid and ngx.ctx._Request.appsecret and ngx.ctx._Request.appsecret == ngx.ctx._Config.appsecret then
        local adminInfo = {
            id = 1,
            username = 'admin',
            real_name = '后台任务执行',
            phone = '',
            email = '',
            role = 'admin',
            state = 1
        }
        return true, adminInfo
    end
    
    local headers = ngx.req.get_headers()
    local accessToken = headers["access_token"]
    
    if not accessToken or accessToken == "" then
        return false, "未登录或登录已过期"
    end
    
    local tokenData = _share_auth:get_access_token(accessToken)
    
    if not tokenData then
        return false, "登录已过期，请重新登录"
    end
    
    local adminInfo = json.decode(tokenData)
    
    _share_auth:set_access_token(accessToken, tokenData, 7200)
    
    return true, adminInfo
end

local _initRequest = function()
    ngx.ctx._Request = _Lib:get_request_data()
    
    if ngx.ctx._Request then
        for key, value in pairs(ngx.ctx._Request) do
            if type(value) == "boolean" then
                ngx.ctx._Request[key] = ""
            end
        end
    end
    
    if ngx.ctx._Request.offset then
        ngx.ctx._Request.offset = tonumber(ngx.ctx._Request.offset) or 0
    end
    if ngx.ctx._Request.count then
        ngx.ctx._Request.count = tonumber(ngx.ctx._Request.count) or 20
    end

    local uri = ngx.var.uri
    local isLoginRequest = uri:match("/admin%-api/login/login") or uri:match("/admin%-api/login/logout")
    
    if not isLoginRequest then
        local ok, adminInfo = _verifyToken()
        if not ok then
            _ApiCommon:api_output(nil, 401, adminInfo)
            ngx.exit(401)
            return
        end
        ngx.ctx._AdminInfo = adminInfo
    else
        ngx.ctx._AdminInfo = nil
    end
    
    -- ngx.log(ngx.ERR, "ngx.ctx._Request: ", json.encode(ngx.ctx._Request))
end

local _matchRoute = function()
    local uri = ngx.var.uri
    local file, method = uri:match("/admin%-api/([%w%-_]+)/([%w%-_]+)")
    if not file or not method then
        _ApiCommon:api_output(nil, 400, 'no route')
        return
    end
    ngx.ctx._Route = {
        file = file,
        method = method,
    }
    return file, method
end

local _callFunc = function()
    local file, method = _matchRoute()
    local ok, module = pcall(require, ngx.ctx._gowafname .. ".admin.api." .. file)
    if not ok or not module then
        _ApiCommon:api_output(nil, 400, 'require module error')
        return
    end
    local func = module[method]
    if not func or type(func) ~= "function" then
        _ApiCommon:api_output(nil, 400, 'no method')
        return
    end
    func()
end

function _main:process()
    _initRequest()

    _initDB()

    _callFunc()
end

return _main
