/**
 * 打开指定ID的模态框
 * @param {string} id - 模态框元素的ID
 */
function openModal(id) {
    const modal = document.getElementById(id);
    if (modal) {
        modal.style.display = 'block';
    }
}

/**
 * 关闭指定ID的模态框
 * @param {string} id - 模态框元素的ID
 */
function closeModal(id) {
    const modal = document.getElementById(id);
    if (modal) {
        modal.style.display = 'none';
    }
}

/**
 * 显示确认对话框
 * @param {string} message - 确认消息
 * @param {function} onConfirm - 确认回调函数
 * @param {string} title - 对话框标题，默认为"确认操作"
 */
function showConfirm(message, onConfirm, title = '确认操作') {
    const confirmModal = document.getElementById('confirmModal');
    if (!confirmModal) {
        console.error('确认对话框不存在');
        return;
    }
    
    document.getElementById('confirmTitle').textContent = title;
    document.getElementById('confirmMessage').textContent = message;
    
    const confirmBtn = document.getElementById('confirmBtn');
    const cancelBtn = document.getElementById('cancelBtn');
    
    confirmBtn.onclick = function() {
        closeModal('confirmModal');
        if (typeof onConfirm === 'function') {
            onConfirm();
        }
    };
    
    cancelBtn.onclick = function() {
        closeModal('confirmModal');
    };
    
    openModal('confirmModal');
}

/**
 * 初始化Tab切换功能
 * 为所有.tab-btn按钮绑定点击事件，切换对应的.tab-pane内容
 */
function initTabSwitch() {
    const tabBtns = document.querySelectorAll('.tab-btn');
    tabBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            const tab = this.getAttribute('data-tab');
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
            this.classList.add('active');
            const tabPane = document.getElementById(tab);
            if (tabPane) {
                tabPane.classList.add('active');
            }
        });
    });
}

/**
 * 删除表格中的记录行
 * @param {HTMLElement} btn - 触发删除的按钮元素
 */
function deleteItem(btn) {
    showConfirm('确定要删除这条记录吗？', () => {
        btn.closest('tr').remove();
    });
}

/**
 * 删除规则记录
 * @param {HTMLElement} btn - 触发删除的按钮元素
 */
function deleteRule(btn) {
    showConfirm('确定要删除这条规则吗？', () => {
        btn.closest('tr').remove();
    });
}

/**
 * 编辑规则（提示功能开发中）
 * @param {HTMLElement} btn - 触发编辑的按钮元素
 */
function editRule(btn) {
    alert('编辑功能开发中...');
}

/**
 * 退出登录
 */
function logout() {
    LoginApi.logout()
        .then(data => {
            localStorage.removeItem('gowaf_access_token');
            localStorage.removeItem('gowaf_admin_info');
            localStorage.removeItem('gowaf_token_expire');
            
            toast.success('退出登录成功');
            
            setTimeout(() => {
                window.location.href = 'login.html';
            }, 1000);
        })
        .catch(error => {
            console.error('退出登录失败:', error);
            
            localStorage.removeItem('gowaf_access_token');
            localStorage.removeItem('gowaf_admin_info');
            localStorage.removeItem('gowaf_token_expire');
            
            window.location.href = 'login.html';
        });
}

let qpsChart = null;
let qpsInterval = null;

/**
 * 格式化时间戳为 HH:MM:SS 格式
 * @param {number} timestamp - Unix 时间戳
 * @returns {string} 格式化后的时间字符串
 */
function formatTime(timestamp) {
    const date = new Date(timestamp * 1000);
    return date.getHours().toString().padStart(2, '0') + ':' + 
           date.getMinutes().toString().padStart(2, '0') + ':' + 
           date.getSeconds().toString().padStart(2, '0');
}

/**
 * 更新 QPS 图表数据
 * @param {Array} data - QPS 数据数组
 */
function updateQpsChart(data) {
    if (!qpsChart || !data || !Array.isArray(data)) return;

    const reversedData = [...data].reverse();
    
    const labels = reversedData.map(item => formatTime(item.time));
    const qpsValues = reversedData.map(item => item.qps);
    
    qpsChart.data.labels = labels;
    qpsChart.data.datasets[0].data = qpsValues;
    qpsChart.update('none');
    
    const currentQpsEl = document.getElementById('currentQps');
    if (currentQpsEl && data.length > 0) {
        const currentQps = data[0].qps || 0;
        currentQpsEl.textContent = currentQps.toLocaleString();
    }
}

/**
 * 从 API 获取 QPS 数据并更新图表
 */
async function fetchAndUpdateQps() {
    try {
        const result = await StatApi.getAllQps();
        if (result && result.code === 200 && result.data) {
            updateQpsChart(result.data);
        }
    } catch (error) {
        console.error('获取 QPS 数据失败:', error);
    }
}

/**
 * 初始化QPS图表
 * 使用Chart.js绘制最近60秒的QPS趋势图
 */
function initQpsChart() {
    const canvas = document.getElementById('qpsChart');
    if (!canvas) return;

    // 销毁旧的图表实例
    if (qpsChart) {
        qpsChart.destroy();
        qpsChart = null;
    }

    const ctx = canvas.getContext('2d');
    const gradient = ctx.createLinearGradient(0, 0, 0, 360);
    gradient.addColorStop(0, 'rgba(22, 93, 255, 0.3)');
    gradient.addColorStop(1, 'rgba(22, 93, 255, 0.01)');

    const now = Math.floor(Date.now() / 1000);
    const initialLabels = Array.from({length: 60}, (_, i) => {
        return formatTime(now - 59 + i);
    });

    qpsChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: initialLabels,
            datasets: [{
                label: 'QPS',
                data: Array.from({length: 60}, () => 0),
                borderColor: '#165DFF',
                backgroundColor: gradient,
                fill: true,
                tension: 0.4,
                pointRadius: 0,
                pointHoverRadius: 6,
                pointHoverBackgroundColor: '#165DFF',
                pointHoverBorderColor: '#fff',
                pointHoverBorderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: 'rgba(0, 0, 0, 0.8)',
                    titleFont: { size: 12 },
                    bodyFont: { size: 14 },
                    padding: 12,
                    cornerRadius: 8
                }
            },
            scales: {
                x: {
                    grid: { display: false },
                    ticks: { color: '#86909C', font: { size: 11 } }
                },
                y: {
                    grid: { color: 'rgba(0, 0, 0, 0.04)' },
                    ticks: { color: '#86909C', font: { size: 11 } }
                }
            },
            interaction: {
                intersect: false,
                mode: 'index'
            }
        }
    });
    
    fetchAndUpdateQps();
}

/**
 * 初始化时间按钮切换
 * 为所有.btn-time按钮绑定点击事件，实现激活状态切换
 */
function initTimeButtons() {
    const timeBtns = document.querySelectorAll('.btn-time');
    timeBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.btn-time').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
        });
    });
}

/**
 * 初始化QPS实时刷新
 * 每3秒从API获取最新数据并更新图表
 */
function initQpsRefresh() {
    // 清除旧的定时器
    if (qpsInterval) {
        clearInterval(qpsInterval);
        qpsInterval = null;
    }
    
    // QPS 轮询已禁用
    // qpsInterval = setInterval(() => {
    //     fetchAndUpdateQps();
    // }, 3000);
}

/**
 * 初始化侧边栏
 * 通过fetch加载sidebar.html文件，并根据当前页面高亮对应的菜单项
 */
function initSidebar() {
    fetch('sidebar.html')
        .then(response => response.text())
        .then(html => {
            const sidebarContainer = document.getElementById('sidebar-container');
            if (sidebarContainer) {
                sidebarContainer.innerHTML = html;
                const currentPage = window.location.pathname.split('/').pop();
                const navItems = sidebarContainer.querySelectorAll('.nav-item, .nav-subitem');
                navItems.forEach(item => {
                    const href = item.getAttribute('href');
                    if (href === currentPage) {
                        item.classList.add('active');
                    }
                });
                initSidebarInteractions(sidebarContainer);
                
                // 恢复滚动位置
                restoreSidebarScroll();
            }
        })
        .catch(err => console.error('加载侧边栏失败:', err));
}

/**
 * 保存侧边栏滚动位置
 * 在页面切换前调用，保存当前滚动位置到localStorage
 */
function saveSidebarScroll() {
    const navMenu = document.querySelector('.nav-menu');
    if (navMenu) {
        localStorage.setItem('sidebar_scroll_top', navMenu.scrollTop);
    }
}

/**
 * 恢复侧边栏滚动位置
 * 在侧边栏加载完成后调用，从localStorage恢复滚动位置
 */
function restoreSidebarScroll() {
    const savedScrollTop = localStorage.getItem('sidebar_scroll_top');
    if (savedScrollTop) {
        const navMenu = document.querySelector('.nav-menu');
        if (navMenu) {
            navMenu.scrollTop = parseInt(savedScrollTop);
        }
    }
}

/**
 * 为所有导航链接添加点击事件，保存滚动位置
 */
function initNavigationLinks() {
    document.addEventListener('click', function(e) {
        const link = e.target.closest('a');
        if (link && (link.classList.contains('nav-item') || link.classList.contains('nav-subitem'))) {
            saveSidebarScroll();
        }
    });
}

/**
 * 初始化侧边栏交互
 * 为分组标题绑定展开/折叠事件
 * @param {HTMLElement} container - 侧边栏容器元素
 */
function initSidebarInteractions(container) {
    const groupHeaders = container.querySelectorAll('.nav-group-header');
    groupHeaders.forEach(header => {
        header.addEventListener('click', function() {
            const content = this.nextElementSibling;
            if (content && content.classList.contains('nav-group-content')) {
                content.classList.toggle('show');
                this.classList.toggle('collapsed');
            }
        });
    });
    const subgroupHeaders = container.querySelectorAll('.nav-subgroup-header');
    subgroupHeaders.forEach(header => {
        header.addEventListener('click', function() {
            const content = this.nextElementSibling;
            if (content && content.classList.contains('nav-subgroup-content')) {
                content.classList.toggle('show');
                this.classList.toggle('collapsed');
            }
        });
    });
    
    // 为侧边栏中的导航链接添加点击事件，保存滚动位置
    const navLinks = container.querySelectorAll('.nav-item, .nav-subitem');
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            saveSidebarScroll();
        });
    });
}

/**
 * 加载侧边栏
 * 通过fetch加载sidebar.html文件，并根据当前页面高亮对应的菜单项
 */
function loadSidebar() {
    fetch('sidebar.html')
        .then(response => response.text())
        .then(html => {
            const sidebar = document.getElementById('sidebar');
            if (sidebar) {
                sidebar.innerHTML = html;
                const currentPage = window.location.pathname.split('/').pop();
                const navItems = sidebar.querySelectorAll('.nav-item, .nav-subitem');
                navItems.forEach(item => {
                    const href = item.getAttribute('href');
                    if (href === currentPage) {
                        item.classList.add('active');
                    }
                });
                initSidebarInteractions(sidebar);
                
                // 恢复滚动位置
                restoreSidebarScroll();
            }
        })
        .catch(err => console.error('加载侧边栏失败:', err));
}

/**
 * 搜索栏组件类
 * 提供统一的搜索栏功能，支持添加搜索项、重置、搜索等操作
 */
class SearchBar {
    constructor(containerId, options = {}) {
        this.container = document.getElementById(containerId);
        if (!this.container) {
            console.error(`搜索栏容器 ${containerId} 不存在`);
            return;
        }
        this.options = {
            onSearch: options.onSearch || null,
            onReset: options.onReset || null,
            showReset: options.showReset !== false,
            searchButtonText: options.searchButtonText || '搜索',
            resetButtonText: options.resetButtonText || '重置'
        };
        this.searchItems = [];
        this.init();
    }

    init() {
        this.container.classList.add('search-bar');
        this.render();
    }

    addSearchItem(id, label, type = 'text', options = {}) {
        const searchItem = {
            id,
            label,
            type,
            options
        };
        this.searchItems.push(searchItem);
        this.render();
        return this;
    }

    render() {
        let html = '';
        this.searchItems.forEach(item => {
            html += this.renderSearchItem(item);
        });
        html += this.renderActions();
        this.container.innerHTML = html;
        this.bindEvents();
    }

    renderSearchItem(item) {
        const { id, label, type, options } = item;
        let inputHtml = '';

        switch (type) {
            case 'text':
                inputHtml = `<input type="text" id="${id}" class="form-control" placeholder="${options.placeholder || ''}">`;
                break;
            case 'select':
                inputHtml = `<select id="${id}" class="form-control">`;
                const selectOptions = Array.isArray(options) ? options : (options.options || []);
                selectOptions.forEach(opt => {
                    inputHtml += `<option value="${opt.value}">${opt.label}</option>`;
                });
                inputHtml += `</select>`;
                break;
            case 'date':
                inputHtml = `<input type="date" id="${id}" class="form-control">`;
                break;
            case 'datetime-local':
                inputHtml = `<input type="datetime-local" id="${id}" class="form-control">`;
                break;
            case 'number':
                inputHtml = `<input type="number" id="${id}" class="form-control" placeholder="${options.placeholder || ''}">`;
                break;
            default:
                inputHtml = `<input type="text" id="${id}" class="form-control" placeholder="${options.placeholder || ''}">`;
        }

        return `
            <div class="search-item" style="min-width: ${Array.isArray(options) ? '180px' : (options.minWidth || '180px')};">
                <label for="${id}" class="form-label">${label}</label>
                ${inputHtml}
            </div>
        `;
    }

    renderActions() {
        let actionsHtml = `
            <div class="search-actions">
                <button class="btn btn-primary" onclick="this.closest('.search-bar').searchBarInstance.search()">
                    <i class="bi bi-search"></i> ${this.options.searchButtonText}
                </button>
        `;
        if (this.options.showReset) {
            actionsHtml += `
                <button class="btn btn-outline-secondary" onclick="this.closest('.search-bar').searchBarInstance.reset()">
                    <i class="bi bi-arrow-counterclockwise"></i> ${this.options.resetButtonText}
                </button>
            `;
        }
        actionsHtml += `</div>`;
        return actionsHtml;
    }

    bindEvents() {
        this.container.searchBarInstance = this;
    }

    search() {
        const searchData = {};
        this.searchItems.forEach(item => {
            const element = document.getElementById(item.id);
            if (element) {
                searchData[item.id] = element.value;
            }
        });
        if (this.options.onSearch) {
            this.options.onSearch(searchData);
        }
    }

    reset() {
        this.searchItems.forEach(item => {
            const element = document.getElementById(item.id);
            if (element) {
                element.value = '';
            }
        });
        if (this.options.onReset) {
            this.options.onReset();
        }
    }

    getSearchData() {
        const searchData = {};
        this.searchItems.forEach(item => {
            const element = document.getElementById(item.id);
            if (element) {
                searchData[item.id] = element.value;
            }
        });
        return searchData;
    }

    setFieldValue(id, value) {
        const element = document.getElementById(id);
        if (element) {
            element.value = value;
        }
    }

    updateSearchItem(id, label, type = 'text', options = {}) {
        const index = this.searchItems.findIndex(item => item.id === id);
        if (index !== -1) {
            this.searchItems[index] = {
                id,
                label,
                type,
                options
            };
            this.render();
            this.bindEvents();
        }
        return this;
    }
}

/**
 * 页面DOM加载完成后执行初始化
 * 依次初始化登录检查、侧边栏、Tab切换、图表、时间按钮和QPS刷新
 */
document.addEventListener('DOMContentLoaded', function() {
    const accessToken = localStorage.getItem('gowaf_access_token');
    const currentPath = window.location.pathname;
    
    if (!accessToken && !currentPath.includes('login.html')) {
        window.location.href = 'login.html';
        return;
    }
    
    if (accessToken && currentPath.includes('login.html')) {
        window.location.href = 'index.html';
        return;
    }
    
    initSidebar();
    initTabSwitch();
    initQpsChart();
    initTimeButtons();
    
    if (currentPath.includes('index.html')) {
        initQpsRefresh();
    }
    
    initNavigationLinks();
});
