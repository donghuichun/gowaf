local _Main = {}

local gowafname = ngx.var.gowafname or "gowaf"
ngx.ctx._gowafname = gowafname

-- 初始化全局配置
local _Init = require(ngx.ctx._gowafname .. ".core.init")
_Init:init()

-- local json = require("cjson")
-- local _Lib = require(ngx.ctx._gowafname .. ".core.lib")

local _Tool = require(ngx.ctx._gowafname .. ".core.tool")
_Tool:process()

-- 配置关掉或者nginx配置了不处理，直接返回
-- if ngx.ctx._Config.config_waf_enable ~= "on" or ngx.var.gowaf_limit_enable == 'off' then
--     return
-- end

local requestMain = require(ngx.ctx._gowafname .. ".access.main")
requestMain:process()

-- local _checkUrl = require(ngx.ctx._gowafname .. ".check.checkUrl")
-- _checkUrl:check()

-- local _whiteIp = require(ngx.ctx._gowafname .. ".check.checkWhiteIp")
-- if _whiteIp:check() then
--     return
-- end

-- local _ipCheck = require(ngx.ctx._gowafname .. ".check.checkIp")
-- _ipCheck:check()

-- local _agent = require(ngx.ctx._gowafname .. ".check.checkAgent")
-- _agent:check()

-- local _urluserLimit = require(ngx.ctx._gowafname .. ".check.checkUrlUserLimit")
-- _urluserLimit:check()

-- local _urlipLimit = require(ngx.ctx._gowafname .. ".check.checkUrlIpLimit")
-- _urlipLimit:check()

-- local _urlLimit = require(ngx.ctx._gowafname .. ".check.checkUrlLimit")
-- _urlLimit:check()

return _Main
