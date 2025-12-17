// ==================== 数字滚动效果模块（老虎机效果）====================
// 🔧 BUG修复 #17: 修复销毁后无法重启问题

class DigitRoller {
    constructor(elementId) {
        this.elementId = elementId; // 🔧 #17: 保存elementId，用于重新初始化
        this.container = document.getElementById(elementId);
        if (!this.container) {
            console.error('找不到元素:', elementId);
            return;
        }
        this.currentValue = '0.000000';
        this.digits = [];
        this.initialized = false;
        this.isActive = false;
        
        // 🔧 BUG修复 #17: 保存原始状态，用于destroy后恢复
        this.savedState = {
            display: this.container.style.display || 'inline',
            fontFamily: this.container.style.fontFamily || "'Courier New', monospace",
            innerHTML: this.container.innerHTML || '-- 未开启 --'
        };
    }

    // 初始化滚动容器
    init() {
        // 🔧 BUG修复 #17: 重新获取container引用（防止destroy后丢失）
        if (!this.container) {
            this.container = document.getElementById(this.elementId);
            if (!this.container) {
                console.error('🔧 #17: 无法重新获取元素:', this.elementId);
                return false;
            }
        }
        
        if (this.initialized) {
            console.log('数字滚动器已初始化，跳过');
            return true;
        }
        
        // 清空容器
        this.container.innerHTML = '';
        this.container.style.display = 'inline-flex';
        this.container.style.alignItems = 'flex-end';
        this.container.style.fontFamily = "'Courier New', monospace";
        
        // 创建固定的"+"号
        const plus = document.createElement('span');
        plus.textContent = '+';
        plus.style.cssText = `
            font-size: 22px;
            font-weight: 700;
            color: #fbbf24;
            line-height: 28px;
            margin-right: 2px;
        `;
        this.container.appendChild(plus);
        
        // 创建整数部分（固定显示）
        const integerPart = document.createElement('span');
        integerPart.id = 'interestInteger';
        integerPart.textContent = '0';
        integerPart.style.cssText = `
            font-size: 22px;
            font-weight: 700;
            color: #fbbf24;
            line-height: 28px;
        `;
        this.container.appendChild(integerPart);
        
        // 创建小数点
        const dot = document.createElement('span');
        dot.textContent = '.';
        dot.style.cssText = `
            font-size: 22px;
            font-weight: 700;
            color: #fbbf24;
            line-height: 28px;
        `;
        this.container.appendChild(dot);
        
        // 创建6个小数位的滚动容器
        this.digits = []; // 🔧 #17: 重置digits数组
        for (let i = 0; i < 6; i++) {
            const roller = this.createDigitRoller(i);
            this.container.appendChild(roller);
            this.digits.push(roller);
        }
        
        this.initialized = true;
        this.isActive = true;
        console.log('✅ 数字滚动效果初始化完成');
        return true;
    }

    // 创建单个数字滚动器
    createDigitRoller(index) {
        const wrapper = document.createElement('div');
        wrapper.className = 'digit-roller';
        wrapper.style.cssText = `
            display: inline-block;
            height: 28px;
            overflow: hidden;
            vertical-align: bottom;
            width: 14px;
            text-align: center;
        `;
        
        const track = document.createElement('div');
        track.className = 'digit-track';
        track.dataset.index = index;
        track.style.cssText = `
            transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            font-size: 22px;
            font-weight: 700;
            line-height: 28px;
        `;
        
        // 创建0-9的数字
        for (let i = 0; i <= 9; i++) {
            const digit = document.createElement('div');
            digit.textContent = i;
            digit.style.cssText = `
                height: 28px;
                color: ${index >= 4 ? '#fff' : '#fbbf24'};
                text-shadow: ${index >= 4 ? '0 0 10px #fbbf24' : 'none'};
            `;
            track.appendChild(digit);
        }
        
        wrapper.appendChild(track);
        return wrapper;
    }

    // 更新显示值
    update(value) {
        // 🔧 BUG修复 #17: 如果未初始化或已销毁，先初始化
        if (!this.initialized || !this.container) {
            console.log('🔧 #17: 滚动器需要初始化，现在执行...');
            const initSuccess = this.init();
            if (!initSuccess) {
                console.warn('🔧 #17: 初始化失败，无法更新');
                return;
            }
        }
        
        const valueStr = parseFloat(value).toFixed(6);
        const parts = valueStr.split('.');
        const integer = parts[0];
        const decimal = parts[1] || '000000';
        
        // 更新整数部分
        const integerEl = document.getElementById('interestInteger');
        if (integerEl) {
            integerEl.textContent = integer;
        }
        
        // 更新小数部分（滚动效果）
        for (let i = 0; i < 6; i++) {
            const digit = parseInt(decimal[i] || '0');
            this.scrollToDigit(i, digit);
        }
        
        this.currentValue = valueStr;
    }

    // 滚动到指定数字
    scrollToDigit(index, digit) {
        if (!this.digits[index]) return;
        
        const track = this.digits[index].querySelector('.digit-track');
        if (track) {
            const offset = digit * 28; // 每个数字高度28px
            track.style.transform = `translateY(-${offset}px)`;
        }
    }

    // 激活滚动器
    activate() {
        if (!this.initialized) {
            console.log('🔧 #17: 激活时发现未初始化，现在初始化...');
            this.init();
        }
        this.isActive = true;
        console.log('✅ 数字滚动器已激活');
    }
    
    // 停用滚动器（但不销毁）
    deactivate() {
        this.isActive = false;
        console.log('⏸️ 数字滚动器已停用');
    }
    
    // 🔧 BUG修复 #17: 销毁滚动器，但保留重启能力
    destroy() {
        if (!this.container) {
            console.warn('🔧 #17: 容器已不存在，跳过销毁');
            return;
        }
        
        // 恢复到原始状态
        this.container.style.display = this.savedState.display;
        this.container.style.fontFamily = this.savedState.fontFamily;
        this.container.innerHTML = this.savedState.innerHTML;
        
        // ✅ 关键修复：不清空digits数组和container引用，只标记为未初始化
        this.digits = [];
        this.initialized = false;
        this.isActive = false;
        
        // 🔧 #17: 保持 this.container 和 this.elementId 引用，允许重新init
        console.log('🔧 #17: 数字滚动器已销毁（保留重启能力）');
    }
    
    // 🔧 BUG修复 #17: 新增重置方法（完全清理并准备重启）
    reset() {
        this.destroy();
        this.currentValue = '0.000000';
        console.log('🔧 #17: 数字滚动器已重置');
    }
}

// 全局实例
let digitRoller = null;

// 初始化函数
function initDigitRoller() {
    if (!digitRoller) {
        digitRoller = new DigitRoller('interestValue');
        console.log('✅ 创建数字滚动器实例');
    } else if (!digitRoller.initialized) {
        // 🔧 BUG修复 #17: 如果实例存在但未初始化，重新初始化
        console.log('🔧 #17: 实例存在但未初始化，重新初始化...');
        digitRoller.init();
    }
    return digitRoller;
}

// 🔧 BUG修复 #17: 新增全局重启函数（用于钱包重连场景）
function restartDigitRoller() {
    if (digitRoller) {
        console.log('🔧 #17: 重启数字滚动器...');
        digitRoller.reset();
        digitRoller.init();
        return digitRoller;
    } else {
        console.log('🔧 #17: 首次创建数字滚动器...');
        return initDigitRoller();
    }
}
