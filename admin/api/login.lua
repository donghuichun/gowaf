local _login = {}
local json = require("cjson")
local _ApiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local _OperationLog = require(ngx.ctx._gowafname .. ".admin.api.lib.operation_log")
local _share_auth = require(ngx.ctx._gowafname .. ".core.share.share_auth")

local _generateToken = function()
    local seed = tostring(ngx.now()) .. tostring(math.random(100000, 999999))
    return ngx.md5(seed .. ngx.var.remote_addr)
end

local _verifyPassword = function(inputPassword, dbPassword, salt)
    -- 前端传递的是MD5加密后的密码，需要与数据库中存储的MD5(明文密码 + salt)比较
    -- 但由于前端已经MD5加密，所以需要将前端的MD5再与salt组合后MD5
    local hashed = ngx.md5(inputPassword .. salt)
    return hashed == dbPassword
end

function _login:login()
    local ok, err = _ApiCommon:validate({
        username = { required = true, label = "用户名", type = "string", min_len = 1, max_len = 64 },
        password = { required = true, label = "密码", type = "string", min_len = 1, max_len = 128 }
    })
    if not ok then
        _ApiCommon:api_output('', 400, err)
        return
    end
    
    local username = ngx.ctx._Request.username
    local password = ngx.ctx._Request.password
    local clientIp = ngx.var.remote_addr or ''
    
    local failCount = tonumber(_share_auth:get_login_fail(username)) or 0
    
    if failCount >= 5 then
        _ApiCommon:api_output('', 400, '账号已锁定，请联系管理员解锁')
        return
    end
    
    local res = ngx.ctx._ApiModel:getOne("gowaf_admin_account", {
        username = username
    })
    
    if not res then
        _ApiCommon:api_output('', 400, '用户名或密码错误')
        return
    end
    
    if res.state ~= 1 then
        _ApiCommon:api_output('', 400, '账号已禁用，请联系管理员')
        return
    end
    
    if not _verifyPassword(password, res.password, res.salt) then
        failCount = failCount + 1
        _share_auth:set_login_fail(username, failCount, 3600)
        
        -- 设置账号锁定
        if failCount >= 5 then
            ngx.ctx._ApiModel:update("gowaf_admin_account", { state = 2 }, { id = res.id })
        end
        
        _ApiCommon:api_output('', 400, '用户名或密码错误')
        return
    end
    
    _share_auth:delete_login_fail(username)
    
    local accessToken = _generateToken()
    local tokenExpire = 7200
    
    local adminInfo = {
        id = res.id,
        username = res.username,
        real_name = res.real_name,
        phone = res.phone,
        email = res.email,
        role = res.role,
        state = res.state
    }
    ngx.ctx._AdminInfo = adminInfo
    
    _share_auth:set_access_token(accessToken, json.encode(adminInfo), tokenExpire)
    
    local updateData = {
        login_time = os.date("%Y-%m-%d %H:%M:%S", ngx.now()),
        login_ip = clientIp
    }
    ngx.ctx._ApiModel:update("gowaf_admin_account", updateData, { id = res.id })
    
    _OperationLog:add({
        operation_type = "登录成功",
        operation_module = "登录认证",
        operation_content = {
            username = username,
            login_ip = clientIp,
            login_time = os.date("%Y-%m-%d %H:%M:%S", ngx.now())
        },
        operation_result = 1
    })
    
    _ApiCommon:api_output({
        access_token = accessToken,
        expire_time = tokenExpire,
        admin_info = adminInfo
    }, 200, '登录成功')
end

function _login:logout()
    local accessToken = ngx.req.get_headers()["access_token"]
    
    if not accessToken or accessToken == "" then
        _ApiCommon:api_output('', 400, '未登录')
        return
    end
    
    _share_auth:delete_access_token(accessToken)
    
    _ApiCommon:api_output('', 200, '退出成功')
end

return _login
