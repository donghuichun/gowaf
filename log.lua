local _Log = {}

local gowafname = ngx.var.gowafname or "gowaf"
ngx.ctx._gowafname = gowafname

local _Stat = require(ngx.ctx._gowafname .. ".core.stat")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")
local _share_limit = require(ngx.ctx._gowafname .. ".core.share.share_limit")

function _Log:process()
    if not ngx.ctx._gowaf_req_access then
        return
    end
    
    -- 增加全局QPS统计
    _Stat:incr_all_qps()

    -- 增加今日统计
    _Stat:incr_today_stats()
end

_Log:process()

return _Log
