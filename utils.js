// ==================== 工具函数集合 ====================
// 文件名：utils.js
// 描述：通用工具函数，包括格式化、UI提示、加载动画等
// 🔧 BUG修复 #19: 优化 getTruncatedBalance 使用
// 🔧 BUG修复 #12: Toast消息防重叠优化

// ==================== 地址格式化函数 ====================

/**
 * 格式化地址（显示为：0x1234...5678）
 * @param {string} address - 以太坊地址
 * @returns {string} 格式化后的地址
 */
function formatAddress(address) {
  if (!address) return ''
  return `${address.substring(0, 6)}...${address.substring(36)}`
}

// ==================== 数字格式化函数 ====================

/**
 * 格式化数字（千分位分隔，保留2位小数）
 * @param {number|string} num - 要格式化的数字
 * @returns {string} 格式化后的字符串
 */
function formatNumber(num) {
  if (!num || isNaN(num) || parseFloat(num) <= 0) return '0.00'
  
  // 向下舍入到2位小数
  const factor = 100; // 10^2
  const truncated = Math.floor(parseFloat(num) * factor) / factor;
  
  return truncated.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  })
}

/**
 * 格式化代币数量（根据小数位转换）
 * @param {string|number} value - 原始值（通常是合约返回的wei单位）
 * @param {number} decimals - 代币的小数位数
 * @returns {string} 格式化后的数量（保留2位小数）
 */
function formatToken(value, decimals = 6) {
  if (!value || value === '0' || parseFloat(value) <= 0) return '0.00'
  
  const divisor = Math.pow(10, decimals);
  const raw = parseFloat(value) / divisor;
  
  // 向下舍入到2位小数
  const factor = 100;
  const truncated = Math.floor(raw * factor) / factor;
  
  return truncated.toFixed(2);
}

// ==================== 合约金额转换函数 ====================

/**
 * 输入金额转换为合约参数（前端显示 -> 合约单位）
 * @param {string|number} value - 前端输入的数量
 * @param {number} decimals - 代币的小数位数
 * @returns {string} 合约单位（wei）的字符串
 */
// 修复的toContractAmount函数 - 完全避免科学计数法
function toContractAmount(amount, decimals) {
    if (!amount || isNaN(amount) || amount <= 0) {
        return '0';
    }
    
    // 1. 确保amount是字符串
    let amountStr = amount.toString();
    
    // 2. 如果包含科学计数法，转换为普通数字
    if (amountStr.includes('e') || amountStr.includes('E')) {
        // 使用BigInt安全的转换方式
        const amountNum = parseFloat(amountStr);
        
        // 将小数转换为整数：乘以10^decimals，然后取整
        // 使用字符串操作避免科学计数法
        if (decimals <= 20) {
            // 对于较小的decimals，可以使用数字运算
            const multiplier = Math.pow(10, decimals);
            const weiValue = amountNum * multiplier;
            
            // 使用Math.floor确保是整数
            return Math.floor(weiValue).toString();
        } else {
            // 对于大的decimals，使用字符串操作
            const [integer, fractional = ''] = amountNum.toFixed(decimals).split('.');
            return integer + fractional.padEnd(decimals, '0');
        }
    }
    
    // 3. 常规处理（无科学计数法）
    const [integer, fractional = ''] = amountStr.split('.');
    
    // 如果有小数部分
    if (fractional) {
        // 补零或截断到指定小数位
        const adjustedFractional = fractional.length > decimals 
            ? fractional.substring(0, decimals)  // 截断
            : fractional.padEnd(decimals, '0');  // 补零
        
        // 移除整数部分的前导零
        const cleanInteger = integer.replace(/^0+/, '') || '0';
        
        return cleanInteger + adjustedFractional;
    }
    
    // 4. 只有整数部分
    const cleanInteger = integer.replace(/^0+/, '') || '0';
    return cleanInteger + '0'.repeat(decimals);
}

/**
 * 合约返回值转换为显示金额（合约单位 -> 前端显示）
 * @param {string|number} value - 合约返回的数量（wei单位）
 * @param {number} decimals - 代币的小数位数
 * @returns {string} 格式化后的显示金额
 */
function fromContractAmount(value, decimals = 6) {
  if (!value || value === '0' || parseFloat(value) <= 0) {
    return decimals === 18 ? '0.000000' : '0.00';
  }
  
  const divisor = Math.pow(10, decimals);
  const raw = parseFloat(value) / divisor;
  
  // 向下舍入到指定小数位
  const displayDecimals = decimals === 18 ? 6 : 2;
  const factor = Math.pow(10, displayDecimals);
  const truncated = Math.floor(raw * factor) / factor;
  
  return truncated.toFixed(displayDecimals);
}

// ==================== 安全的格式化函数（确保向下舍入） ====================

/**
 * 安全的余额格式化（向下舍入，确保不显示超过实际余额）
 * @param {number|string} num - 要格式化的数字
 * @param {number} decimals - 小数位数
 * @returns {string} 格式化后的字符串
 */
function formatBalanceSafe(num, decimals = 2) {
  if (!num || isNaN(num) || parseFloat(num) <= 0) {
    return '0.' + '0'.repeat(decimals);
  }
  
  const factor = Math.pow(10, decimals);
  const truncated = Math.floor(parseFloat(num) * factor) / factor;
  
  return truncated.toFixed(decimals);
}

/**
 * 带千分位的数字格式化（向下舍入）
 * @param {number|string} num - 要格式化的数字
 * @param {number} decimals - 小数位数
 * @returns {string} 格式化后的字符串
 */
function formatNumberWithCommas(num, decimals = 0) {
  if (!num || isNaN(num) || parseFloat(num) <= 0) {
    return '0';
  }
  
  let truncated = Math.floor(parseFloat(num));
  
  if (decimals > 0) {
    const factor = Math.pow(10, decimals);
    truncated = Math.floor(parseFloat(num) * factor) / factor;
    return truncated.toFixed(decimals).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }
  
  return truncated.toLocaleString();
}

/**
 * 🔧 BUG修复 #19: getTruncatedBalance 函数（供index.html统一使用）
 * 获取向下舍入后的余额（避免代码重复）
 * @param {number|string} num - 原始数字
 * @param {number} decimals - 小数位数
 * @returns {number} 向下舍入后的数字
 */
function getTruncatedBalance(num, decimals = 2) {
  if (!num || isNaN(num) || parseFloat(num) <= 0) {
    return 0;
  }
  
  const factor = Math.pow(10, decimals);
  return Math.floor(parseFloat(num) * factor) / factor;
}

// ==================== 时间格式化函数 ====================

/**
 * 格式化倒计时（将时间戳转换为可读的倒计时）
 * @param {number} timestamp - Unix时间戳（秒）
 * @returns {string} 格式化后的倒计时字符串
 */
function formatCountdown(timestamp) {
  const now = Math.floor(Date.now() / 1000)
  const remaining = timestamp - now
  
  if (remaining <= 0) return "可执行"
  
  const days = Math.floor(remaining / 86400)
  const hours = Math.floor((remaining % 86400) / 3600)
  const minutes = Math.floor((remaining % 3600) / 60)
  const seconds = remaining % 60
  
  return `${days}天${hours}时${minutes}分${seconds}秒`
}

// ==================== 加载动画函数 ====================

/**
 * 显示全局加载动画
 * @param {string} message - 加载提示文字
 */
function showLoading(message = '处理中...') {
  // 如果已有加载动画，先移除
  hideLoading()
  
  const loadingHtml = `
    <div id="loading-overlay" style="
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.8);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 99999;
    ">
      <div style="
        background: rgba(26, 11, 61, 0.95);
        padding: 30px 40px;
        border-radius: 12px;
        color: white;
        text-align: center;
      ">
        <div style="font-size: 16px; margin-bottom: 10px;">${message}</div>
        <div style="font-size: 12px; color: #fbbf24;">请在钱包中确认交易</div>
      </div>
    </div>
  `
  document.body.insertAdjacentHTML('beforeend', loadingHtml)
}

/**
 * 隐藏全局加载动画
 */
function hideLoading() {
  const loading = document.getElementById('loading-overlay')
  if (loading) loading.remove()
}

// ==================== Toast提示函数 ====================

/**
 * 显示成功提示（绿色Toast）
 * @param {string} message - 提示消息
 */
function showSuccess(message) {
  showToast(message, 'success')
}

/**
 * 显示错误提示（红色Toast）
 * @param {string} message - 错误消息
 */
function showError(message) {
  showToast(message, 'error')
}

/**
 * 显示信息提示（蓝色Toast）
 * @param {string} message - 信息消息
 */
function showInfo(message) {
  showToast(message, 'info')
}

// 🔧 BUG修复 #12: Toast消息防重叠 - 添加队列管理
let toastQueue = [];
let isShowingToast = false;

/**
 * Toast队列处理函数
 */
function processToastQueue() {
  if (isShowingToast || toastQueue.length === 0) return;
  
  const { message, type } = toastQueue.shift();
  isShowingToast = true;
  
  _showToastInternal(message, type, () => {
    isShowingToast = false;
    // 处理下一个Toast（如果有）
    setTimeout(processToastQueue, 300);
  });
}

/**
 * 显示Toast提示的核心函数
 * @param {string} message - 显示的消息
 * @param {string} type - 消息类型：'success' | 'error' | 'info'
 */
function showToast(message, type = 'info') {
  // 🔧 BUG修复 #12: 检查是否有相同消息已在队列中
  const isDuplicate = toastQueue.some(item => 
    item.message === message && item.type === type
  );
  
  if (isDuplicate) {
    console.log('🔧 防止重复Toast:', message);
    return;
  }
  
  // 🔧 BUG修复 #12: 限制队列长度，防止堆积
  if (toastQueue.length >= 3) {
    console.warn('Toast队列已满，丢弃旧消息');
    toastQueue.shift(); // 移除最旧的消息
  }
  
  toastQueue.push({ message, type });
  processToastQueue();
}

/**
 * 内部Toast显示函数（实际渲染逻辑）
 * @param {string} message - 显示的消息
 * @param {string} type - 消息类型
 * @param {function} onComplete - 完成回调
 */
function _showToastInternal(message, type, onComplete) {
  // 颜色映射
  const colors = {
    success: '#10b981', // 绿色
    error: '#ef4444',   // 红色
    info: '#3b82f6'     // 蓝色
  }
  
  // 图标映射
  const icons = {
    success: '✅',
    error: '❌',
    info: 'ℹ️'
  }
  
  const toastHtml = `
    <div class="toast-message" style="
      position: fixed;
      top: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: ${colors[type]};
      color: white;
      padding: 15px 30px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 600;
      z-index: 100000;
      animation: slideDown 0.3s ease;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
      backdrop-filter: blur(10px);
      display: flex;
      align-items: center;
      gap: 8px;
      max-width: 80%;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    ">
      <span style="font-size: 16px;">${icons[type]}</span>
      <span>${message}</span>
    </div>
  `
  
  // 🔧 BUG修复 #12: 移除现有Toast（保证同时只显示一个）
  const existingToasts = document.querySelectorAll('.toast-message')
  existingToasts.forEach(toast => toast.remove())
  
  // 添加新的Toast
  document.body.insertAdjacentHTML('beforeend', toastHtml)
  
  // 3秒后自动移除
  const autoRemoveTimer = setTimeout(() => {
    const toast = document.querySelector('.toast-message')
    if (toast) {
      toast.style.animation = 'slideUp 0.3s ease'
      setTimeout(() => {
        toast.remove()
        if (onComplete) onComplete()
      }, 300)
    }
  }, 3000)
  
  // 点击立即关闭
  setTimeout(() => {
    const toast = document.querySelector('.toast-message')
    if (toast) {
      toast.addEventListener('click', function() {
        clearTimeout(autoRemoveTimer)
        this.style.animation = 'slideUp 0.3s ease'
        setTimeout(() => {
          this.remove()
          if (onComplete) onComplete()
        }, 300)
      })
    }
  }, 100)
}

// ==================== CSS动画样式 ====================

// 添加Toast动画样式（只添加一次）
if (!document.querySelector('#toast-animations')) {
  const style = document.createElement('style')
  style.id = 'toast-animations'
  style.textContent = `
    @keyframes slideDown {
      from { 
        transform: translate(-50%, -100%); 
        opacity: 0; 
      }
      to { 
        transform: translate(-50%, 0); 
        opacity: 1; 
      }
    }
    @keyframes slideUp {
      from { 
        transform: translate(-50%, 0); 
        opacity: 1; 
      }
      to { 
        transform: translate(-50%, -100%); 
        opacity: 0; 
      }
    }
  `
  document.head.appendChild(style)
}

// ==================== 简单提示函数（兼容模式） ====================

/**
 * 简单的alert信息提示（兼容旧代码）
 * @param {string} message - 提示消息
 */
function alertInfo(message) {
  console.info('提示:', message)
  alert(message)
}

/**
 * 简单的alert错误提示（兼容旧代码）
 * @param {string} message - 错误消息
 */
function alertError(message) {
  console.error('错误:', message)
  alert('❌ ' + message)
}

/**
 * 简单的alert成功提示（兼容旧代码）
 * @param {string} message - 成功消息
 */
function alertSuccess(message) {
  console.log('成功:', message)
  alert('✅ ' + message)
}
