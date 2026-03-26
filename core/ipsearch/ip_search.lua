local _M = {}

local bit = require("bit")
local ffi = require("ffi")
local C = ffi.C

-- 定义 C 结构用于内存操作
ffi.cdef[[
    typedef unsigned char uint8_t;
    typedef unsigned int uint32_t;
]]

-- IP 搜索库类
local IPSearchLib = {}
IPSearchLib.__index = IPSearchLib

-- 将 4 个字节转换为无符号长整型
local function bytes_to_long(a, b, c, d)
    local iplong = string.byte(a) + bit.lshift(string.byte(b), 8) + bit.lshift(string.byte(c), 16) + bit.lshift(string.byte(d), 24)
    if iplong < 0 then
        iplong = iplong + 4294967296
    end
    return iplong
end

-- 将 IP 字符串转换为无符号整型
local function ip_to_uint(ip)
    local o1, o2, o3, o4 = ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
    if not o1 then
        return nil
    end
    local lng_ip = bit.lshift(tonumber(o1), 24) + bit.lshift(tonumber(o2), 16) + bit.lshift(tonumber(o3), 8) + tonumber(o4)
    if lng_ip < 0 then
        lng_ip = lng_ip + 4294967296
    end
    return lng_ip
end

-- 创建新的 IP 搜索实例
function _M.new(database_path)
    local self = setmetatable({}, IPSearchLib)

    -- 打开文件
    local fp = io.open(database_path, "rb")
    if not fp then
        return nil, "无法打开数据库文件: " .. database_path
    end

    self.fp = fp

    -- 读取文件头部信息 (16 字节)
    local buf = fp:read(16)
    if not buf or #buf < 16 then
        fp:close()
        return nil, "数据库文件格式错误"
    end

    self.first_start_ip_offset = bytes_to_long(buf:sub(1, 1), buf:sub(2, 2), buf:sub(3, 3), buf:sub(4, 4))
    self.last_start_ip_offset = bytes_to_long(buf:sub(5, 5), buf:sub(6, 6), buf:sub(7, 7), buf:sub(8, 8))
    self.prefix_start_offset = bytes_to_long(buf:sub(9, 9), buf:sub(10, 10), buf:sub(11, 11), buf:sub(12, 12))
    self.prefix_end_offset = bytes_to_long(buf:sub(13, 13), buf:sub(14, 14), buf:sub(15, 15), buf:sub(16, 16))

    self.ip_count = math.floor((self.last_start_ip_offset - self.first_start_ip_offset) / 12) + 1
    self.prefix_count = math.floor((self.prefix_end_offset - self.prefix_start_offset) / 9) + 1

    -- 读取前缀索引表
    self.prefix_array = {}
    fp:seek("set", self.prefix_start_offset)
    local pref_buf = fp:read(self.prefix_count * 9)

    for k = 0, self.prefix_count - 1 do
        local i = k * 9
        local prefix = string.byte(pref_buf:sub(i + 1, i + 1))
        local start_index = bytes_to_long(
            pref_buf:sub(i + 2, i + 2),
            pref_buf:sub(i + 3, i + 3),
            pref_buf:sub(i + 4, i + 4),
            pref_buf:sub(i + 5, i + 5)
        )
        local end_index = bytes_to_long(
            pref_buf:sub(i + 6, i + 6),
            pref_buf:sub(i + 7, i + 7),
            pref_buf:sub(i + 8, i + 8),
            pref_buf:sub(i + 9, i + 9)
        )
        self.prefix_array[prefix] = {
            start_index = start_index,
            end_index = end_index
        }
    end
    
    return self
end

-- 从文件读取指定字节
function IPSearchLib:read(offset, number_of_bytes)
    self.fp:seek("set", offset)
    return self.fp:read(number_of_bytes)
end

-- 获取指定索引的结束 IP
function IPSearchLib:get_end_ip(left)
    local left_offset = self.first_start_ip_offset + (left * 12) + 4
    local buf = self:read(left_offset, 4)
    return bytes_to_long(buf:sub(1, 1), buf:sub(2, 2), buf:sub(3, 3), buf:sub(4, 4))
end

-- 二分查找算法
function IPSearchLib:binary_search(low, high, k)
    local M = 0
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local end_ip_num = self:get_end_ip(mid)
        if end_ip_num >= k then
            M = mid
            if mid == 0 then
                break
            end
            high = mid - 1
        else
            low = mid + 1
        end
    end
    return M
end

-- 获取索引信息
function IPSearchLib:get_index(left)
    local left_offset = self.first_start_ip_offset + (left * 12)
    local buf = self:read(left_offset, 12)

    local start_ip = bytes_to_long(buf:sub(1, 1), buf:sub(2, 2), buf:sub(3, 3), buf:sub(4, 4))
    local end_ip = bytes_to_long(buf:sub(5, 5), buf:sub(6, 6), buf:sub(7, 7), buf:sub(8, 8))

    local r3 = string.byte(buf:sub(9, 9)) + bit.lshift(string.byte(buf:sub(10, 10)), 8) + bit.lshift(string.byte(buf:sub(11, 11)), 16)
    if r3 < 0 then
        r3 = r3 + 4294967296
    end

    local local_offset = r3
    local local_length = string.byte(buf:sub(12, 12))

    return start_ip, end_ip, local_offset, local_length
end

-- 获取地理位置信息
function IPSearchLib:get_local(local_offset, local_length)
    return self:read(local_offset, local_length)
end

-- 查询 IP 地址
function IPSearchLib:query(ip_address)
    if not ip_address or ip_address == "" then
        return nil
    end

    local ip_num = ip_to_uint(ip_address)
    if not ip_num then
        return nil
    end
    
    -- 获取前缀
    local prefix = tonumber(ip_address:match("^(%d+)"))
    if not prefix then
        return nil
    end

    local prefix_info = self.prefix_array[prefix]
    if not prefix_info then
        return nil
    end

    local low = prefix_info.start_index
    local high = prefix_info.end_index

    local left
    if low == high then
        left = low
    else
        left = self:binary_search(low, high, ip_num)
    end

    local start_ip, end_ip, local_offset, local_length = self:get_index(left)

    if start_ip <= ip_num and end_ip >= ip_num then
        return self:get_local(local_offset, local_length)
    else
        return nil
    end
end

-- 关闭文件
function IPSearchLib:close()
    if self.fp then
        self.fp:close()
        self.fp = nil
    end
end

-- 模块级缓存，避免重复加载
local ip_search_cache = {}

-- 获取 IP 地理位置（带缓存的单例模式）
function _M.get_ip_location(ip, database_path)
    if not ip or ip == "" then
        return nil
    end

    -- 验证 IP 格式
    if not ip:match("^%d+%.%d+%.%d+%.%d+$") then
        return nil
    end

    database_path = database_path or (ngx.ctx._Config.project_dir ..ngx.ctx._gowafname .. "/core/ipsearch/dat/gowaf-ip-utf8.dat")

    -- 检查缓存
    local cache_key = database_path
    local searcher = ip_search_cache[cache_key]

    if not searcher then
        local new_searcher, err = _M.new(database_path)
        if not new_searcher then
            ngx.log(ngx.ERR, "IP 数据库加载失败: ", err)
            return nil
        end
        ip_search_cache[cache_key] = new_searcher
        searcher = new_searcher
    end

    local area_info = searcher:query(ip)
    if not area_info then
        return nil
    end
    
    -- 解析返回结果
    local parts = {}
    local current_part = ""
    for i = 1, #area_info do
        local char = area_info:sub(i, i)
        if char == "|" then
            table.insert(parts, current_part)
            current_part = ""
        else
            current_part = current_part .. char
        end
    end
    -- 处理最后一个部分
    if current_part ~= "" or area_info:sub(-1) == "|" then
        table.insert(parts, current_part)
    end

    if #parts >= 11 then
        return {
            longitude = parts[10] or "",
            latitude = parts[11] or "",
            country = parts[2] or "",
            province = parts[3] or "",
            city = parts[4] or "",
            area = parts[5] or "",
            isp = parts[6] or "",
            continent = parts[1] or ""
        }
    end

    return nil
end

-- 清理缓存（用于热更新）
function _M.clear_cache()
    for _, searcher in pairs(ip_search_cache) do
        searcher:close()
    end
    ip_search_cache = {}
end

return _M
