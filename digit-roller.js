// ==================== 数字滚动效果模块（老虎机效果）====================

class DigitRoller {
    constructor(elementId) {
        this.container = document.getElementById(elementId);
        if (!this.container) {
            console.error('找不到元素:', elementId);
            return;
        }
        this.currentValue = '0.000000';
        this.digits = [];
        this.initialized = false;
        this.isActive = false; // 新增：标记是否激活状态
    }

    // 初始化滚动容器
    init() {
        if (this.initialized) return;
        
        // 保存原始样式，以便恢复
        this.originalDisplay = this.container.style.display;
        this.originalFontFamily = this.container.style.fontFamily;
        this.originalContent = this.container.innerHTML;
        
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
        for (let i = 0; i < 6; i++) {
            const roller = this.createDigitRoller(i);
            this.container.appendChild(roller);
            this.digits.push(roller);
        }
        
        this.initialized = true;
        this.isActive = true;
        console.log('数字滚动效果初始化完成');
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
		// ✅ 修复：如果未初始化，先初始化
		if (!this.initialized) {
			console.log('滚动器未初始化，现在初始化');
			this.init();
		}
		
		// ✅ 修复：如果已初始化但未激活，也允许更新
		if (this.initialized) {
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
		} else {
			console.warn('滚动器初始化失败，无法更新');
		}
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
            this.init();
        }
        this.isActive = true;
    }
    
    // 停用滚动器（恢复到普通文本显示）
    deactivate() {
        this.isActive = false;
    }
    
    // 销毁滚动器，恢复到原始状态
    destroy() {
        if (this.container) {
            // 恢复到原始状态
            this.container.style.display = this.originalDisplay || 'inline';
            this.container.style.fontFamily = this.originalFontFamily || "'Courier New', monospace";
            this.container.innerHTML = this.originalContent || '-- 未开启 --';
        }
        
        this.digits = [];
        this.initialized = false;
        this.isActive = false;
        console.log('数字滚动器已销毁');
    }
}

// 全局实例
let digitRoller = null;

// 初始化函数
function initDigitRoller() {
    if (!digitRoller) {
        digitRoller = new DigitRoller('interestValue');
        console.log('创建数字滚动器实例');
    }
    return digitRoller;
}