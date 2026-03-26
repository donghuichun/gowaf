/**
 * 动态加载 axios
 * @returns {Promise} 返回 Promise 对象
 */
function loadAxios() {
    return new Promise((resolve, reject) => {
        if (typeof axios !== 'undefined') {
            resolve(axios);
            return;
        }
        
        const script = document.createElement('script');
        script.src = 'lib/axios/axios.min.js';
        script.onload = () => resolve(axios);
        script.onerror = () => reject(new Error('Failed to load axios'));
        document.head.appendChild(script);
    });
}

/**
 * API 请求封装类
 * 提供统一的 HTTP 请求接口，支持 GET、POST、PUT、DELETE 等方法
 */
class ApiClient {
    constructor(baseURL = '') {
        this.baseURL = baseURL;
        this.timeout = 30000;
        this.axiosLoaded = false;
    }

    /**
     * 确保 axios 已加载
     * @returns {Promise} 返回 Promise 对象
     */
    async ensureAxiosLoaded() {
        if (!this.axiosLoaded) {
            await loadAxios();
            this.axiosLoaded = true;
        }
    }

    /**
     * 设置基础 URL
     * @param {string} url - 基础 URL
     */
    setBaseURL(url) {
        this.baseURL = url;
    }

    /**
     * 设置超时时间
     * @param {number} timeout - 超时时间（毫秒）
     */
    setTimeout(timeout) {
        this.timeout = timeout;
    }

    /**
     * 通用请求方法
     * @param {string} url - 请求 URL
     * @param {object} options - 请求选项
     * @returns {Promise} 返回 Promise 对象
     */
    async request(url, options = {}) {
        await this.ensureAxiosLoaded();
        
        const accessToken = localStorage.getItem('gowaf_access_token');
        
        const config = {
            url: this.baseURL + url,
            timeout: this.timeout,
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            }
        };
        
        if (accessToken) {
            config.headers['Access-Token'] = accessToken;
        }
        
        Object.assign(config, options);

        try {
            const response = await axios(config);
            
            if (response.data && response.data.code === 401) {
                localStorage.removeItem('gowaf_access_token');
                localStorage.removeItem('gowaf_admin_info');
                localStorage.removeItem('gowaf_token_expire');
                
                if (!window.location.pathname.includes('login.html')) {
                    window.location.href = 'login.html';
                }
                
                return response.data;
            }
            
            return response.data;
        } catch (error) {
            if (error.response) {
                const data = error.response.data;
                
                if (data && data.code === 401) {
                    localStorage.removeItem('gowaf_access_token');
                    localStorage.removeItem('gowaf_admin_info');
                    localStorage.removeItem('gowaf_token_expire');
                    
                    if (!window.location.pathname.includes('login.html')) {
                        window.location.href = 'login.html';
                    }
                    
                    return data;
                }
                
                return data;
            } else if (error.request) {
                return {
                    code: 500,
                    msg: '网络请求失败，请检查网络连接'
                };
            } else {
                return {
                    code: 500,
                    msg: error.message || '请求发生错误'
                };
            }
        }
    }

    /**
     * GET 请求
     * @param {string} url - 请求 URL
     * @param {object} params - 查询参数
     * @param {object} options - 其他请求选项
     * @returns {Promise} 返回 Promise 对象
     */
    get(url, params = {}, options = {}) {
        return this.request(url, {
            method: 'GET',
            params,
            ...options
        });
    }

    /**
     * POST 请求
     * @param {string} url - 请求 URL
     * @param {object} params - 查询参数
     * @param {object} options - 其他请求选项
     * @returns {Promise} 返回 Promise 对象
     */
    post(url, params = {}, options = {}) {
        return this.request(url, {
            method: 'POST',
            params,
            ...options
        });
    }

    /**
     * PUT 请求
     * @param {string} url - 请求 URL
     * @param {object} params - 查询参数
     * @param {object} options - 其他请求选项
     * @returns {Promise} 返回 Promise 对象
     */
    put(url, params = {}, options = {}) {
        return this.request(url, {
            method: 'PUT',
            params,
            ...options
        });
    }

    /**
     * DELETE 请求
     * @param {string} url - 请求 URL
     * @param {object} params - 查询参数
     * @param {object} options - 其他请求选项
     * @returns {Promise} 返回 Promise 对象
     */
    delete(url, params = {}, options = {}) {
        return this.request(url, {
            method: 'DELETE',
            params,
            ...options
        });
    }
}

/**
 * 创建 API 实例
 * @param {string} baseURL - 基础 URL
 * @returns {ApiClient} 返回 ApiClient 实例
 */
function createApiClient(baseURL = '') {
    return new ApiClient(baseURL);
}

/**
 * 账号管理 API
 */
const AccountApi = {
    /**
     * 查询账号列表
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    query(params = {}) {
        return api.get('admin-api/account/query', params);
    },

    /**
     * 创建账号
     * @param {object} params - 账号参数
     * @returns {Promise} 返回 Promise 对象
     */
    create(params) {
        return api.post('admin-api/account/create', params);
    },

    /**
     * 更新账号
     * @param {object} params - 账号参数
     * @returns {Promise} 返回 Promise 对象
     */
    update(params) {
        return api.post('admin-api/account/update', params);
    },

    /**
     * 删除账号
     * @param {number} id - 账号 ID
     * @returns {Promise} 返回 Promise 对象
     */
    delete(id) {
        return api.post('admin-api/account/delete', { id });
    },

    /**
     * 获取账号详情
     * @param {number} id - 账号 ID
     * @returns {Promise} 返回 Promise 对象
     */
    detail(id) {
        return api.get('admin-api/account/detail', { id });
    },

    /**
     * 锁定/解锁账号
     * @param {number} id - 账号 ID
     * @param {number} state - 状态：1-正常，2-锁定
     * @returns {Promise} 返回 Promise 对象
     */
    lock(id, state) {
        return api.post('admin-api/account/lock', { id, state });
    }
};

/**
 * 黑名单管理 API
 */
const BlacklistApi = {
    /**
     * 查询黑名单列表
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    query(params = {}) {
        return api.get('admin-api/blacklist/query', params);
    },

    /**
     * 创建黑名单
     * @param {object} params - 黑名单参数
     * @returns {Promise} 返回 Promise 对象
     */
    create(params) {
        return api.post('admin-api/blacklist/create', params);
    },

    /**
     * 更新黑名单
     * @param {object} params - 黑名单参数
     * @returns {Promise} 返回 Promise 对象
     */
    update(params) {
        return api.post('admin-api/blacklist/update', params);
    },

    /**
     * 删除黑名单
     * @param {number} id - 黑名单 ID
     * @returns {Promise} 返回 Promise 对象
     */
    delete(id) {
        return api.post('admin-api/blacklist/delete', { id });
    },

    /**
     * 获取黑名单详情
     * @param {number} id - 黑名单 ID
     * @returns {Promise} 返回 Promise 对象
     */
    detail(id) {
        return api.get('admin-api/blacklist/detail', { id });
    }
};

/**
 * 白名单管理 API
 */
const WhitelistApi = {
    /**
     * 查询白名单列表
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    query(params = {}) {
        return api.get('admin-api/whitelist/query', params);
    },

    /**
     * 创建白名单
     * @param {object} params - 白名单参数
     * @returns {Promise} 返回 Promise 对象
     */
    create(params) {
        return api.post('admin-api/whitelist/create', params);
    },

    /**
     * 更新白名单
     * @param {object} params - 白名单参数
     * @returns {Promise} 返回 Promise 对象
     */
    update(params) {
        return api.post('admin-api/whitelist/update', params);
    },

    /**
     * 删除白名单
     * @param {number} id - 白名单 ID
     * @returns {Promise} 返回 Promise 对象
     */
    delete(id) {
        return api.post('admin-api/whitelist/delete', { id });
    },

    /**
     * 获取白名单详情
     * @param {number} id - 白名单 ID
     * @returns {Promise} 返回 Promise 对象
     */
    detail(id) {
        return api.get('admin-api/whitelist/detail', { id });
    }
};

/**
 * 系统设置 API
 */
const SettingsApi = {
    /**
     * 获取系统设置
     * @param {string} type - 设置类型
     * @returns {Promise} 返回 Promise 对象
     */
    get(type) {
        return api.get('admin-api/settings/get', { type });
    },

    /**
     * 根据类型获取设置
     * @param {string} type - 设置类型
     * @returns {Promise} 返回 Promise 对象
     */
    getByType(type) {
        return api.get('admin-api/settings/getByType', { type });
    },

    /**
     * 创建系统设置
     * @param {object} params - 设置参数
     * @returns {Promise} 返回 Promise 对象
     */
    create(params) {
        return api.post('admin-api/settings/create', params);
    },

    /**
     * 更新系统设置
     * @param {object} params - 设置参数
     * @returns {Promise} 返回 Promise 对象
     */
    update(params) {
        return api.post('admin-api/settings/update', params);
    }
};

/**
 * 操作日志 API
 */
const OperationLogApi = {
    /**
     * 查询操作日志
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    query(params = {}) {
        return api.get('admin-api/operation_log/query', params);
    },

    /**
     * 获取操作日志详情
     * @param {number} id - 日志 ID
     * @returns {Promise} 返回 Promise 对象
     */
    detail(id) {
        return api.get('admin-api/operation_log/detail', { id });
    }
};

/**
 * 路由配置 API
 */
const ApiRouteApi = {
    /**
     * 查询路由列表
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    query(params = {}) {
        return api.get('admin-api/api_route/query', params);
    },

    /**
     * 创建路由
     * @param {object} params - 路由参数
     * @returns {Promise} 返回 Promise 对象
     */
    create(params) {
        return api.post('admin-api/api_route/create', params);
    },

    /**
     * 更新路由
     * @param {object} params - 路由参数
     * @returns {Promise} 返回 Promise 对象
     */
    update(params) {
        return api.post('admin-api/api_route/update', params);
    },

    /**
     * 删除路由
     * @param {number} id - 路由 ID
     * @returns {Promise} 返回 Promise 对象
     */
    delete(id) {
        return api.post('admin-api/api_route/delete', { id });
    },

    /**
     * 获取路由详情
     * @param {number} id - 路由 ID
     * @returns {Promise} 返回 Promise 对象
     */
    detail(id) {
        return api.get('admin-api/api_route/detail', { id });
    }
};

/**
 * 路由分类管理 API
 */
const ApiRouteCategoryApi = {
    /**
     * 查询分类列表
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    query(params = {}) {
        return api.get('admin-api/api_route_category/query', params);
    },

    /**
     * 获取所有分类
     * @returns {Promise} 返回 Promise 对象
     */
    all() {
        return api.get('admin-api/api_route_category/all');
    },

    /**
     * 创建分类
     * @param {object} params - 分类参数
     * @returns {Promise} 返回 Promise 对象
     */
    create(params) {
        return api.post('admin-api/api_route_category/create', params);
    },

    /**
     * 更新分类
     * @param {object} params - 分类参数
     * @returns {Promise} 返回 Promise 对象
     */
    update(params) {
        return api.post('admin-api/api_route_category/update', params);
    },

    /**
     * 删除分类
     * @param {number} id - 分类 ID
     * @returns {Promise} 返回 Promise 对象
     */
    delete(id) {
        return api.post('admin-api/api_route_category/delete', { id });
    },

    /**
     * 获取分类详情
     * @param {number} id - 分类 ID
     * @returns {Promise} 返回 Promise 对象
     */
    detail(id) {
        return api.get('admin-api/api_route_category/detail', { id });
    }
};

/**
 * 登录认证 API
 */
const LoginApi = {
    /**
     * 登录
     * @param {object} params - 登录参数 {username, password}
     * @returns {Promise} 返回 Promise 对象
     */
    login(params) {
        return api.post('admin-api/login/login', params);
    },

    /**
     * 退出登录
     * @returns {Promise} 返回 Promise 对象
     */
    logout() {
        return api.post('admin-api/login/logout', {});
    }
};

/**
 * 系统信息 API
 */
const SystemApi = {
    /**
     * 获取系统基本信息
     * @returns {Promise} 返回 Promise 对象
     */
    getBasicInfo() {
        return api.get('admin-api/system/basicInfo');
    },

    /**
     * 重载配置
     * @returns {Promise} 返回 Promise 对象
     */
    reloadConfig() {
        return api.post('admin-api/system/reloadConfig');
    },

    /**
     * 清理配置缓存
     * @returns {Promise} 返回 Promise 对象
     */
    clearConfigCache() {
        return api.post('admin-api/system/clearConfigCache');
    },

    /**
     * 清理用户访问缓存
     * @returns {Promise} 返回 Promise 对象
     */
    clearLimitCache() {
        return api.post('admin-api/system/clearLimitCache');
    }
};

/**
 * 缓存工具 API
 */
const CacheApi = {
    /**
     * 获取缓存类型列表
     * @returns {Promise} 返回 Promise 对象
     */
    getTypes() {
        return api.get('admin-api/cache/getTypes');
    },

    /**
     * 获取缓存统计信息
     * @returns {Promise} 返回 Promise 对象
     */
    getStats() {
        return api.get('admin-api/cache/getStats');
    },

    /**
     * 获取缓存列表
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    getList(params = {}) {
        return api.get('admin-api/cache/getList', params);
    },

    /**
     * 获取缓存详情
     * @param {string} dict - 共享字典名称
     * @param {string} key - 缓存键
     * @returns {Promise} 返回 Promise 对象
     */
    getDetail(dict, key) {
        return api.get('admin-api/cache/getDetail', { dict, key });
    },

    /**
     * 删除缓存
     * @param {string} dict - 共享字典名称
     * @param {string} key - 缓存键
     * @returns {Promise} 返回 Promise 对象
     */
    delete(dict, key) {
        return api.post('admin-api/cache/delete', { dict, key });
    }
};

/**
 * 统计 API
 */
const StatApi = {
    /**
     * 获取最近 60 秒的 QPS 统计数据
     * @returns {Promise} 返回 Promise 对象
     */
    getAllQps() {
        return api.get('admin-api/stat/getAllQps');
    },

    /**
     * 获取历史统计数据
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    getHistoryStats(params = {}) {
        return api.get('admin-api/stat/getHistoryStats', params);
    },

    /**
     * 获取7天汇总数据
     * @returns {Promise} 返回 Promise 对象
     */
    get7DaysSummary() {
        return api.get('admin-api/stat/get7DaysSummary');
    },

    /**
     * 获取访问统计数据
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    getAccessStatData(params = {}) {
        return api.get('admin-api/stat/getAccessStatData', params);
    },

    /**
     * 获取服务器列表
     * @returns {Promise} 返回 Promise 对象
     */
    getServerList() {
        return api.get('admin-api/stat/getServerList');
    }
};

/**
 * 监控中心 API
 */
const MonitorApi = {
    /**
     * 获取实时监控数据
     * @returns {Promise} 返回 Promise 对象
     */
    getRealtimeData() {
        return api.get('admin-api/monitor/getRealtimeData');
    }
};

/**
 * 新版监控 API
 */
const MonitorNewApi = {
    /**
     * 获取实时监控数据（新版）
     * @returns {Promise} 返回 Promise 对象
     */
    getRealtimeData() {
        return api.get('admin-api/monitor_new/getRealtimeData');
    },

    /**
     * 获取所有服务器监控数据
     * @returns {Promise} 返回 Promise 对象
     */
    getAllServerData() {
        return api.get('admin-api/monitor_new/getAllServerData');
    }
};

/**
 * 告警记录 API
 */
const AlertApi = {
    /**
     * 查询告警记录
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    query(params = {}) {
        return api.get('admin-api/alert/query', params);
    },

    /**
     * 获取告警详情
     * @param {number} id - 告警ID
     * @returns {Promise} 返回 Promise 对象
     */
    getDetail(id) {
        return api.get('admin-api/alert/getDetail', { id });
    },

    /**
     * 标记告警已读
     * @param {string} ids - 告警ID列表，逗号分隔
     * @returns {Promise} 返回 Promise 对象
     */
    markRead(ids) {
        return api.post('admin-api/alert/markRead', { ids });
    },

    /**
     * 处理告警
     * @param {number} id - 告警ID
     * @param {string} action - 操作类型: block/ignore
     * @returns {Promise} 返回 Promise 对象
     */
    handle(id, action) {
        return api.post('admin-api/alert/handle', { id, action });
    }
};

/**
 * 创建全局 API 实例
 */
const api = createApiClient();

/**
 * 服务节点 API
 */
const ServersApi = {
    /**
     * 获取服务器列表
     * @param {object} params - 查询参数
     * @returns {Promise} 返回 Promise 对象
     */
    list(params = {}) {
        return api.get('admin-api/servers/list', params);
    },

    /**
     * 切换服务器类型
     * @param {object} params - 参数
     * @returns {Promise} 返回 Promise 对象
     */
    switchType(params) {
        return api.post('admin-api/servers/switchType', params);
    }
};

/**
 * 导出 API 模块
 */
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        ApiClient,
        createApiClient,
        AccountApi,
        BlacklistApi,
        WhitelistApi,
        SettingsApi,
        OperationLogApi,
        ApiRouteApi,
        ApiRouteCategoryApi,
        LoginApi,
        SystemApi,
        CacheApi,
        StatApi,
        MonitorApi,
        MonitorNewApi,
        AlertApi,
        ServersApi,
        api
    };
}
