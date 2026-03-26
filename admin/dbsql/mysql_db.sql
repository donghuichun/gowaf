CREATE TABLE `gowaf_blacklist` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `type` tinyint(4) DEFAULT 1 COMMENT '类型：1-单个IP，2-网段',
  `ip_address` varchar(64) DEFAULT '' COMMENT 'IP地址/网段（如192.168.1.1或192.168.1.0/24）',
  `source` tinyint(4) DEFAULT 1 COMMENT '来源：1-手动，2-自动',
  `state` tinyint(4) DEFAULT 1 COMMENT '状态：1-已封禁，2-已取消',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `create_user_name` varchar(64) DEFAULT '' COMMENT '创建人（管理员账号）',
  `create_user_id` int(10) DEFAULT 0 COMMENT '创建人（管理员ID）',
  `expire_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '过期时间（NULL表示永久）',
  `remark` varchar(512) DEFAULT '' COMMENT '备注',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ip_type` (`ip_address`,`type`) COMMENT 'IP+类型唯一索引，避免重复',
  KEY `idx_state` (`state`) COMMENT '状态索引，查询封禁IP时提速',
  KEY `idx_expire_time` (`expire_time`) COMMENT '过期时间索引，清理过期数据时提速',
  KEY `idx_create_time` (`create_time`) COMMENT '创建时间索引，按时间范围查询'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='IP黑名单表';

CREATE TABLE `gowaf_api_route_category` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `category_name` varchar(64) DEFAULT '' COMMENT '分类名称',
  `remark` varchar(256) DEFAULT '' COMMENT '备注',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  `update_user_id` int(10) DEFAULT 0 COMMENT '修改人（管理员ID）',
  `update_user_name` varchar(64) DEFAULT '' COMMENT '修改人（管理员账号）',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='接口路由分类表';

CREATE TABLE `gowaf_whitelist` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `type` tinyint(4) DEFAULT 1 COMMENT '类型：1-单个IP，2-网段',
  `ip_address` varchar(64) DEFAULT '' COMMENT 'IP地址/网段（如192.168.1.1或192.168.1.0/24）',
  `source` tinyint(4) DEFAULT 1 COMMENT '来源：1-手动添加，2-自动添加',
  `state` tinyint(4) DEFAULT 1 COMMENT '状态：1-启用，2-关闭',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `create_user_name` varchar(64) DEFAULT '' COMMENT '创建人（管理员账号）',
  `create_user_id` bigint(20) DEFAULT 0 COMMENT '创建人（管理员ID）',
  `expire_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '过期时间（NULL表示永久）',
  `remark` varchar(512) DEFAULT '' COMMENT '备注',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ip_type` (`ip_address`,`type`) COMMENT 'IP+类型唯一索引，避免重复',
  KEY `idx_state` (`state`) COMMENT '状态索引，查询启用白名单时提速',
  KEY `idx_create_time` (`create_time`) COMMENT '创建时间索引，按时间范围查询'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='IP白名单表';

CREATE TABLE `gowaf_settings` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `type` varchar(64) DEFAULT '' COMMENT '设置类型（如ip_single_global_limit表示单个ip全局设置，ip_segment_global_limit表示ip网段全局设置，url_global_limit表示url全局设置，system_settings表示系统设置，web_attack_settings表示Web攻击设置）',
  `content` json COMMENT '设置内容（JSON格式，适配不同类型配置）',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  `update_user_id` int(10) DEFAULT 0 COMMENT '修改人（管理员ID）',
  `update_user_name` varchar(64) DEFAULT '' COMMENT '修改人（管理员账号）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_type` (`type`) COMMENT '设置类型唯一，避免重复配置',
  KEY `idx_update_time` (`update_time`) COMMENT '修改时间索引，按时间范围查询'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统设置表';
-- // 全局IP限流配置
-- {
--   "check_time": 3,
--   "check_num": 10,
--   "block_time": 300,
--   "open": 1
-- }

CREATE TABLE `gowaf_api_route` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `category_id` int(10) DEFAULT 0 COMMENT '分类ID，关联gowaf_api_route_category表',
  `type` tinyint(4) DEFAULT 1 COMMENT '类型：1-详细地址，2-通配符',
  `route_url` varchar(256) DEFAULT '' COMMENT '路由链接（如/api/activity、/gowaf_admin/*）',
  `tenant_config_open` tinyint(4) DEFAULT 0 COMMENT '租户配置开启状态：0-关闭，1-开启',
  `tenant_config` json COMMENT '租户配置（JSON格式）',
  `ip_limit_config_open` tinyint(4) DEFAULT 0 COMMENT 'IP限制配置开启状态：0-关闭，1-开启',
  `ip_limit_config` json COMMENT 'IP限制配置（JSON格式）',
  `member_limit_config_open` tinyint(4) DEFAULT 0 COMMENT '会员限制配置开启状态：0-关闭，1-开启',
  `member_limit_config` json COMMENT '会员限制配置（JSON格式）',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  `update_user_id` int(10) DEFAULT 0 COMMENT '修改人（管理员ID）',
  `update_user_name` varchar(64) DEFAULT '' COMMENT '修改人（管理员账号）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_type_route_url` (`type`,`route_url`) COMMENT '路由链接唯一，避免重复配置',
  KEY `idx_category_id` (`category_id`) COMMENT '分类ID索引',
  KEY `idx_ip_limit_open` (`ip_limit_config_open`) COMMENT 'IP限制开启状态索引',
  KEY `idx_update_time` (`update_time`) COMMENT '修改时间索引，按时间范围查询'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='接口路由配置表';
-- {
--   "single_ip_limit": 10,
--   "single_ip_seconds": 3,
--   "segment_limit": 40,
--   "segment_seconds": 3,
--   "cdn_ignore": 1
-- }

CREATE TABLE `gowaf_admin_account` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `username` varchar(64) DEFAULT '' COMMENT '管理员账号',
  `salt` varchar(64) DEFAULT '' COMMENT '盐值（用于密码加密）',
  `password` varchar(128) DEFAULT '' COMMENT '密码（MD5/SHA256加密）',
  `real_name` varchar(64) DEFAULT '' COMMENT '真实姓名',
  `phone` varchar(20) DEFAULT '' COMMENT '手机号',
  `email` varchar(64) DEFAULT '' COMMENT '邮箱',
  `role` tinyint(4) DEFAULT 3 COMMENT '角色：1-超级管理员，2-普通管理员，3-只读管理员',
  `state` tinyint(4) DEFAULT 1 COMMENT '状态：1-启用，2-禁用',
  `login_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最后登录时间',
  `login_ip` varchar(64) DEFAULT '' COMMENT '最后登录IP',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  `update_user_id` int(10) DEFAULT 0 COMMENT '修改人（管理员ID）',
  `update_user_name` varchar(64) DEFAULT '' COMMENT '修改人（管理员账号）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`) COMMENT '账号唯一',
  KEY `idx_role` (`role`) COMMENT '角色索引',
  KEY `idx_state` (`state`) COMMENT '状态索引',
  KEY `idx_login_time` (`login_time`) COMMENT '最后登录时间索引',
  KEY `idx_create_time` (`create_time`) COMMENT '创建时间索引，按时间范围查询',
  KEY `idx_update_time` (`update_time`) COMMENT '修改时间索引，按时间范围查询'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 AUTO_INCREMENT=10000 COMMENT='管理账号表';

CREATE TABLE `gowaf_admin_operation_log` (
  `id` int(10) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `admin_username` varchar(64) DEFAULT '' COMMENT '操作人账号（关联管理账号表username）',
  `operation_type` varchar(64) DEFAULT '' COMMENT '操作类型（如：添加黑名单、修改白名单、编辑路由配置、修改系统设置、账号新增/禁用等）',
  `operation_module` varchar(64) DEFAULT '' COMMENT '操作模块（如：黑白名单管理、系统设置、接口路由配置、管理员账号管理）',
  `operation_content` json COMMENT '操作内容（JSON格式，记录操作前后的关键数据）',
  `operation_ip` varchar(64) DEFAULT '' COMMENT '操作人IP地址（兼容IPv6）',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  `operation_result` tinyint(4) DEFAULT 1 COMMENT '操作结果：1-成功，2-失败',
  `error_msg` varchar(512) DEFAULT '' COMMENT '失败原因（操作失败时填写，成功则为空）',
  `request_id` varchar(64) DEFAULT '' COMMENT '请求唯一标识（用于问题排查）',
  PRIMARY KEY (`id`),
  KEY `idx_admin_username` (`admin_username`) COMMENT '操作人索引，查询单个管理员操作记录',
  KEY `idx_create_time` (`create_time`) COMMENT '操作时间索引，按时间范围查询/审计',
  KEY `idx_operation_module` (`operation_module`) COMMENT '模块索引，按模块筛选操作记录',
  KEY `idx_operation_type` (`operation_type`) COMMENT '操作类型索引，筛选特定操作'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台管理操作日志表';


-- 告警记录表
CREATE TABLE IF NOT EXISTS `gowaf_alert_logs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `t_id` int(11) default 0 COMMENT '租户ID',
  `user_id` varchar(64) default '' COMMENT '用户ID',
  `alert_type` varchar(60) NOT NULL COMMENT '告警类型: attack/block/slow/error',
  `alert_level` varchar(60) NOT NULL COMMENT '告警级别: high、medium、low',
  `client_ip` varchar(50) NOT NULL COMMENT '客户端IP',
  `request_uri` varchar(500) DEFAULT '' COMMENT '请求URI',
  `request_method` varchar(10) DEFAULT '' COMMENT '请求方法',
  `alert_detail` varchar(1000) DEFAULT '' COMMENT '告警详情',
  `user_agent` varchar(500) DEFAULT '' COMMENT 'User-Agent',
  `status` varchar(20) DEFAULT 'unread' COMMENT '状态: unread/readed/handled',
  `handled_by` varchar(50) DEFAULT '' COMMENT '处理人',
  `handled_at` timestamp NULL DEFAULT NULL COMMENT '处理时间',
  `province` varchar(100) DEFAULT '' COMMENT '省份',
  `city` varchar(100) DEFAULT '' COMMENT '城市',
  `area` varchar(100) DEFAULT '' COMMENT '区县',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_type` (`alert_type`),
  KEY `user_id` (`user_id`),
  KEY `idx_level` (`alert_level`),
  KEY `idx_status` (`status`),
  KEY `idx_created` (`created_at`),
  KEY `idx_ip` (`client_ip`),
  KEY `idx_province` (`province`),
  KEY `idx_city` (`city`),
  KEY `idx_area` (`area`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='GOWAF告警记录表';

-- 创建服务器表
CREATE TABLE IF NOT EXISTS `gowaf_servers` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL default '' COMMENT '服务器名称',
  `server_uuid` varchar(64) NOT NULL default '' COMMENT '服务器UUID',
  `ip` varchar(64) NOT NULL default '' COMMENT '服务器IP',
  `update_time` bigint(20) NOT NULL default 0 COMMENT '更新时间',
  `type` varchar(32) NOT NULL DEFAULT 'slave' COMMENT '主子类型，master-主节点，slave-子节点',
  PRIMARY KEY (`id`),
  KEY `idx_server_uuid` (`server_uuid`),
  KEY `idx_ip` (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='GOWAF服务器表';

-- 创建统计记录表
CREATE TABLE IF NOT EXISTS `gowaf_stat_records` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `server_id` int(11) default 0 COMMENT '服务器ID',
  `type` tinyint(4) DEFAULT 1 COMMENT '记录类型，1-qps、2-一天访问量、3-一天拦截量、4-一天锁定量等',
  `t_id` int(11) default 0 COMMENT '租户ID',
  `time` bigint(20) NOT NULL default 0 COMMENT '时间点，包含时间戳秒、到天日期、到分钟时间、如20230801、11位时间戳、202308011122',
  `num` bigint(20) NOT NULL default 0 COMMENT '统计数量',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_server_type_t_id_time` (`time`, `type`, `server_id`, `t_id`),
  KEY `idx_server_id` (`server_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='GOWAF统计记录表';

-- 创建服务同步操作调度表
CREATE TABLE IF NOT EXISTS `gowaf_server_sync_tasks` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `shared_name` varchar(100) NOT NULL default '' COMMENT '共享名称',
  `title` varchar(256) NOT NULL default '' COMMENT '任务标题',
  `action` varchar(100) NOT NULL default '' COMMENT '操作类型，如sync_config、sync_stat等',
  `data` varchar(2000) NOT NULL default '' COMMENT '操作数据，如JSON格式的配置数据',
  `status` tinyint(4) DEFAULT 0 COMMENT '状态，0-待处理、1-已完成、2-失败、3-处理中',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_create_time` (`create_time`) COMMENT '创建时间索引，按时间范围查询', 
  KEY `idx_status` (`status`) COMMENT '状态索引，按状态查询' 
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='GOWAF服务同步操作调度表';

-- 创建服务同步操作执行记录表
CREATE TABLE IF NOT EXISTS `gowaf_server_sync_tasks_execution` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `task_id` bigint(20) NOT NULL default 0 COMMENT '任务ID, 关联 gowaf_server_sync_tasks 表id',
  `server_id` int(11) NOT NULL default 0 COMMENT '服务器ID',
  `status` tinyint(4) DEFAULT 0 COMMENT '状态，0-待处理、1-已完成、2-失败、3-处理中',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_server_id` (`task_id`, `server_id`),
  KEY `idx_task_id` (`task_id`),
  KEY `idx_server_id` (`server_id`),
  KEY `idx_create_time` (`create_time`) COMMENT '创建时间索引，按时间范围查询' 
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='GOWAF服务同步操作执行记录表';
