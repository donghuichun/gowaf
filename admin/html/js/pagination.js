/**
 * 分页组件类
 * 提供美观的分页功能，显示总数据量和页码
 */
class Pagination {
    constructor(containerId, options = {}) {
        this.container = document.getElementById(containerId);
        if (!this.container) {
            console.error(`分页容器 #${containerId} 不存在`);
            return;
        }

        this.total = options.total || 0;
        this.pageSize = options.pageSize || 20;
        this.currentPage = options.currentPage || 1;
        this.maxPages = options.maxPages || 7;
        this.showTotal = options.showTotal !== false;
        this.showSizeChanger = options.showSizeChanger || false;
        this.pageSizeOptions = options.pageSizeOptions || [10, 20, 50, 100];
        this.onChange = options.onChange || function() {};

        this.init();
    }

    /**
     * 初始化分页组件
     */
    init() {
        this.render();
    }

    /**
     * 设置总数据量
     * @param {number} total - 总数据量
     */
    setTotal(total) {
        this.total = total;
        this.render();
    }

    /**
     * 设置当前页
     * @param {number} page - 当前页码
     */
    setCurrentPage(page) {
        this.currentPage = page;
        // 不在这里调用 render，避免重复渲染
    }

    /**
     * 设置每页显示数量
     * @param {number} size - 每页显示数量
     */
    setPageSize(size) {
        this.pageSize = size;
        this.currentPage = 1;
        // 不在这里调用 render，避免重复渲染
    }

    /**
     * 获取总页数
     * @returns {number} 返回总页数
     */
    getTotalPages() {
        return Math.ceil(this.total / this.pageSize) || 1;
    }

    /**
     * 渲染分页组件
     */
    render() {
        if (!this.container) return;

        const totalPages = this.getTotalPages();
        const html = this.generateHTML(totalPages);
        this.container.innerHTML = html;

        this.bindEvents();
    }

    /**
     * 生成分页 HTML
     * @param {number} totalPages - 总页数
     * @returns {string} 返回 HTML 字符串
     */
    generateHTML(totalPages) {
        let html = '<div class="pagination-wrapper">';

        if (this.showTotal) {
            html += `<div class="pagination-total">共 ${this.total} 条数据</div>`;
        }

        html += '<div class="pagination-controls">';
        html += '<nav aria-label="Page navigation">';
        html += '<ul class="pagination">';

        // 上一页按钮
        html += this.generatePrevButton(totalPages);

        // 页码按钮
        html += this.generatePageNumbers(totalPages);

        // 下一页按钮
        html += this.generateNextButton(totalPages);

        html += '</ul>';
        html += '</nav>';

        if (this.showSizeChanger) {
            html += this.generatePageSizeChanger();
        }

        html += '</div>';
        html += '</div>';

        return html;
    }

    /**
     * 生成上一页按钮
     * @param {number} totalPages - 总页数
     * @returns {string} 返回 HTML 字符串
     */
    generatePrevButton(totalPages) {
        const disabled = this.currentPage === 1 ? 'disabled' : '';
        return `
            <li class="page-item ${disabled}">
                <button class="page-link" data-page="${this.currentPage - 1}" aria-label="上一页">
                    <i class="bi bi-chevron-left"></i>
                    <span>上一页</span>
                </button>
            </li>
        `;
    }

    /**
     * 生成下一页按钮
     * @param {number} totalPages - 总页数
     * @returns {string} 返回 HTML 字符串
     */
    generateNextButton(totalPages) {
        const disabled = this.currentPage === totalPages ? 'disabled' : '';
        return `
            <li class="page-item ${disabled}">
                <button class="page-link" data-page="${this.currentPage + 1}" aria-label="下一页">
                    <span>下一页</span>
                    <i class="bi bi-chevron-right"></i>
                </button>
            </li>
        `;
    }

    /**
     * 生成页码按钮
     * @param {number} totalPages - 总页数
     * @returns {string} 返回 HTML 字符串
     */
    generatePageNumbers(totalPages) {
        let html = '';
        const pages = this.calculateVisiblePages(totalPages);

        pages.forEach(page => {
            if (page === '...') {
                html += `
                    <li class="page-item disabled">
                        <span class="page-link">...</span>
                    </li>
                `;
            } else {
                const active = page === this.currentPage ? 'active' : '';
                html += `
                    <li class="page-item ${active}">
                        <button class="page-link" data-page="${page}">
                            第${page}页
                        </button>
                    </li>
                `;
            }
        });

        return html;
    }

    /**
     * 计算可见页码
     * @param {number} totalPages - 总页数
     * @returns {Array} 返回页码数组
     */
    calculateVisiblePages(totalPages) {
        const pages = [];
        const half = Math.floor(this.maxPages / 2);

        if (totalPages <= this.maxPages) {
            for (let i = 1; i <= totalPages; i++) {
                pages.push(i);
            }
        } else {
            pages.push(1);

            if (this.currentPage > half + 2) {
                pages.push('...');
            }

            const start = Math.max(2, this.currentPage - half + 1);
            const end = Math.min(totalPages - 1, this.currentPage + half - 1);

            for (let i = start; i <= end; i++) {
                pages.push(i);
            }

            if (this.currentPage < totalPages - half - 1) {
                pages.push('...');
            }

            pages.push(totalPages);
        }

        return pages;
    }

    /**
     * 生成每页显示数量选择器
     * @returns {string} 返回 HTML 字符串
     */
    generatePageSizeChanger() {
        let html = '<div class="pagination-size-changer">';
        html += '<select class="form-select" id="pageSizeSelect">';

        this.pageSizeOptions.forEach(size => {
            const selected = size === this.pageSize ? 'selected' : '';
            html += `<option value="${size}" ${selected}>${size}条/页</option>`;
        });

        html += '</select>';
        html += '</div>';

        return html;
    }

    /**
     * 绑定事件
     */
    bindEvents() {
        const pageButtons = this.container.querySelectorAll('.page-link[data-page]');
        pageButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                e.preventDefault();
                const page = parseInt(button.getAttribute('data-page'));
                this.goToPage(page);
            });
        });

        if (this.showSizeChanger) {
            const sizeSelect = this.container.querySelector('#pageSizeSelect');
            if (sizeSelect) {
                sizeSelect.addEventListener('change', (e) => {
                    const size = parseInt(e.target.value);
                    this.setPageSize(size);
                    this.onChange(this.currentPage, size);
                });
            }
        }
    }

    /**
     * 跳转到指定页
     * @param {number} page - 页码
     */
    goToPage(page) {
        const totalPages = this.getTotalPages();
        if (page < 1 || page > totalPages || page === this.currentPage) {
            return;
        }

        this.currentPage = page;
        this.render();
        this.onChange(page, this.pageSize);
    }

    /**
     * 刷新分页组件
     */
    refresh() {
        this.render();
    }

    /**
     * 销毁分页组件
     */
    destroy() {
        if (this.container) {
            this.container.innerHTML = '';
        }
    }
}

/**
 * 创建分页实例
 * @param {string} containerId - 容器 ID
 * @param {object} options - 配置选项
 * @returns {Pagination} 返回 Pagination 实例
 */
function createPagination(containerId, options = {}) {
    return new Pagination(containerId, options);
}

/**
 * 导出分页模块
 */
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        Pagination,
        createPagination
    };
}