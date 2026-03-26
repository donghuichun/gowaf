/**
 * Toast 提示组件类
 * 提供美观的弹窗提示、报错等基本样式
 */
class Toast {
    constructor(options = {}) {
        this.position = options.position || 'top-right';
        this.duration = options.duration || 3000;
        this.maxCount = options.maxCount || 5;
        this.container = null;
        this.toasts = [];

        this.init();
    }

    /**
     * 初始化 Toast 容器
     */
    init() {
        if (!this.container) {
            this.container = document.createElement('div');
            this.container.className = `toast-container toast-${this.position}`;
            document.body.appendChild(this.container);
        }
    }

    /**
     * 显示提示消息
     * @param {string} message - 提示消息
     * @param {string} type - 提示类型：success, error, warning, info
     * @param {number} duration - 显示时长（毫秒）
     * @returns {Toast} 返回 Toast 实例
     */
    show(message, type = 'info', duration) {
        const toast = this.createToast(message, type, duration || this.duration);
        this.addToast(toast);
        return this;
    }

    /**
     * 显示成功提示
     * @param {string} message - 提示消息
     * @param {number} duration - 显示时长（毫秒）
     * @returns {Toast} 返回 Toast 实例
     */
    success(message, duration) {
        return this.show(message, 'success', duration);
    }

    /**
     * 显示错误提示
     * @param {string} message - 提示消息
     * @param {number} duration - 显示时长（毫秒）
     * @returns {Toast} 返回 Toast 实例
     */
    error(message, duration) {
        return this.show(message, 'error', duration);
    }

    /**
     * 显示警告提示
     * @param {string} message - 提示消息
     * @param {number} duration - 显示时长（毫秒）
     * @returns {Toast} 返回 Toast 实例
     */
    warning(message, duration) {
        return this.show(message, 'warning', duration);
    }

    /**
     * 显示信息提示
     * @param {string} message - 提示消息
     * @param {number} duration - 显示时长（毫秒）
     * @returns {Toast} 返回 Toast 实例
     */
    info(message, duration) {
        return this.show(message, 'info', duration);
    }

    /**
     * 创建 Toast 元素
     * @param {string} message - 提示消息
     * @param {string} type - 提示类型
     * @param {number} duration - 显示时长（毫秒）
     * @returns {HTMLElement} 返回 Toast 元素
     */
    createToast(message, type, duration) {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        
        const icon = this.getIcon(type);
        
        toast.innerHTML = `
            <div class="toast-icon">${icon}</div>
            <div class="toast-content">
                <div class="toast-message">${message}</div>
            </div>
            <button class="toast-close" onclick="this.parentElement.remove()">
                <i class="bi bi-x"></i>
            </button>
        `;

        toast.style.display = 'flex';
        toast.style.animation = 'toastSlideIn 0.3s ease';

        setTimeout(() => {
            this.removeToast(toast);
        }, duration);

        return toast;
    }

    /**
     * 获取图标
     * @param {string} type - 提示类型
     * @returns {string} 返回图标 HTML
     */
    getIcon(type) {
        const icons = {
            success: '<i class="bi bi-check-circle-fill"></i>',
            error: '<i class="bi bi-x-circle-fill"></i>',
            warning: '<i class="bi bi-exclamation-circle-fill"></i>',
            info: '<i class="bi bi-info-circle-fill"></i>'
        };
        return icons[type] || icons.info;
    }

    /**
     * 添加 Toast 到容器
     * @param {HTMLElement} toast - Toast 元素
     */
    addToast(toast) {
        if (this.toasts.length >= this.maxCount) {
            this.removeToast(this.toasts[0]);
        }

        this.toasts.push(toast);
        this.container.appendChild(toast);
    }

    /**
     * 移除 Toast
     * @param {HTMLElement} toast - Toast 元素
     */
    removeToast(toast) {
        const index = this.toasts.indexOf(toast);
        if (index > -1) {
            this.toasts.splice(index, 1);
        }

        if (toast && toast.parentElement) {
            toast.style.animation = 'toastSlideOut 0.3s ease';
            setTimeout(() => {
                if (toast.parentElement) {
                    toast.parentElement.removeChild(toast);
                }
            }, 300);
        }
    }

    /**
     * 清除所有 Toast
     */
    clear() {
        this.toasts.forEach(toast => {
            if (toast.parentElement) {
                toast.parentElement.removeChild(toast);
            }
        });
        this.toasts = [];
    }

    /**
     * 销毁 Toast 容器
     */
    destroy() {
        this.clear();
        if (this.container && this.container.parentElement) {
            this.container.parentElement.removeChild(this.container);
        }
        this.container = null;
    }
}

/**
 * Modal 模态框组件类
 */
class Modal {
    constructor(options = {}) {
        this.id = options.id || 'modal-' + Date.now();
        this.title = options.title || '';
        this.content = options.content || '';
        this.footer = options.footer || '';
        this.width = options.width || '550px';
        this.onConfirm = options.onConfirm || null;
        this.onCancel = options.onCancel || null;
        this.showClose = options.showClose !== false;
        this.confirmText = options.confirmText || '确定';
        this.cancelText = options.cancelText || '取消';
        this.confirmType = options.confirmType || 'primary';
        this.element = null;

        this.create();
    }

    /**
     * 创建模态框
     */
    create() {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.id = this.id;
        modal.style.display = 'none';

        modal.innerHTML = `
            <div class="modal-dialog" style="max-width: ${this.width}">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">${this.title}</h5>
                        ${this.showClose ? `
                            <button type="button" class="close-btn" data-dismiss="modal">
                                <i class="bi bi-x"></i>
                            </button>
                        ` : ''}
                    </div>
                    <div class="modal-body">${this.content}</div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-dismiss="modal">${this.cancelText}</button>
                        ${this.onConfirm ? `
                            <button type="button" class="btn btn-${this.confirmType}" data-confirm="true">${this.confirmText}</button>
                        ` : ''}
                        ${this.footer}
                    </div>
                </div>
            </div>
        `;

        document.body.appendChild(modal);
        this.element = modal;

        this.bindEvents();
    }

    /**
     * 绑定事件
     */
    bindEvents() {
        const closeButtons = this.element.querySelectorAll('[data-dismiss="modal"]');
        closeButtons.forEach(button => {
            button.addEventListener('click', () => this.hide());
        });

        const confirmButton = this.element.querySelector('[data-confirm="true"]');
        if (confirmButton) {
            confirmButton.addEventListener('click', () => {
                if (this.onConfirm) {
                    this.onConfirm();
                }
            });
        }

        this.element.addEventListener('click', (e) => {
            if (e.target === this.element) {
                this.hide();
            }
        });
    }

    /**
     * 显示模态框
     */
    show() {
        this.element.style.display = 'block';
    }

    /**
     * 隐藏模态框
     */
    hide() {
        this.element.style.display = 'none';
        if (this.onCancel) {
            this.onCancel();
        }
    }

    /**
     * 设置标题
     * @param {string} title - 标题
     */
    setTitle(title) {
        this.title = title;
        const titleElement = this.element.querySelector('.modal-title');
        if (titleElement) {
            titleElement.textContent = title;
        }
    }

    /**
     * 设置内容
     * @param {string} content - 内容
     */
    setContent(content) {
        this.content = content;
        const bodyElement = this.element.querySelector('.modal-body');
        if (bodyElement) {
            bodyElement.innerHTML = content;
        }
    }

    /**
     * 销毁模态框
     */
    destroy() {
        if (this.element && this.element.parentElement) {
            this.element.parentElement.removeChild(this.element);
        }
        this.element = null;
    }
}

/**
 * 创建 Toast 实例
 * @param {object} options - 配置选项
 * @returns {Toast} 返回 Toast 实例
 */
function createToast(options = {}) {
    return new Toast(options);
}

/**
 * 创建 Modal 实例
 * @param {object} options - 配置选项
 * @returns {Modal} 返回 Modal 实例
 */
function createModal(options = {}) {
    return new Modal(options);
}

/**
 * 全局 Toast 实例
 */
const toast = new Toast();

/**
 * 导出 Toast 和 Modal 模块
 */
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        Toast,
        Modal,
        createToast,
        createModal,
        toast
    };
}