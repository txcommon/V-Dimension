// js/bug-fixes.js - 完整修复版
class BugFixes {
    constructor() {
        this.isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
        this.isAndroid = /Android/i.test(navigator.userAgent);
        
        this.state = {
            canConnect: true, // 默认可以连接
            lastConnectTime: 0,
            // Android键盘状态
            androidKeyboardOpen: false,
            androidKeyboardAnimating: false,
            isProcessingAndroidTap: false
        };
    }
    
    init() {
        console.log('[BugFixes] 初始化修复');
        
        // ✅ 重复连接防护
        this.fixConnectionThrottle();
        
        // ✅ 网络切换监听
        this.fixNetworkListeners();
        
        // ✅ iOS滚动优化
        if (this.isIOS) {
            this.enhanceIOSScroll();
        }
        
        // ✅ Android键盘点击修复
        if (this.isAndroid) {
            // 延迟初始化，确保DOM完全加载
            setTimeout(() => {
                this.fixAndroidKeyboardIssues();
            }, 1000);
        }
        
        return this;
    }
    
    // ==================== 重复连接防护（修复版） ====================
    fixConnectionThrottle() {
        console.log('[BugFixes] 设置连接防护');
        
        // 包装connectWallet函数
        if (typeof window.connectWallet === 'function') {
            this.wrapConnectWallet();
        }
    }
    
    wrapConnectWallet() {
        const originalConnectWallet = window.connectWallet;
        
        window.connectWallet = async function() {
            const now = Date.now();
            const timeSinceLastConnect = now - (window.bugFixes?.state.lastConnectTime || 0);
            
            console.log('[BugFixes] 连接检查', { timeSinceLastConnect });
            
            // 3秒内刚刚连接过，阻止
            if (timeSinceLastConnect < 3000 && window.bugFixes?.state.lastConnectTime > 0) {
                if (window.showMessage) {
                    window.showMessage('请等待3秒后再试', 'warning');
                }
                return;
            }
            
            // 记录连接时间
            if (window.bugFixes) {
                window.bugFixes.state.lastConnectTime = now;
            }
            
            // 执行原函数
            return await originalConnectWallet.apply(this, arguments);
        };
    }
    
    // ==================== 网络切换监听 ====================
    fixNetworkListeners() {
        if (typeof window.ethereum === 'undefined') return;
        
        console.log('[BugFixes] 设置网络切换监听');
        
        if (window.ethereum._bugfixChainListener) return;
        
        window.ethereum.on('chainChanged', (chainId) => {
            console.log('[BugFixes] 网络切换:', chainId);
            
            // 重置连接时间，允许重新连接
            if (window.bugFixes) {
                window.bugFixes.state.lastConnectTime = 0;
            }
            
            // 延迟更新数据
            setTimeout(async () => {
                if (window.web3Manager?.account && window.updateUI) {
                    try {
                        await window.updateUI();
                    } catch (error) {
                        console.error('[BugFixes] 网络切换更新失败:', error);
                    }
                }
            }, 1500);
        });
        
        window.ethereum._bugfixChainListener = true;
    }
    
    // ==================== iOS滚动优化 ====================
    enhanceIOSScroll() {
        if (!this.isIOS) return;
        
        console.log('[BugFixes] iOS滚动优化');
        
        const input = document.getElementById('resonateInput');
        if (!input) return;
        
        input.addEventListener('focus', () => {
            setTimeout(() => {
                const willReceiveRow = document.querySelector('.will-receive-row');
                if (willReceiveRow) {
                    willReceiveRow.scrollIntoView({
                        behavior: 'smooth',
                        block: 'center'
                    });
                }
            }, 450);
        }, { passive: true });
    }
    
    // ==================== Android键盘问题修复（核心修复） ====================
    fixAndroidKeyboardIssues() {
        console.log('[BugFixes] 初始化Android键盘修复');
        
        // 1. 监控键盘状态
        this.setupAndroidKeyboardMonitor();
        
        // 2. 修复共振按钮点击（核心修复）
        setTimeout(() => {
            this.fixResonateButtonClick();
        }, 1500);
        
        // 3. 保护Tab按钮不被误触
        setTimeout(() => {
            this.protectTabButtons();
        }, 2000);
    }
    
    // 1. 监控Android键盘状态
    setupAndroidKeyboardMonitor() {
        let originalViewportHeight = window.innerHeight;
        let keyboardCheckTimeout = null;
        
        const checkKeyboardState = () => {
            const currentHeight = window.innerHeight;
            const heightDiff = originalViewportHeight - currentHeight;
            
            // 键盘弹出（高度减少超过300px）
            if (heightDiff > 300) {
                if (!this.state.androidKeyboardOpen) {
                    console.log('[BugFixes] Android键盘弹出');
                    this.state.androidKeyboardOpen = true;
                    this.state.androidKeyboardAnimating = true;
                    
                    // 动画结束后标记
                    setTimeout(() => {
                        this.state.androidKeyboardAnimating = false;
                        console.log('[BugFixes] 键盘弹出动画完成');
                    }, 500);
                }
            }
            // 键盘收起
            else if (heightDiff < 50 && this.state.androidKeyboardOpen) {
                console.log('[BugFixes] Android键盘收起');
                this.state.androidKeyboardOpen = false;
                this.state.androidKeyboardAnimating = true;
                
                setTimeout(() => {
                    this.state.androidKeyboardAnimating = false;
                    this.state.isProcessingAndroidTap = false;
                    console.log('[BugFixes] 键盘收起动画完成');
                }, 400);
            }
            
            originalViewportHeight = currentHeight;
        };
        
        // 监听窗口大小变化（Android键盘的主要检测方式）
        window.addEventListener('resize', () => {
            clearTimeout(keyboardCheckTimeout);
            keyboardCheckTimeout = setTimeout(checkKeyboardState, 100);
        });
        
        // 辅助检测：输入框焦点
        const input = document.getElementById('resonateInput');
        if (input) {
            input.addEventListener('focus', () => {
                this.state.androidKeyboardOpen = true;
                this.state.androidKeyboardAnimating = true;
                
                setTimeout(() => {
                    this.state.androidKeyboardAnimating = false;
                }, 600);
            });
            
            input.addEventListener('blur', () => {
                this.state.androidKeyboardAnimating = true;
                
                setTimeout(() => {
                    this.state.androidKeyboardOpen = false;
                    this.state.androidKeyboardAnimating = false;
                    this.state.isProcessingAndroidTap = false;
                }, 400);
            });
        }
    }
    
    // 2. 修复共振按钮点击（核心方法）
    fixResonateButtonClick() {
        const resonateBtn = document.getElementById('resonateBtn');
        const input = document.getElementById('resonateInput');
        
        if (!resonateBtn || !input) {
            console.warn('[BugFixes] 共振按钮或输入框未找到，延迟重试');
            setTimeout(() => this.fixResonateButtonClick(), 500);
            return;
        }
        
        console.log('[BugFixes] 修复共振按钮点击事件');
        
        // 保存原始点击处理器
        const originalOnClick = resonateBtn.onclick;
        
        // 关键修复1：使用pointerdown事件（在touchstart之前触发）
        resonateBtn.addEventListener('pointerdown', (e) => {
            console.log('[BugFixes] pointerdown触发', {
                keyboardOpen: this.state.androidKeyboardOpen,
                animating: this.state.androidKeyboardAnimating,
                activeElement: document.activeElement?.id
            });
            
            // 如果正在处理Android点击，阻止所有后续事件
            if (this.state.isProcessingAndroidTap) {
                e.stopImmediatePropagation();
                e.preventDefault();
                console.log('[BugFixes] 正在处理点击，阻止重复事件');
                return;
            }
            
            // 如果键盘打开且输入框有焦点
            if (this.state.androidKeyboardOpen && document.activeElement === input) {
                console.log('[BugFixes] Android键盘打开时点击共振按钮');
                
                // 标记正在处理Android点击
                this.state.isProcessingAndroidTap = true;
                
                // 立即阻止所有后续事件传播
                e.stopImmediatePropagation();
                e.preventDefault();
                
                // 第一步：先检查按钮是否可用
                if (resonateBtn.disabled) {
                    console.log('[BugFixes] 共振按钮被禁用');
                    this.state.isProcessingAndroidTap = false;
                    return;
                }
                
                // 第二步：立即执行共振逻辑（不等待键盘动画）
                setTimeout(() => {
                    if (typeof window.handleResonate === 'function') {
                        console.log('[BugFixes] 执行共振逻辑');
                        window.handleResonate();
                    }
                }, 10); // 极短延迟确保事件处理完成
                
                // 第三步：延迟收起键盘（避免干扰事件流）
                setTimeout(() => {
                    if (document.activeElement === input) {
                        console.log('[BugFixes] 延迟收起键盘');
                        input.blur();
                    }
                    
                    // 延迟重置状态
                    setTimeout(() => {
                        this.state.isProcessingAndroidTap = false;
                        console.log('[BugFixes] Android点击处理完成');
                    }, 500);
                }, 300); // 300ms后收起键盘
                
                return false;
            }
        }, { capture: true, passive: false }); // 使用捕获阶段，非被动模式
        
        // 关键修复2：处理touchstart事件（Android主要触摸事件）
        resonateBtn.addEventListener('touchstart', (e) => {
            if (this.state.androidKeyboardOpen && document.activeElement === input) {
                // 仅记录，不阻止，让pointerdown处理
                console.log('[BugFixes] touchstart事件（键盘打开状态）');
            }
        }, { passive: true });
        
        // 关键修复3：处理click事件（备用兼容）
        resonateBtn.addEventListener('click', (e) => {
            console.log('[BugFixes] click事件触发', {
                isProcessingAndroidTap: this.state.isProcessingAndroidTap
            });
            
            // 如果Android点击已经处理过，阻止click事件
            if (this.state.isProcessingAndroidTap) {
                console.log('[BugFixes] 已处理过Android点击，阻止click事件');
                e.stopImmediatePropagation();
                e.preventDefault();
                
                // 执行原始点击逻辑（如果需要）
                if (originalOnClick && !resonateBtn.disabled) {
                    setTimeout(() => {
                        originalOnClick.call(resonateBtn, e);
                    }, 10);
                }
                
                return false;
            }
            
            // 正常情况：执行原始点击逻辑
            if (originalOnClick && !resonateBtn.disabled) {
                return originalOnClick.call(resonateBtn, e);
            }
        });
        
        console.log('[BugFixes] 共振按钮点击修复完成');
    }
    
    // 3. 保护Tab按钮不被误触
    protectTabButtons() {
        const tabButtons = document.querySelectorAll('.tab-btn');
        
        if (!tabButtons.length) {
            console.warn('[BugFixes] Tab按钮未找到');
            return;
        }
        
        console.log('[BugFixes] 保护Tab按钮，数量:', tabButtons.length);
        
        tabButtons.forEach((tab, index) => {
            const originalOnClick = tab.onclick;
            
            // 重写onclick处理器
            tab.onclick = function(e) {
                // 如果正在处理Android共振按钮点击，阻止Tab点击
                if (window.bugFixes?.state.isProcessingAndroidTap) {
                    console.log('[BugFixes] 阻止Tab按钮在Android点击期间被触发', index);
                    e.stopImmediatePropagation();
                    e.preventDefault();
                    return false;
                }
                
                // 键盘动画期间，谨慎处理Tab点击
                if (window.bugFixes?.state.androidKeyboardAnimating) {
                    console.log('[BugFixes] 键盘动画期间Tab点击，延迟执行', index);
                    
                    // 延迟执行，避免与键盘动画冲突
                    setTimeout(() => {
                        if (originalOnClick) {
                            originalOnClick.call(tab, e);
                        }
                    }, 600);
                    
                    e.preventDefault();
                    return false;
                }
                
                // 正常情况：执行原始点击逻辑
                if (originalOnClick) {
                    return originalOnClick.call(tab, e);
                }
            };
        });
        
        console.log('[BugFixes] Tab按钮保护完成');
    }
    
    // ==================== 工具方法 ====================
    
    // 强制重置Android点击状态（在需要时调用）
    resetAndroidTapState() {
        console.log('[BugFixes] 重置Android点击状态');
        this.state.isProcessingAndroidTap = false;
    }
    
    // 获取当前键盘状态（调试用）
    getKeyboardState() {
        return {
            isIOS: this.isIOS,
            isAndroid: this.isAndroid,
            keyboardOpen: this.state.androidKeyboardOpen,
            keyboardAnimating: this.state.androidKeyboardAnimating,
            processingTap: this.state.isProcessingAndroidTap
        };
    }
}
