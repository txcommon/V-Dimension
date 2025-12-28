// ==================== 多语言管理器 ====================
// 支持语言: zh-CN, en, vi, ja, ko

class I18nManager {
    constructor() {
        this.currentLang = 'zh-CN';
        this.translations = {};
        this.supportedLangs = {
            'zh-CN': { name: '简体中文', flag: '🇨🇳' },
            'en': { name: 'English', flag: '🇺🇸' },
            'vi': { name: 'Tiếng Việt', flag: '🇻🇳' },
            'ja': { name: '日本語', flag: '🇯🇵' },
            'ko': { name: '한국어', flag: '🇰🇷' }
        };
        this.loaded = false;
    }

    // 初始化
    async init() {
        // 从本地存储获取语言设置
        const savedLang = localStorage.getItem('lehua_lang');
        if (savedLang && this.supportedLangs[savedLang]) {
            this.currentLang = savedLang;
        } else {
            // 检测浏览器语言
            this.currentLang = this.detectBrowserLang();
        }

        // 加载语言文件
        await this.loadLanguage(this.currentLang);
        this.loaded = true;
        
        // 更新页面文本
        this.updatePageTexts();
        
        console.log('🌐 语言初始化完成:', this.currentLang);
        return this.currentLang;
    }

    // 检测浏览器语言
    detectBrowserLang() {
        const browserLang = navigator.language || navigator.userLanguage;
        
        if (browserLang.startsWith('zh')) return 'zh-CN';
        if (browserLang.startsWith('en')) return 'en';
        if (browserLang.startsWith('vi')) return 'vi';
        if (browserLang.startsWith('ja')) return 'ja';
        if (browserLang.startsWith('ko')) return 'ko';
        
        return 'zh-CN'; // 默认中文
    }

    // 加载语言文件
    async loadLanguage(lang) {
        if (this.translations[lang]) {
            this.currentLang = lang;
            return;
        }

        try {
            const response = await fetch(`i18n/${lang}.json`);
            if (!response.ok) throw new Error('语言文件加载失败');
            
            this.translations[lang] = await response.json();
            this.currentLang = lang;
            localStorage.setItem('lehua_lang', lang);
            
            console.log('📚 语言文件已加载:', lang);
        } catch (error) {
            console.error('语言文件加载错误:', error);
            
            // 尝试加载默认语言
            if (lang !== 'zh-CN') {
                await this.loadLanguage('zh-CN');
            }
        }
    }

    // 切换语言
    async switchLanguage(lang) {
        if (!this.supportedLangs[lang]) {
            console.warn('不支持的语言:', lang);
            return false;
        }

        await this.loadLanguage(lang);
        this.updatePageTexts();
        
        // 触发语言切换事件
        window.dispatchEvent(new CustomEvent('langChanged', { 
            detail: { lang: lang } 
        }));
        
        return true;
    }

    // 获取翻译文本
    t(key, params = {}) {
        const keys = key.split('.');
        let value = this.translations[this.currentLang];
        
        for (const k of keys) {
            if (value && value[k] !== undefined) {
                value = value[k];
            } else {
                // 尝试从默认语言获取
                value = this.getFromDefault(keys);
                break;
            }
        }

        if (typeof value !== 'string') {
            console.warn('翻译缺失:', key);
            return key;
        }

        // 替换参数
        return value.replace(/\{(\w+)\}/g, (match, param) => {
            return params[param] !== undefined ? params[param] : match;
        });
    }

    // 从默认语言获取
    getFromDefault(keys) {
        let value = this.translations['zh-CN'];
        if (!value) return keys.join('.');
        
        for (const k of keys) {
            if (value && value[k] !== undefined) {
                value = value[k];
            } else {
                return keys.join('.');
            }
        }
        return value;
    }

    // 更新页面所有带data-i18n属性的元素
    updatePageTexts() {
        // 更新文本内容
        document.querySelectorAll('[data-i18n]').forEach(el => {
            const key = el.getAttribute('data-i18n');
            el.textContent = this.t(key);
        });

        // 更新placeholder
        document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
            const key = el.getAttribute('data-i18n-placeholder');
            el.placeholder = this.t(key);
        });

        // 更新title属性
        document.querySelectorAll('[data-i18n-title]').forEach(el => {
            const key = el.getAttribute('data-i18n-title');
            el.title = this.t(key);
        });

        // 更新HTML lang属性
        document.documentElement.lang = this.currentLang;
    }

    // 获取当前语言
    getCurrentLang() {
        return this.currentLang;
    }

    // 获取支持的语言列表
    getSupportedLangs() {
        return this.supportedLangs;
    }

    // 格式化数字（根据语言区域）
    formatNumber(num, decimals = 2) {
        if (num === null || num === undefined || isNaN(num)) return '0';
        
        const localeMap = {
            'zh-CN': 'zh-CN',
            'en': 'en-US',
            'vi': 'vi-VN',
            'ja': 'ja-JP',
            'ko': 'ko-KR'
        };
        
        return new Intl.NumberFormat(localeMap[this.currentLang] || 'en-US', {
            minimumFractionDigits: decimals,
            maximumFractionDigits: decimals
        }).format(num);
    }

    // 格式化日期
    formatDate(timestamp) {
        if (!timestamp) return '--';
        
        const date = new Date(timestamp * 1000);
        const localeMap = {
            'zh-CN': 'zh-CN',
            'en': 'en-US',
            'vi': 'vi-VN',
            'ja': 'ja-JP',
            'ko': 'ko-KR'
        };
        
        return new Intl.DateTimeFormat(localeMap[this.currentLang] || 'en-US', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }).format(date);
    }

    // 格式化倒计时
    formatCountdown(seconds) {
        if (seconds <= 0) return this.t('common.available');
        
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        
        const d = this.t('common.days');
        const h = this.t('common.hours');
        const m = this.t('common.minutes');
        const s = this.t('common.seconds');
        
        if (days > 0) {
            return `${days}${d}${hours}${h}${minutes}${m}${secs}${s}`;
        } else if (hours > 0) {
            return `${hours}${h}${minutes}${m}${secs}${s}`;
        } else if (minutes > 0) {
            return `${minutes}${m}${secs}${s}`;
        } else {
            return `${secs}${s}`;
        }
    }
}

// 创建全局实例
const i18n = new I18nManager();

// 便捷函数
function t(key, params) {
    return i18n.t(key, params);
}
