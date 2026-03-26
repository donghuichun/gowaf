# GoWAF 管理后台 API 接口文档

## 1. 接口概述

GoWAF 管理后台 API 接口基于 Lua 开发，提供了完整的管理功能，包括用户认证、IP管理、路由管理、限流配置、监控统计等。接口采用 RESTful 风格，返回 JSON 格式数据。

## 2. 缓存服务器同步机制

### 2.1 设计背景

在多服务器部署场景下，每台代理服务器独立运行 GoWAF，共同访问一个数据库。当一台服务器修改了配置（如黑白名单、路由配置等）时，需要确保其他服务器也能及时更新缓存。

### 2.2 实现方案

采用任务表机制实现多服务器缓存同步：

1. **任务表设计**：创建 `gowaf_cache_task` 表，记录所有缓存更新任务
2. **任务执行记录表**：创建 `gowaf_cache_task_execution` 表，记录各服务器的任务执行状态
3. **任务检测**：每台服务器每秒检测任务表，获取未执行的任务
4. **任务执行**：执行任务并更新执行状态
5. **任务完成**：更新任务状态为已完成

### 2.3 表结构设计

#### 2.3.1 任务表 (`gowaf_cache_task`)

```sql
CREATE TABLE IF NOT EXISTS gowaf_cache_task (
    id INT AUTO_INCREMENT PRIMARY KEY,
    task_type VARCHAR(50) NOT NULL COMMENT '任务类型：settings/white_ip/black_ip/api_route/all',
    action VARCHAR(20) NOT NULL COMMENT '操作类型：add/update/delete/refresh',
    data JSON DEFAULT NULL COMMENT '任务数据，JSON格式',
    status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending' COMMENT '任务状态',
    priority INT DEFAULT 1 COMMENT '任务优先级，数字越大优先级越高',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    KEY idx_status (status),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='缓存同步任务表';
```

#### 2.3.2 任务执行记录表 (`gowaf_cache_task_execution`)

```sql
CREATE TABLE IF NOT EXISTS gowaf_cache_task_execution (
    id INT AUTO_INCREMENT PRIMARY KEY,
    task_id INT NOT NULL COMMENT '任务ID',
    server_id INT NOT NULL COMMENT '服务器ID',
    status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending' COMMENT '执行状态',
    error_message TEXT DEFAULT NULL COMMENT '错误信息',
    started_at TIMESTAMP NULL DEFAULT NULL COMMENT '开始执行时间',
    completed_at TIMESTAMP NULL DEFAULT NULL COMMENT '完成执行时间',
    KEY idx_task_id (task_id),
    KEY idx_server_id (server_id),
    KEY idx_status (status),
    FOREIGN KEY (task_id) REFERENCES gowaf_cache_task(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='任务执行记录表';
```

### 2.4 实现步骤

1. **添加任务**：管理后台接口在修改配置时，向任务表插入任务记录
2. **检测任务**：代理服务器每秒查询任务表，获取未执行的任务
3. **执行任务**：根据任务类型执行相应的缓存操作
4. **更新状态**：更新任务执行状态和任务状态
5. **清理任务**：定期清理已完成的任务记录

## 3. API 接口列表

### 3.1 认证接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/login/login` | POST | 用户登录 | username, password | `{"code": 200, "msg": "success", "data": {"token": "...", "user": {...}}}` |
| `/admin-api/login/logout` | POST | 用户登出 | token | `{"code": 200, "msg": "success", "data": {}}` |

### 3.2 账户管理接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/account/getList` | GET | 获取账号列表 | page, limit, username, status | `{"code": 200, "msg": "success", "data": {"list": [...], "total": 10}}` |
| `/admin-api/account/add` | POST | 添加账号 | username, password, real_name, phone, email, role, state | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/account/edit` | POST | 编辑账号 | id, real_name, phone, email, role, state | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/account/delete` | POST | 删除账号 | id | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/account/changePassword` | POST | 修改密码 | old_password, new_password | `{"code": 200, "msg": "success", "data": {}}` |

### 3.3 IP管理接口

#### 3.3.1 黑名单接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/blacklist/getList` | GET | 获取黑名单列表 | page, limit, ip_address, type, state, expire_state | `{"code": 200, "msg": "success", "data": {"list": [...], "total": 10}}` |
| `/admin-api/blacklist/add` | POST | 添加黑名单 | ip_address, type, expire_time, remark | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/blacklist/edit` | POST | 编辑黑名单 | id, state, expire_time, remark | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/blacklist/delete` | POST | 删除黑名单 | id | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/blacklist/batchImport` | POST | 批量导入黑名单 | ip_list | `{"code": 200, "msg": "success", "data": {}}` |

#### 3.3.2 白名单接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/whitelist/getList` | GET | 获取白名单列表 | page, limit, ip_address, type, state, expire_state | `{"code": 200, "msg": "success", "data": {"list": [...], "total": 10}}` |
| `/admin-api/whitelist/add` | POST | 添加白名单 | ip_address, type, expire_time, remark | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/whitelist/edit` | POST | 编辑白名单 | id, state, expire_time, remark | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/whitelist/delete` | POST | 删除白名单 | id | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/whitelist/batchImport` | POST | 批量导入白名单 | ip_list | `{"code": 200, "msg": "success", "data": {}}` |

### 3.4 路由管理接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/api_route/getList` | GET | 获取路由列表 | page, limit, route_url, type, tenant_config_open, ip_config_open, member_config_open | `{"code": 200, "msg": "success", "data": {"list": [...], "total": 10}}` |
| `/admin-api/api_route/add` | POST | 添加路由 | type, route_url, tenant_config, ip_config, member_config | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/api_route/edit` | POST | 编辑路由 | id, tenant_config, ip_config, member_config | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/api_route/delete` | POST | 删除路由 | id | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/api_route_category/getList` | GET | 获取路由分类列表 | page, limit, name | `{"code": 200, "msg": "success", "data": {"list": [...], "total": 10}}` |
| `/admin-api/api_route_category/add` | POST | 添加路由分类 | name, description | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/api_route_category/edit` | POST | 编辑路由分类 | id, name, description | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/api_route_category/delete` | POST | 删除路由分类 | id | `{"code": 200, "msg": "success", "data": {}}` |

### 3.5 系统设置接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/settings/getList` | GET | 获取设置列表 | page, limit, type | `{"code": 200, "msg": "success", "data": {"list": [...], "total": 10}}` |
| `/admin-api/settings/add` | POST | 添加设置 | type, content | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/settings/edit` | POST | 编辑设置 | id, content | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/settings/delete` | POST | 删除设置 | id | `{"code": 200, "msg": "success", "data": {}}` |

### 3.6 监控统计接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/monitor/getRealtimeData` | GET | 获取实时监控数据 | - | `{"code": 200, "msg": "success", "data": {"global_data": {...}, "server_data": [...]}}` |
| `/admin-api/stat/getAllQps` | GET | 获取最近60秒QPS数据 | - | `{"code": 200, "msg": "success", "data": [...]}` |
| `/admin-api/stat/getHistoryStats` | GET | 获取历史统计数据 | start_date, end_date, interval | `{"code": 200, "msg": "success", "data": [...]}` |
| `/admin-api/stat/get7DaysSummary` | GET | 获取7天汇总数据 | - | `{"code": 200, "msg": "success", "data": {...}}` |
| `/admin-api/stat/getAccessStatData` | GET | 获取访问统计数据 | server_id, start_date, end_date | `{"code": 200, "msg": "success", "data": {...}}` |
| `/admin-api/stat/getServerList` | GET | 获取服务器列表 | - | `{"code": 200, "msg": "success", "data": [...]}` |

### 3.7 告警管理接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/alert/getList` | GET | 获取告警列表 | page, limit, alert_type, alert_level, status, start_time, end_time | `{"code": 200, "msg": "success", "data": {"list": [...], "total": 10}}` |
| `/admin-api/alert/markRead` | POST | 标记告警为已读 | id | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/alert/markHandled` | POST | 标记告警为已处理 | id | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/alert/blockIp` | POST | 封禁告警IP | id | `{"code": 200, "msg": "success", "data": {}}` |

### 3.8 操作日志接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/operation_log/getList` | GET | 获取操作日志列表 | page, limit, admin_name, operation_module, operation_type, operation_result, start_time, end_time | `{"code": 200, "msg": "success", "data": {"list": [...], "total": 10}}` |

### 3.9 缓存管理接口

| 接口路径 | 方法 | 描述 | 参数 | 成功返回 |
|---------|------|------|------|---------|
| `/admin-api/cache/clearAll` | POST | 清空所有缓存 | - | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/cache/clearExpired` | POST | 清空过期缓存 | - | `{"code": 200, "msg": "success", "data": {}}` |
| `/admin-api/cache/getKeys` | GET | 获取缓存Key列表 | prefix | `{"code": 200, "msg": "success", "data": [...]}` |

## 4. 接口规范

### 4.1 响应格式

所有API接口返回统一的JSON格式：

```json
{
  "code": 200,         // 状态码，200表示成功，其他表示失败
  "msg": "success",    // 消息，成功或失败原因
  "data": {}           // 数据，根据接口不同返回不同格式
}
```

### 4.2 错误码

| 错误码 | 描述 |
|-------|------|
| 400 | 请求参数错误 |
| 401 | 未授权，登录过期 |
| 403 | 权限不足 |
| 500 | 服务器内部错误 |

### 4.3 认证机制

- 使用 Token 认证，登录成功后返回 Token
- Token 有效期为 2 小时
- 所有非登录接口需要在请求头中携带 `access_token`

### 4.4 请求频率限制

- 管理后台接口请求频率限制为 60 次/分钟
- 超过限制将返回 429 错误

## 5. 开发规范

### 5.1 接口命名规范

- 接口路径使用小写字母和下划线
- 接口方法使用 HTTP 标准方法（GET/POST/PUT/DELETE）
- 接口功能描述清晰，符合 RESTful 风格

### 5.2 参数命名规范

- 参数名使用小写字母和下划线
- 参数类型明确，必要参数必须验证
- 参数值范围合理，超出范围应返回错误

### 5.3 代码规范

- 使用 Lua 标准编码风格
- 函数名使用驼峰命名法
- 变量名使用小写字母和下划线
- 代码注释清晰，说明功能和参数

## 6. 安全注意事项

- 所有接口都需要进行参数验证，防止注入攻击
- 敏感操作需要记录操作日志，便于审计
- 密码等敏感信息需要加密存储
- 接口访问需要进行权限控制，防止越权操作
- 定期清理过期的 Token 和缓存数据