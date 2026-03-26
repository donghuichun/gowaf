# GowafV2 安装部署指南

## 目录
- [环境要求](#环境要求)
- [安装步骤](#安装步骤)
  - [1. Nginx配置](#1-nginx配置)
  - [2. 工程配置](#2-工程配置)
  - [3. 数据库配置](#3-数据库配置)
  - [4. 计划任务配置](#4-计划任务配置)
- [注意事项](#注意事项)

---

## 环境要求

- OpenResty >= 1.19.3
- MySQL >= 5.7
- Python >= 3.6（计划任务需要）

---

## 安装步骤

### 1. Nginx配置

#### 1.1 http块配置

在 `nginx.conf` 的 `http` 块中添加以下配置：

```nginx
http {
    # ... 其他配置 ...
    
    # WAF共享内存配置
    lua_shared_dict gowaflimit 512m;      # 用户访问缓存（限流、统计等）
    lua_shared_dict gowafsettings 100m;    # 配置缓存（黑白名单、路由配置等）
    
    # Lua包路径配置
    # 注意：路径需要指向工程目录的上一级
    # 例如工程路径为 /home/backend/gowaf_dev，则配置为 /home/backend
    lua_package_path ";/home/backend/?.lua;;";
    
    # ... 其他配置 ...
}
```

#### 1.2 server块配置

在需要开启防护的域名 `server` 块中添加：

```nginx
server {
    listen 80;
    server_name example.com;
    
    # 设置工程名称变量
    set $gowafname gowafV2_dev;
    
    # 开启WAF防护（在access阶段执行）
    access_by_lua_file "/home/backend/$gowafname/main.lua";
    log_by_lua_file "/home/backend/$gowafname/log.lua";
    # 开启Lua代码缓存（生产环境必须开启）
    lua_code_cache on;
    
    # 管理后台静态资源，最好独立配置域名访问
   location ^~ /_gowaf_admin/ {
      alias /home/backend/$gowafname/admin/html/;
      index index.html;
   }
    # ... 其他配置 ...
}
```

---

### 2. 工程配置

#### 2.1 env.lua配置文件

复制 `env.lua.example` 为 `env.lua`，并根据实际环境修改配置：

```lua
local _env = {}

_env = {
    -- 环境名称标识
    name = 'production',

    -- API认证配置
    appid = "10001",
    appsecret = "your-appsecret-here",
    api_domain = "http://your-domain.com",

    -- 日志目录配置
    debug = true, -- 是否开启调试模式
    config_log_dir = "/var/log/gowaf",
    project_dir = "/Users/dong/develop/gowaf/", -- 项目根目录上一级

    -- 共享缓存前缀配置（多环境部署时用于隔离不同环境的缓存数据）
    config_share_dict = {
        prefix = "local", -- 缓存前缀
        limit = "gowaflimit", -- 用户限制数据，如遇到统一服务器需要配置多套gowaf，需要配置不同库
        settings = "gowafsettings" -- 后台配置数据，如遇到统一服务器需要配置多套gowaf，需要配置不同库
    },

    -- MySQL数据库配置
    config_gowaf_mysql = {
        host = "127.0.0.1",
        port = 3306,
        user = "gowaf",
        password = "your-password",
        database = "gowaf_db",
        pool_size = 10
    },

    -- 需要检查的api路径，配置的目录才会被检查
    config_gowaf_uri_prefix_to_check = {
        '/api/', '/mall-api/', '/game-api/', '/ugc-api/'
    },

    -- 短链配置（可选）
    config_duanlian = {
        path_prefix = "/dl/",
        cache_time = 86400
    },

    -- WAF拦截后的响应配置
    config_waf_redirect_url = "https://www.example.com/blocked",
    config_output_html = [[
        {"code":"110110","msg":"参与人数较多，请稍后再试","data":""}
        ]],

    config_output_html_2 = [[
        {"code":"110110","msg":"访问过于频繁，请稍后再试","data":""}
        ]],

    config_output_html_3 = [[
        {"code":"110110","msg":"网络连接异常","data":""}
        ]],

    config_output_html_4 = [[
        {"code":"110110","msg":"人数较多，请稍后再试","data":""}
        ]],

    config_output_html_5 = [[
        {"code":"110110","msg":"当前访问人较多，请稍后再试","data":""}
        ]],

    config_output_html_6 = [[
        {"code":"110110","msg":"您的操作包含潜在风险，已被自动阻断。","data":""}
   ]]
}

return _env
```

#### 2.2 配置项说明

| 配置项 | 说明 | 必填 |
|--------|------|------|
| `name` | 环境标识，用于区分不同环境 | 否 |
| `appid` | API认证ID | 是 |
| `appsecret` | API认证密钥 | 是 |
| `api_domain` | API域名 | 是 |
| `config_log_dir` | 日志目录路径 | 是 |
| `config_gowaf_mysql` | MySQL数据库配置 | 是 |
| `config_share_dict.prefix` | 缓存前缀，多环境部署时需要不同 | 是 |

---

### 3. 数据库配置

#### 3.1 创建数据库

```sql
CREATE DATABASE gowaf_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
```

#### 3.2 创建数据表

依次执行以下SQL文件：

```bash
# 创建核心表
mysql -u gowaf -p gowaf_db < admin/dbsql/mysql_db.sql

```

#### 3.3 数据表说明

| 表名 | 说明 |
|------|------|
| `gowaf_blacklist` | IP黑名单表 |
| `gowaf_whitelist` | IP白名单表 |
| `gowaf_api_route` | 接口路由配置表 |
| `gowaf_api_route_category` | 接口路由分类表 |
| `gowaf_settings` | 系统设置表 |
| `gowaf_admin_account` | 管理员账号表 |
| `gowaf_admin_operation_log` | 操作日志表 |
| `gowaf_alert_logs` | 告警日志表 |

#### 3.4 初始化管理员账号

```sql
-- 插入默认管理员账号（密码：admin123）
INSERT INTO gowaf_admin_account (username, salt, password, real_name, role, state)
VALUES ('gowaf_admin_T8VH', 'B6VA', 'f1dd3205aa98c8808a52fa8776cf5904', '超级管理员', 1, 1);

账号：gowaf_admin_T8VH
密码：T3ZnyUea2S7uxZke

访问地址：`http://your-domain.com/_gowaf_admin/`
```

---

### 4. 计划任务配置

#### 4.1 后台任务

# 添加以下后台任务，最好使用supervisor管理

```
python3 /home/backend/$gowafname/gowaf_crontab.py

```
# 使用supervisor方式的配置示例

```
[program:gowaf_pro]
directory=/home/backend/gowafV2_pro
command=/usr/bin/python3 /home/backend/gowafV2_pro/gowaf_crontab.py
user=root
autostart=true
autorestart=true
startsecs=10
startretries=5
stderr_logfile=/home/logs/supervisord/gowafV2_pro.log
stdout_logfile=/home/logs/supervisord/gowafV2_pro.log

```

---

## 注意事项

### 1. 部署注意事项

1. **lua_package_path 配置**
   - 路径必须指向工程目录的上一级
   - 例如工程路径为 `/home/backend/gowaf_dev`，则配置为 `;/home/backend/?.lua;;`

2. **lua_code_cache**
   - 生产环境必须设置为 `on`
   - 开发环境可设置为 `off`，修改代码后无需重载

3. **共享内存大小**
   - `gowaflimit`：根据访问量和统计需求调整，建议 512M-2G
   - `gowafsettings`：根据配置数据量调整，建议 50M-200M

4. **缓存前缀**
   - 多环境部署在同一Nginx时，必须设置不同的 `config_share_dict.prefix`
   - 避免不同环境的缓存数据冲突

### 2. 运维注意事项

1. **配置修改后需要重载**
   - 修改黑白名单、路由配置、系统设置后，需要点击管理后台的"重载配置"按钮
   - 或执行 `nginx -s reload`

2. **Nginx重启后需要重载配置**
   - Nginx重启后，ngx.shared缓存会清空
   - 需要访问管理后台执行"重载配置"

3. **清理用户缓存影响**
   - 执行"清理用户缓存"后，管理后台需要重新登录
   - 今日访问统计数据会被清空

4. **日志目录权限**
   - 确保 `config_log_dir` 配置的目录存在且Nginx有写入权限
   - `mkdir -p /var/log/gowaf && chown nginx:nginx /var/log/gowaf`

### 3. 安全注意事项

1. **修改默认密码**
   - 首次部署后立即修改管理员密码
   - 修改 `appsecret` 配置

2. **数据库安全**
   - 使用专用数据库账号，限制权限
   - 不要使用root账号

3. **管理后台访问控制**
   - 建议限制管理后台的访问IP
   - 配置HTTPS

### 4. 性能优化建议

1. **开启lua_code_cache**
   - 生产环境必须开启

2. **合理设置共享内存**
   - 根据实际访问量调整 `gowaflimit` 大小

3. **数据库连接池**
   - 根据并发量调整 `pool_size`

4. **Redis连接池**
   - 根据并发量调整 `pool_size` 和 `keepalive_timeout`

---

## 快速检查清单

- [ ] Nginx已安装OpenResty
- [ ] 已配置 `lua_shared_dict`
- [ ] 已配置 `lua_package_path`
- [ ] 已创建数据库和数据表
- [ ] 已配置 `env.lua`
- [ ] 已初始化管理员账号
- [ ] 已配置计划任务
- [ ] 已修改默认密码
- [ ] 日志目录权限正确
- [ ] 测试访问正常
