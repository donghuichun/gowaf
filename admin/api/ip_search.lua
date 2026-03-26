local _ipSearch = {}
local _apiCommon = require(ngx.ctx._gowafname .. ".admin.api.lib.common")
local json = require("cjson")
local _Lib = require(ngx.ctx._gowafname .. ".core.lib")

-- 获取 IP 归属地信息
-- GET /admin-api/ip_search/get?ip=xxx
function _ipSearch:get()
    local args = ngx.req.get_uri_args()
    local ip = args.ip

    if not ip or ip == "" then
        _apiCommon:api_output(nil, 400, 'IP 地址不能为空')
        return
    end

    local area_info, err = _Lib:get_ip_area(ip)
    local area_info, err = _Lib:get_ip_area(ip)
    local area_info, err = _Lib:get_ip_area(ip)
    local area_info, err = _Lib:get_ip_area(ip)
    local area_info, err = _Lib:get_ip_area(ip)
    local area_info, err = _Lib:get_ip_area(ip)
    if not area_info then
        _apiCommon:api_output(nil, 400, err or 'IP 地址定位失败')
        return
    end
    _apiCommon:api_output(area_info, 200, 'success')
end

-- -- 批量查询 IP 归属地
-- -- POST /api/ip-search/batch
-- -- body: {"ips": ["1.1.1.1", "2.2.2.2"]}
-- function _ipSearch:batch()
--     ngx.req.read_body()
--     local body = ngx.req.get_body_data()

--     if not body then
--         _apiCommon:api_output(nil, 400, '请求体不能为空')
--         return
--     end

--     local data
--     local ok, err = pcall(function()
--         data = json.decode(body)
--     end)

--     if not ok or not data then
--         _apiCommon:api_output(nil, 400, 'JSON 解析失败: ' .. (err or '未知错误'))
--         return
--     end

--     if not data.ips or type(data.ips) ~= 'table' or #data.ips == 0 then
--         _apiCommon:api_output(nil, 400, 'ips 参数不能为空且必须是数组')
--         return
--     end

--     if #data.ips > 100 then
--         _apiCommon:api_output(nil, 400, '单次最多查询 100 个 IP')
--         return
--     end

--     local results = {}
--     for _, ip in ipairs(data.ips) do
--         if type(ip) == 'string' and ip:match("^%d+%.%d+%.%d+%.%d+$") then
--             local location = _IPSearch.get_ip_location(ip)
--             if location then
--                 location.ip = ip
--                 table.insert(results, location)
--             else
--                 table.insert(results, {
--                     ip = ip,
--                     country = "",
--                     province = "",
--                     city = "",
--                     area = "",
--                     isp = "",
--                     longitude = "",
--                     latitude = ""
--                 })
--             end
--         end
--     end

--     _apiCommon:api_output({
--         list = results,
--         total = #results
--     }, 200, 'success')
-- end

return _ipSearch
