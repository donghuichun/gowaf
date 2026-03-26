local mysql = require "resty.mysql"
local ngx = ngx

local Model = {}
Model.__index = Model

-- 构造函数：接收数据库配置参数
function Model:new(config)
    local instance = setmetatable({}, self)
    instance.config = {
        host = config.host or "127.0.0.1",
        port = config.port or 3306,
        user = config.user or "root",
        password = config.password or "",
        database = config.database or "",
        timeout = config.timeout or 1000,
        max_idle_timeout = config.max_idle_timeout or 10000,  -- 连接池空闲超时
        pool_size = config.pool_size or 10,                  -- 连接池大小
        charset = config.charset or "utf8mb4"
    }
    instance.db = nil
    return instance
end

-- 创建数据库连接（内部使用）
function Model:_connect()
    if self.db then
        return true
    end

    local db, err = mysql:new()
    if not db then
        return nil, "创建MySQL实例失败: " .. (err or "未知错误")
    end

    db:set_timeout(self.config.timeout)

    local ok, err = db:connect({
        host = self.config.host,
        port = self.config.port,
        user = self.config.user,
        password = self.config.password,
        database = self.config.database,
        charset = self.config.charset,
        max_packet_size = 1024 * 1024  -- 1MB
    })

    if not ok then
        return nil, "连接数据库失败: " .. (err or "未知错误")
    end

    self.db = db
    return true
end

-- ip日志拦截
function Model:sql_log(sql)
    local io = require 'io'
    local LOG_PATH = ngx.ctx._Config.config_log_dir
    local LOCAL_TIME = ngx.localtime()
    local LOG_LINE = LOCAL_TIME .. " " ..sql
    local LOG_NAME = LOG_PATH .. "/gowaf_sql.log"
    local file = io.open(LOG_NAME, "a")
    if file == nil then
        return
    end
    file:write(LOG_LINE .. "\n")
    file:flush()
    file:close()
end

-- 执行查询（返回结果集）
function Model:query(sql, params)
    local ok, err = self:_connect()
    if not ok then
        return nil, err
    end

    if ngx.ctx._Config.debug then
        self:sql_log(sql)
    end

    local res, err, errno, sqlstate = self.db:query(sql)
    
    self:keepalive()
    
    if not res then
        err = string.format("查询失败: %s, errno: %s, sqlstate: %s, sql: %s", err, errno, sqlstate, sql)
        ngx.log(ngx.ERR, err)
        return nil, err
    end

    return res
end

-- 执行非查询操作（INSERT/UPDATE/DELETE，返回影响行数）
function Model:execute(sql, params)
    local res, err = self:query(sql, params)
    if not res then
        return nil, err
    end
    return res.affected_rows or 0
end

-- 将连接放回连接池（推荐使用，而非直接关闭）
function Model:keepalive()
    if self.db then
        -- 连接池设置：空闲超时和连接池大小
        self.db:set_keepalive(self.config.max_idle_timeout, self.config.pool_size)
        self.db = nil
    end
    return true
end

-- 关闭连接（一般用于错误处理或连接池清理）
function Model:close()
    if self.db then
        self.db:close()
        self.db = nil
    end
    return true
end

-- 转义字符串，防止SQL注入
function Model:escape(value)
    local ok, err = self:_connect()
    if not ok then
        return nil, err
    end
    return self.db:escape_literal(value)
end

-- 构建WHERE条件
local function build_where(conditions)
    if not conditions or next(conditions) == nil then
        return ""
    end
    local where_parts = {}
    for k, v in pairs(conditions) do
        if type(v) == "string" then
            table.insert(where_parts, string.format("`%s` = %s", k, ngx.quote_sql_str(v)))
        elseif type(v) == "number" then
            table.insert(where_parts, string.format("`%s` = %d", k, v))
        elseif type(v) == "table" then
            if v.op then
                local op = v.op:upper()
                if op == "IS NULL" then
                    table.insert(where_parts, string.format("`%s` IS NULL", k))
                elseif op == "IS NOT NULL" then
                    table.insert(where_parts, string.format("`%s` IS NOT NULL", k))
                elseif v.value then
                    if op == "IN" and type(v.value) == "table" then
                        local in_vals = {}
                        for _, val in ipairs(v.value) do
                            if type(val) == "string" then
                                table.insert(in_vals, ngx.quote_sql_str(val))
                            else
                                table.insert(in_vals, tostring(val))
                            end
                        end
                        table.insert(where_parts, string.format("`%s` IN (%s)", k, table.concat(in_vals, ", ")))
                    elseif op == "LIKE" and type(v.value) == "string" then
                        table.insert(where_parts, string.format("`%s` LIKE %s", k, ngx.quote_sql_str("%" .. v.value .. "%")))
                    elseif op == "BETWEEN" and type(v.value) == "table" and #v.value == 2 then
                        local v1, v2 = v.value[1], v.value[2]
                        if type(v1) == "string" then v1 = ngx.quote_sql_str(v1) end
                        if type(v2) == "string" then v2 = ngx.quote_sql_str(v2) end
                        table.insert(where_parts, string.format("`%s` BETWEEN %s AND %s", k, v1, v2))
                    elseif op == "RAW" then
                        table.insert(where_parts, string.format("`%s` %s", k, v.value))
                    elseif op:sub(1, 11) == "IS NOT NULL" then
                        local extra_condition = op:sub(12)
                        table.insert(where_parts, string.format("`%s` IS NOT NULL AND %s", k, extra_condition))
                    else
                        local val = v.value
                        if type(val) == "string" then val = ngx.quote_sql_str(val) end
                        table.insert(where_parts, string.format("`%s` %s %s", k, op, val))
                    end
                end
            end
        end
    end
    return " WHERE " .. table.concat(where_parts, " AND ")
end

-- 构建SET语句
local function build_set(data)
    local set_parts = {}
    for k, v in pairs(data) do
        if type(v) == "string" then
            table.insert(set_parts, string.format("`%s` = %s", k, ngx.quote_sql_str(v)))
        elseif type(v) == "number" then
            table.insert(set_parts, string.format("`%s` = %d", k, v))
        elseif v == ngx.null then
            table.insert(set_parts, string.format("`%s` = NULL", k))
        end
    end
    return table.concat(set_parts, ", ")
end

-- 构建INSERT字段和值
local function build_insert(data)
    local fields, values = {}, {}
    for k, v in pairs(data) do
        table.insert(fields, "`" .. k .. "`")
        if type(v) == "string" then
            table.insert(values, ngx.quote_sql_str(v))
        elseif type(v) == "number" then
            table.insert(values, tostring(v))
        elseif v == ngx.null then
            table.insert(values, "NULL")
        end
    end
    return "(" .. table.concat(fields, ", ") .. ") VALUES (" .. table.concat(values, ", ") .. ")"
end

-- 查询一条数据
-- @param table_name string 表名
-- @param conditions table 查询条件，{字段=值, 字段={op=操作符, value=值}}
-- @param fields table 要查询的字段列表，默认全部字段
-- @param order_by string 排序字段和方向，如 "id DESC"
-- @return table, string 成功返回数据table，失败返回nil和错误信息
-- @example
-- 基本查询：db:getOne("users", {id=1}, {"id", "name"})
-- 条件查询：db:getOne("users", {state={op=">", value=0}}, {"id"}, "create_time DESC")
function Model:getOne(table_name, conditions, fields, order_by)
    local fields_str = "*"
    if fields and type(fields) == "table" and #fields > 0 then
        local field_list = {}
        for _, f in ipairs(fields) do
            table.insert(field_list, "`" .. f .. "`")
        end
        fields_str = table.concat(field_list, ", ")
    end
    local where_str = build_where(conditions)
    local order_str = ""
    if order_by then
        order_str = " ORDER BY " .. order_by
    end
    local sql = string.format("SELECT %s FROM `%s`%s%s LIMIT 1", fields_str, table_name, where_str, order_str)
    local res, err = self:query(sql)
    if not res then
        return nil, err
    end
    return res[1] or nil
end

-- 查询多条数据
-- @param table_name string 表名
-- @param conditions table 查询条件，{字段=值, 字段={op=操作符, value=值}}
-- @param fields table 要查询的字段列表，默认全部字段
-- @param limit number 查询数量限制
-- @param offset number 偏移量
-- @param order_by string 排序字段和方向，如 "id DESC"
-- @return table, string 成功返回数据table数组，失败返回nil和错误信息
-- @example
-- 分页查询：db:getMany("users", {state=1}, {"id", "name"}, 10, 0, "id DESC")
-- 条件查询：db:getMany("users", {age={op=">", value=18}}, nil, 20)
function Model:getMany(table_name, conditions, fields, limit, offset, order_by)
    local fields_str = "*"
    if fields and type(fields) == "table" and #fields > 0 then
        local field_list = {}
        for _, f in ipairs(fields) do
            table.insert(field_list, "`" .. f .. "`")
        end
        fields_str = table.concat(field_list, ", ")
    end
    local where_str = build_where(conditions)
    local order_str = ""
    if order_by then
        order_str = " ORDER BY " .. order_by
    end
    local limit_str = ""
    if limit then
        limit_str = " LIMIT " .. tonumber(limit)
        if offset then
            limit_str = limit_str .. " OFFSET " .. tonumber(offset)
        end
    end
    local sql = string.format("SELECT %s FROM `%s`%s%s%s", fields_str, table_name, where_str, order_str, limit_str)
    return self:query(sql)
end

-- 查询全部数据
-- @param table_name string 表名
-- @param fields table 要查询的字段列表，默认全部字段
-- @param order_by string 排序字段和方向，如 "id DESC"
-- @return table, string 成功返回数据table数组，失败返回nil和错误信息
-- @example
-- 查询所有用户：db:getAll("users", {"id", "name"}, "create_time DESC")
-- 简单查询：db:getAll("roles")
function Model:getAll(table_name, fields, order_by)
    local fields_str = "*"
    if fields and type(fields) == "table" and #fields > 0 then
        local field_list = {}
        for _, f in ipairs(fields) do
            table.insert(field_list, "`" .. f .. "`")
        end
        fields_str = table.concat(field_list, ", ")
    end
    local order_str = ""
    if order_by then
        order_str = " ORDER BY " .. order_by
    end
    local sql = string.format("SELECT %s FROM `%s`%s", fields_str, table_name, order_str)
    return self:query(sql)
end

-- 记录新增方法
-- @param table_name string 表名
-- @param data table 要插入的数据，{字段=值}
-- @return number, number, string 成功返回插入ID和影响行数，失败返回nil, nil和错误信息
-- @example
-- 插入用户：db:insert("users", {name="admin", email="admin@example.com", state=1})
-- 插入文章：db:insert("articles", {title="测试文章", content="内容", user_id=1})
function Model:insert(table_name, data)
    if not data or type(data) ~= "table" or next(data) == nil then
        return nil, "插入数据不能为空"
    end
    local insert_str = build_insert(data)
    local sql = string.format("INSERT INTO `%s` %s", table_name, insert_str)
    local res, err = self:query(sql)
    if not res then
        return nil, err
    end
    return res.insert_id, res.affected_rows
end

-- 批量新增方法
-- @param table_name string 表名
-- @param data_list table 要插入的数据列表，{{字段=值}, {字段=值}}
-- @return number, number, string 成功返回插入ID和影响行数，失败返回nil, nil和错误信息
-- @example
-- 批量插入用户：db:insertBatch("users", {{name="user1", email="user1@example.com"}, {name="user2", email="user2@example.com"}})
function Model:insertBatch(table_name, data_list)
    if not data_list or type(data_list) ~= "table" or #data_list == 0 then
        return nil, "插入数据不能为空"
    end
    local fields = {}
    for k, _ in pairs(data_list[1]) do
        table.insert(fields, "`" .. k .. "`")
    end
    local fields_str = "(" .. table.concat(fields, ", ") .. ")"
    local value_list = {}
    for _, data in ipairs(data_list) do
        local values = {}
        for k, _ in pairs(data_list[1]) do
            local v = data[k]
            if type(v) == "string" then
                table.insert(values, ngx.quote_sql_str(v))
            elseif type(v) == "number" then
                table.insert(values, tostring(v))
            elseif v == ngx.null then
                table.insert(values, "NULL")
            else
                table.insert(values, "NULL")
            end
        end
        table.insert(value_list, "(" .. table.concat(values, ", ") .. ")")
    end
    local sql = string.format("INSERT INTO `%s` %s VALUES %s", table_name, fields_str, table.concat(value_list, ", "))
    local res, err = self:query(sql)
    if not res then
        return nil, err
    end
    return res.insert_id, res.affected_rows
end

-- 记录更新方法
-- @param table_name string 表名
-- @param data table 要更新的数据，{字段=值}
-- @param conditions table 更新条件，{字段=值, 字段={op=操作符, value=值}}
-- @return number, string 成功返回影响行数，失败返回nil和错误信息
-- @example
-- 更新用户：db:update("users", {name="new_admin", state=0}, {id=1})
-- 条件更新：db:update("users", {state=1}, {last_login={op="<", value="2023-01-01"}})
function Model:update(table_name, data, conditions)
    if not data or type(data) ~= "table" or next(data) == nil then
        return nil, "更新数据不能为空"
    end
    local set_str = build_set(data)
    local where_str = build_where(conditions)
    local sql = string.format("UPDATE `%s` SET %s%s", table_name, set_str, where_str)
    local res, err = self:query(sql)
    if not res then
        return nil, err
    end
    return res.affected_rows or 0
end

-- 记录更新或者新增方法（根据主键判断）
-- @param table_name string 表名
-- @param data table 要操作的数据，{字段=值}，必须包含主键字段
-- @param primary_key string|table 主键字段名或主键字段数组
-- @return number, string 成功返回影响行数或插入ID，失败返回nil和错误信息
-- @example
-- 更新或插入用户：db:upsert("users", {id=1, name="admin", email="admin@example.com"}, "id")
-- 更新或插入配置：db:upsert("configs", {key="version", value="1.0.0"}, "key")
-- 更新或插入统计记录：db:upsert("stat_records", {server_id=1, type=1, t_id=1, time=1234567890, num=100}, {"server_id", "type", "t_id", "time"})
function Model:upsert(table_name, data, primary_key)
    if not data or type(data) ~= "table" or next(data) == nil then
        return nil, "数据不能为空"
    end
    
    local conditions = {}
    local condition_fields = {}
    
    if type(primary_key) == "string" then
        -- 单个主键字段
        if not data[primary_key] then
            return nil, "主键字段不能为空"
        end
        conditions[primary_key] = data[primary_key]
        condition_fields = {primary_key}
    elseif type(primary_key) == "table" then
        -- 多个主键字段（组合条件）
        for _, key in ipairs(primary_key) do
            if not data[key] then
                return nil, "主键字段 " .. key .. " 不能为空"
            end
            conditions[key] = data[key]
            table.insert(condition_fields, key)
        end
    else
        return nil, "主键参数必须是字符串或数组"
    end
    
    local exist, err = self:getOne(table_name, conditions, condition_fields)
    if err then
        return nil, err
    end
    if exist then
        local update_data = {}
        for k, v in pairs(data) do
            -- 检查是否为主键字段，如果是则不更新
            local is_primary_key = false
            if type(primary_key) == "string" then
                is_primary_key = (k == primary_key)
            elseif type(primary_key) == "table" then
                for _, pk in ipairs(primary_key) do
                    if k == pk then
                        is_primary_key = true
                        break
                    end
                end
            end
            
            if not is_primary_key then
                update_data[k] = v
            end
        end
        return self:update(table_name, update_data, conditions)
    else
        return self:insert(table_name, data)
    end
end

-- 记录删除方法
-- @param table_name string 表名
-- @param conditions table 删除条件，{字段=值, 字段={op=操作符, value=值}}，必须指定条件
-- @return number, string 成功返回影响行数，失败返回nil和错误信息
-- @example
-- 删除用户：db:delete("users", {id=1})
-- 条件删除：db:delete("logs", {create_time={op="<", value="2023-01-01"}})
function Model:delete(table_name, conditions)
    local where_str = build_where(conditions)
    if where_str == "" then
        return nil, "删除必须指定条件"
    end
    local sql = string.format("DELETE FROM `%s`%s", table_name, where_str)
    local res, err = self:query(sql)
    if not res then
        return nil, err
    end
    return res.affected_rows or 0
end

-- 统计记录数
-- @param table_name string 表名
-- @param conditions table 统计条件，{字段=值, 字段={op=操作符, value=值}}
-- @return number, string 成功返回记录数，失败返回nil和错误信息
-- @example
-- 统计用户数：db:count("users", {state=1})
-- 条件统计：db:count("orders", {amount={op=">", value=100}})
function Model:count(table_name, conditions)
    local where_str = build_where(conditions)
    local sql = string.format("SELECT COUNT(*) AS cnt FROM `%s`%s", table_name, where_str)
    local res, err = self:query(sql)
    if not res then
        return nil, err
    end
    local cnt = res[1] and res[1].cnt or 0
    return tonumber(cnt)
end

return Model