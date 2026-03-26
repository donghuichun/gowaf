/**
 * 批量添加路由数据脚本
 * 用法：在路由自定义设置页面的浏览器控制台中运行此脚本
 * 功能：自动添加200+20个路由数据（100+10个详细地址，100+10个通配符）
 */

// 生成随机路由数据的函数
function generateRouteData() {
    const routeTypes = [1, 2]; // 1: 详细地址, 2: 通配符
    const apiCategories = [
        'user', 'product', 'order', 'cart', 'payment', 'activity', 'coupon',
        'address', 'review', 'recommend', 'search', 'category', 'brand', 'supplier',
        'inventory', 'shipping', 'tax', 'invoice', 'refund', 'return',
        'wishlist', 'compare', 'notification', 'message', 'report', 'analytics',
        'setting', 'configuration', 'dashboard', 'admin'
    ];
    const apiActions = [
        'list', 'detail', 'create', 'update', 'delete', 'add', 'remove',
        'edit', 'save', 'cancel', 'submit', 'approve', 'reject', 'status',
        'search', 'filter', 'sort', 'export', 'import', 'sync'
    ];
    
    const routeData = [];
    
    // 生成100个详细地址类型路由
    for (let i = 0; i < 100; i++) {
        const category = apiCategories[Math.floor(Math.random() * apiCategories.length)];
        const action = apiActions[Math.floor(Math.random() * apiActions.length)];
        const subPath = Math.random() > 0.5 ? `/${Math.floor(Math.random() * 1000)}` : '';
        
        routeData.push({
            type: 1,
            route_url: `/api/${category}/${action}${subPath}`,
            tenant_config_open: Math.random() > 0.3 ? 1 : 0, // 70%启用
            ip_limit_config_open: Math.random() > 0.3 ? 1 : 0, // 70%启用
            member_limit_config_open: Math.random() > 0.3 ? 1 : 0, // 70%启用
            tenant_config: Math.random() > 0.3 ? JSON.stringify({
                check_time: Math.floor(Math.random() * 20) + 5, // 5-25秒
                check_num: Math.floor(Math.random() * 200) + 50, // 50-250次
                block_time: Math.floor(Math.random() * 300) // 0-300秒
            }) : null,
            ip_limit_config: Math.random() > 0.3 ? JSON.stringify({
                check_time: Math.floor(Math.random() * 10) + 2, // 2-12秒
                check_num: Math.floor(Math.random() * 100) + 20, // 20-120次
                block_time: Math.floor(Math.random() * 180) // 0-180秒
            }) : null,
            member_limit_config: Math.random() > 0.3 ? JSON.stringify({
                check_time: Math.floor(Math.random() * 30) + 10, // 10-40秒
                check_num: Math.floor(Math.random() * 300) + 100, // 100-400次
                block_time: Math.floor(Math.random() * 600) // 0-600秒
            }) : null
        });
    }
    
    // 生成100个通配符类型路由
    for (let i = 0; i < 100; i++) {
        const category = apiCategories[Math.floor(Math.random() * apiCategories.length)];
        const subCategory = Math.random() > 0.5 ? `/${apiCategories[Math.floor(Math.random() * apiCategories.length)]}` : '';
        
        routeData.push({
            type: 2,
            route_url: `/api/${category}${subCategory}/*`,
            tenant_config_open: Math.random() > 0.3 ? 1 : 0, // 70%启用
            ip_limit_config_open: Math.random() > 0.3 ? 1 : 0, // 70%启用
            member_limit_config_open: Math.random() > 0.3 ? 1 : 0, // 70%启用
            tenant_config: Math.random() > 0.3 ? JSON.stringify({
                check_time: Math.floor(Math.random() * 20) + 5, // 5-25秒
                check_num: Math.floor(Math.random() * 200) + 50, // 50-250次
                block_time: Math.floor(Math.random() * 300) // 0-300秒
            }) : null,
            ip_limit_config: Math.random() > 0.3 ? JSON.stringify({
                check_time: Math.floor(Math.random() * 10) + 2, // 2-12秒
                check_num: Math.floor(Math.random() * 100) + 20, // 20-120次
                block_time: Math.floor(Math.random() * 180) // 0-180秒
            }) : null,
            member_limit_config: Math.random() > 0.3 ? JSON.stringify({
                check_time: Math.floor(Math.random() * 30) + 10, // 10-40秒
                check_num: Math.floor(Math.random() * 300) + 100, // 100-400次
                block_time: Math.floor(Math.random() * 600) // 0-600秒
            }) : null
        });
    }
    
    // 原有20个固定路由数据
    const fixedRouteData = [
        // 详细地址类型路由
        {
            type: 1,
            route_url: '/api/user/list',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 })
        },
        {
            type: 1,
            route_url: '/api/user/detail',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 })
        },
        {
            type: 1,
            route_url: '/api/product/list',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 })
        },
        {
            type: 1,
            route_url: '/api/product/detail',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 1,
            route_url: '/api/order/list',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 1,
            route_url: '/api/order/detail',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 1,
            route_url: '/api/cart/list',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 1,
            route_url: '/api/cart/add',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 1,
            route_url: '/api/payment/create',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 1,
            route_url: '/api/payment/query',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        // 通配符类型路由
        {
            type: 2,
            route_url: '/api/user/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 2,
            route_url: '/api/product/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 2,
            route_url: '/api/order/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 2,
            route_url: '/api/cart/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 2,
            route_url: '/api/payment/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 2,
            route_url: '/api/activity/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 2,
            route_url: '/api/coupon/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 2,
            route_url: '/api/address/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 2,
            route_url: '/api/review/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        },
        {
            type: 2,
            route_url: '/api/recommend/*',
            tenant_config_open: 1,
            ip_limit_config_open: 1,
            member_limit_config_open: 1,
            tenant_config: JSON.stringify({ check_time: 10, check_num: 100, block_time: 0 }),
            ip_limit_config: JSON.stringify({ check_time: 5, check_num: 50, block_time: 0 }),
            member_limit_config: JSON.stringify({ check_time: 15, check_num: 150, block_time: 0 }),
        }
    ];
    
    // 合并随机生成的数据和固定数据
    return [...routeData, ...fixedRouteData];
}

// 批量添加路由数据函数
async function batchAddRoutes() {
    const routeData = generateRouteData();
    console.log('开始批量添加路由数据...');
    console.log(`共${routeData.length}个路由数据`);
    
    let successCount = 0;
    let errorCount = 0;
    
    for (let i = 0; i < routeData.length; i++) {
        const route = routeData[i];
        console.log(`正在添加第${i + 1}个路由: ${route.route_url}`);
        
        try {
            const result = await ApiRouteApi.create(route);
            
            if (result.code === 200) {
                console.log(`✅ 成功添加路由: ${route.route_url}`);
                successCount++;
            } else {
                console.log(`❌ 失败添加路由: ${route.route_url}, 错误: ${result.msg}`);
                errorCount++;
            }
        } catch (error) {
            console.log(`❌ 异常添加路由: ${route.route_url}, 错误: ${error.message}`);
            errorCount++;
        }
        
        // 避免请求过快，添加100ms延迟
        await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    console.log('批量添加路由数据完成!');
    console.log(`成功: ${successCount}, 失败: ${errorCount}`);
    
    // 刷新页面，显示新添加的数据
    console.log('刷新页面中...');
    setTimeout(() => {
        window.location.reload();
    }, 1000);
}

// 运行批量添加函数
batchAddRoutes();