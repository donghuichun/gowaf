local _Lib = {}
-- waf core lib
local json = require("cjson")
local _Func = require(ngx.ctx._gowafname .. ".core.func")

-- 获取header数据
function _Lib:get_header_base()
    -- ip获取
    local headers = ngx.req.get_headers()
    -- local proxy_ip_list = ngx.var.proxy_add_x_forwarded_for
    local clientIP = headers["access-internal-ip"]
    if clientIP == nil or string.len(clientIP) == 0 or clientIP == "unknown" then
        clientIP = headers["host-yd-proxy-client-ip"]
    end
    if clientIP == nil or string.len(clientIP) == 0 or clientIP == "unknown" then
        clientIP = headers["x-real-ip"]
    end
    if clientIP == nil or string.len(clientIP) == 0 or clientIP == "unknown" then
        clientIP = headers["x-forwarded-for"]
    end
    if clientIP == nil or string.len(clientIP) == 0 or clientIP == "unknown" then
        clientIP = ngx.var.remote_addr
    end
    -- 对于通过多个代理的情况，第一个IP为客户端真实IP,多个IP按照','分割
    if clientIP ~= nil and string.len(clientIP) > 15 then
        -- ngx.log(ngx.ERR, 'IP MAX:' .. clientIP)
        local pos = string.find(clientIP, ",", 1)
        clientIP = string.sub(clientIP, 1, pos - 1)
    end
    if clientIP == nil then
        clientIP = "unknown"
    end

    -- 租户获取
    local t_id = headers["access-t-id"]
    if t_id == nil then
        t_id = '0'
    end

    -- 用户id
    local user_id = headers["access-user-id"]
    if user_id == nil then
        user_id = '0'
    end

    local ret = {
        client_ip = clientIP,
        t_id = tostring(t_id),
        user_id = tostring(user_id)
    }
    return ret
end

-- 获取useragent
function _Lib:get_user_agent()
    local USER_AGENT = ngx.var.http_user_agent
    if USER_AGENT == nil then
        USER_AGENT = "unknown"
    end
    return USER_AGENT
end

-- 获取get和post请求参数，返回json字符串
function _Lib:get_request_data()
    local request_data = {}
    local args = ngx.req.get_uri_args()
    if args ~= nil then
        for key, value in pairs(args) do
            request_data[key] = value
        end
    end
    ngx.req.read_body()
    local post_args = ngx.req.get_post_args()
    if post_args ~= nil then
        for key, value in pairs(post_args) do
            request_data[key] = value
        end
    end
    return request_data
end

-- 获取规则配置
function _Lib:get_rule(rulefilename)
    local RULE_TABLE = {}
    local RULE_TABLE = require(ngx.ctx._gowafname .. '.ruleconfig.' .. rulefilename)
    return (RULE_TABLE)
end

-- 获取租户id
function _Lib:get_t_id()
    local t_id = ngx.ctx._gowaf_t_id
    if not t_id or t_id == "" then
        t_id = "0"
    end
    return t_id
end

-- share dict key全局处理
function _Lib:make_share_dict_key(UID)
    UID = ngx.ctx._gowaf_share_dict_key_prefix .. UID
    -- UID = ngx.md5(ngx.ctx._gowaf_share_dict_key_prefix .. UID)
    return UID
end

-- ip日志拦截
function _Lib:log_record_ip(url, ip_pass_msg)
    local io = require 'io'
    local LOG_PATH = ngx.ctx._Config.config_log_dir
    local USER_AGENT = _Lib:get_user_agent()
    local SERVER_NAME = ngx.var.server_name
    local LOCAL_TIME = ngx.localtime()
    local log_json_obj = {
        t_id = ngx.ctx._gowaf_t_id,
        client_ip = ngx.ctx._gowaf_ip,
        local_time = LOCAL_TIME,
        req_url = url,
        ip_pass_msg = ip_pass_msg
    }
    local LOG_LINE = json.encode(log_json_obj)
    local LOG_NAME = LOG_PATH .. "/waf_blockip.log"
    local file = io.open(LOG_NAME, "a")
    if file == nil then
        return
    end
    file:write(LOG_LINE .. "\n")
    file:flush()
    file:close()
end

-- 日志记录
function _Lib:log_write(data, must_print)
    if not must_print and not ngx.ctx._Config.debug then
        return
    end
    local io = require 'io'
    local LOG_PATH = ngx.ctx._Config.config_log_dir
    local LOG_LINE = ''
    if type(data) == 'table' then
        LOG_LINE = json.encode(data)
    else
        LOG_LINE = tostring(data)
    end
    LOG_LINE = LOG_LINE .. "\n"

    -- [[**********临时打印用户请求参数**********]]
    local all_params = {
        access_uri = ngx.var.request_uri,
        access_get_args = ngx.req.get_uri_args(),
        access_headers = ngx.req.get_headers(),
    }
    LOG_LINE = LOG_LINE .. json.encode(all_params) .. "\n"

    local LOG_NAME = LOG_PATH .. '/' .. ngx.today() .. "_waf.log"
    local file = io.open(LOG_NAME, "a")
    if file == nil then
        return
    end
    file:write(LOG_LINE .. "\n")
    file:flush()
    file:close()
end

-- 全局日志拦截
function _Lib:log_record(method, url, data, ruletag)
    local io = require 'io'
    local LOG_PATH = ngx.ctx._Config.config_log_dir
    local USER_AGENT = _Lib:get_user_agent()
    local SERVER_NAME = ngx.var.server_name
    local LOCAL_TIME = ngx.localtime()
    local log_json_obj = {
        client_ip = ngx.ctx._gowaf_ip,
        local_time = LOCAL_TIME,
        -- server_name = SERVER_NAME,
        -- user_agent = USER_AGENT,
        attack_method = method,
        req_url = url,
        req_data = data
        -- rule_tag = ruletag
    }
    local LOG_LINE = json.encode(log_json_obj)
    local LOG_NAME = LOG_PATH .. '/' .. ngx.today() .. "_waf.log"
    local file = io.open(LOG_NAME, "a")
    if file == nil then
        return
    end
    file:write(LOG_LINE .. "\n")
    file:flush()
    file:close()
end

-- WAF return
function _Lib:waf_output(msg)
    if ngx.ctx._Config.config_waf_output == "redirect" then
        ngx.redirect(ngx.ctx._Config.config_waf_redirect_url, 301)
    else
        -- 跨域
        ngx.header["Content-Type"] = "application/json;charset=UTF-8"
        ngx.header["Access-Control-Allow-Origin"] = "*"
        ngx.header["Access-Control-Allow-Headers"] = "*"
        ngx.header["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        ngx.header["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        ngx.header["Pragma"] = "no-cache"
        if ngx.var.request_method == "OPTIONS" then
            ngx.header["Access-Control-Max-Age"] = "1728000"
            ngx.header["Content-Length"] = "0"
        end
        ngx.status = ngx.HTTP_OK
        -- ngx.status = ngx.HTTP_FORBIDDEN
        ngx.say(msg)
        ngx.exit(ngx.status)
    end
end

-- 规则验证锁定判断
function _Lib:limit_block_check(key, msg)
    -- 如果msg没值或者为空字符串，则退出
    if not msg or msg == "" then
        msg = ngx.ctx._Config.config_output_html_2
    end
    local uidstr = 'lb:' .. ngx.md5(key)
    local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")
    local ret = _share_limit:get(uidstr)
    if ret ~= nil then
        ngx.ctx._gowaf_req_blocked = true
        _Lib:waf_output(msg)
    end
end

-- 规则验证锁定增加
function _Lib:limit_block_add(key, block_time, count_now, alert_type)
    local high_alert_type = {'IP_LIMIT_GLOBAL'} -- 代表高风险报警类型
    -- 如果block_time没值或者小于等于0，则退出
    if not block_time or block_time <= 0 then
        return
    end
    count_now = count_now or 0
    ngx.ctx._gowaf_req_locked = true
    local uidstr = 'lb:' .. ngx.md5(key)
    local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")
    local _Alert = require(ngx.ctx._gowafname .. ".core.alert")

    -- 如果alert_type有值并且在高风险报警类型列表中，则设置为高风险
    local alert_level = 'medium'
    if alert_type and alert_type ~= '' and _Func:is_in_array(alert_type, high_alert_type) then
        alert_level = 'high'
    end
    
    _Alert:log_alert('LIMIT_BLOCK_ADD', alert_level, string.format('临时锁定key: %s, 访问次数: %d', key, count_now))
    _share_limit:set(uidstr, 1, block_time)
end

-- 日志节流验证
function _Lib:log_throt_check(key)
    local log_key = 'log_throt:' .. key
    local default_interval_time = 10 -- 默认10秒间隔
    local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")
    local last_log_time = _share_limit:get(log_key)
    local current_time = ngx.now()
    if not last_log_time or (current_time - last_log_time) >= default_interval_time then
        _share_limit:set(log_key, current_time, default_interval_time + 10)
        return true
    end
    return false
end

-- 获取ip归属地
-- longitude = parts[10] or "",
-- latitude = parts[11] or "",
-- country = parts[2] or "",
-- province = parts[3] or "",
-- city = parts[4] or "",
-- area = parts[5] or "",
-- isp = parts[6] or "",
-- continent = parts[1] or ""
function _Lib:get_ip_area(ip)
    local ip_search = require(ngx.ctx._gowafname .. ".core.ipsearch.ip_search")
    
    local ok, area_info = pcall(function()
        return ip_search.get_ip_location(ip)
    end)
    
    if not ok then
        ngx.log(ngx.ERR, "IP 地址定位异常: ", area_info)
        return nil, 'IP 地址定位失败'
    end
    
    if not area_info then
        return nil, 'IP 地址定位失败'
    end
    return area_info
end

-- 获取当前服务器本地IP
function _Lib:get_server_ip()
    local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")
    local ip = _share_settings:get_server_ip_cache()
    if ip then
        return ip
    end
    local handle = io.popen("hostname -I | awk '{print $1}'")
    local ip = handle:read("*a")
    handle:close()
    ip =ip:gsub("%s+", "")
    ip = ngx.re.gsub(ip or "", "^\\s+|\\s+$", "")
    if not ip or ip == "" then
        ip = '127.0.0.1'
    end
    _share_settings:set_server_ip_cache(ip)
    return ip
end

-- 获取当前服务器本地IP
function _Lib:get_server_uuid()
    local _share_settings = require(ngx.ctx._gowafname .. ".core.share.share_settings")
    local uuid = _share_settings:get_server_uuid_cache()
    if uuid then
        return uuid
    end

    local uuid = self:get_server_ip()
    if not uuid or uuid == "" then
        uuid = ngx.var.hostname
    end
    _share_settings:set_server_uuid_cache(uuid)
    return uuid
end

-- 获取当前服务器表ID
function _Lib:get_server_id()
    local server_uuid = self:get_server_uuid()
    -- 查询出server_uuid对应的记录id
    local _Servers = require(ngx.ctx._gowafname .. ".admin.api.servers")
    local server_record = _Servers:getByServerIdByCache(server_uuid)
    if not server_record then
        ngx.log(ngx.ERR, "未找到服务器记录: " .. server_uuid)
        return nil
    end
    return server_record.id
end

-- 验证该服务器是否为主节点
function _Lib:is_master_server()
    local server_uuid = self:get_server_uuid()
    local _Servers = require(ngx.ctx._gowafname .. ".admin.api.servers")
    local server_record = _Servers:getByServerIdByCache(server_uuid)
    if not server_record then
        return false
    end
    return server_record.type == "master"
end

return _Lib
