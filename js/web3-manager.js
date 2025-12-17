// ==================== Web3管理类 ====================

class Web3Manager {
    constructor() {
        this.web3 = null;
        this.account = null;
        this.chainId = null;
        this.isConnected = false;
        
        // Gas 价格配置
        this.gasConfig = {
            MAX_GWEI: 0.5,      // 最高不超过 0.5 Gwei（你设置的值）
            SAFETY_MARGIN: 1.02  // 5% 安全边际
        };
    }

    // 初始化Web3
    async init() {
        if (typeof window.ethereum !== 'undefined') {
            this.web3 = new Web3(window.ethereum);
            
            // 监听账户变化
            window.ethereum.on('accountsChanged', (accounts) => {
                if (accounts.length === 0) {
                    this.disconnect();
                } else {
                    this.account = accounts[0];
                    this.onAccountChanged(accounts[0]);
                }
            });
            
            // 监听网络变化
            window.ethereum.on('chainChanged', (chainId) => {
                console.log('网络变化，刷新页面');
                window.location.reload();
            });
            
            return true;
        } else {
            console.error('未检测到MetaMask钱包');
            return false;
        }
    }

    // 连接钱包
    async connect() {
        try {
            const accounts = await window.ethereum.request({
                method: 'eth_requestAccounts'
            });
            
            this.account = accounts[0];
            this.chainId = await this.web3.eth.getChainId();
            this.isConnected = true;
            
            console.log('钱包连接成功:', {
                account: this.account,
                chainId: this.chainId
            });
            
            // 检查网络
            if (this.chainId !== CONFIG.CHAIN_ID) {
                console.log('需要切换到BSC网络');
                await this.switchNetwork();
            }
            
            return this.account;
        } catch (error) {
            console.error('连接钱包失败:', error);
            throw error;
        }
    }

    // 切换到BSC网络
    async switchNetwork() {
        try {
            await window.ethereum.request({
                method: 'wallet_switchEthereumChain',
                params: [{ chainId: CONFIG.CHAIN_ID_HEX }]
            });
            console.log('已切换到BSC网络');
        } catch (error) {
            // 如果BSC未添加，则添加网络
            if (error.code === 4902) {
                console.log('BSC网络未添加，正在添加...');
                await window.ethereum.request({
                    method: 'wallet_addEthereumChain',
                    params: [{
                        chainId: CONFIG.CHAIN_ID_HEX,
                        chainName: 'Binance Smart Chain',
                        nativeCurrency: {
                            name: 'BNB',
                            symbol: 'BNB',
                            decimals: 18
                        },
                        rpcUrls: [CONFIG.RPC_URL],
                        blockExplorerUrls: ['https://bscscan.com/']
                    }]
                });
                console.log('BSC网络添加成功');
            } else {
                throw error;
            }
        }
    }

    // 断开连接
    disconnect() {
        this.account = null;
        this.isConnected = false;
        this.onAccountChanged(null);
        console.log('钱包已断开');
    }

    // 账户变化回调（由页面覆盖）
    onAccountChanged(account) {
        console.log('账户变化:', account);
    }

    // 获取合约实例
    getContract(abi, address) {
        if (!this.web3) {
            console.error('Web3未初始化');
            return null;
        }
        return new this.web3.eth.Contract(abi, address);
    }

    // 获取BNB余额
	async getBNBBalance() {
		try {
			const balanceWei = await this.web3.eth.getBalance(this.account);
			const balanceETH = this.web3.utils.fromWei(balanceWei, 'ether');
			
			// 向下舍入到6位小数
			const factor = 1000000;
			const truncated = Math.floor(parseFloat(balanceETH) * factor) / factor;
			
			return truncated.toFixed(6);
		} catch (error) {
			console.error('获取BNB余额失败:', error);
			return '0.000000';
		}
	}

    // 获取代币余额
	async getTokenBalance(tokenAddress, decimals = 18) {
		try {
			const contract = this.getContract(ERC20_ABI, tokenAddress);
			const balanceWei = await contract.methods.balanceOf(this.account).call();
			
			// 转换为可读格式并使用向下舍入
			const divisor = Math.pow(10, decimals);
			const rawBalance = parseFloat(balanceWei) / divisor;
			
			// 向下舍入到2位小数
			const factor = 100; // 10^2
			const truncated = Math.floor(rawBalance * factor) / factor;
			
			return truncated.toFixed(2);
		} catch (error) {
			console.error(`获取${tokenAddress}余额失败:`, error);
			return '0.00';
		}
	}

    // ==================== Gas 价格管理 ====================

    /**
     * 获取优化的 gas price（基于当前 BSC 网络价格，最高限制 MAX_GWEI）
     */
    async getOptimizedGasPrice() {
        try {
            // 1. 获取当前网络实际价格
            const networkGasPriceWei = await this.web3.eth.getGasPrice();
            const networkGasPriceGwei = parseFloat(
                this.web3.utils.fromWei(networkGasPriceWei, 'gwei')
            );
            
            console.log('📊 BSC 网络当前价格:', networkGasPriceGwei.toFixed(3), 'Gwei');
            
            // 2. 应用优化策略
            let optimizedGwei;
            
            if (networkGasPriceGwei > this.gasConfig.MAX_GWEI) {
                // 价格过高，限制到最大值保护用户
                optimizedGwei = this.gasConfig.MAX_GWEI;
                console.log(`⚠️  网络价格过高，限制到: ${optimizedGwei.toFixed(3)} Gwei`);
            } else {
                // 价格在可接受范围，使用实际价格 + 安全边际
                optimizedGwei = networkGasPriceGwei * this.gasConfig.SAFETY_MARGIN;
                console.log(`✅ 使用优化价格: ${optimizedGwei.toFixed(3)} Gwei`);
            }
            
            // 确保精度到小数点后3位
            optimizedGwei = Math.round(optimizedGwei * 1000) / 1000;
            
            const optimizedWei = this.web3.utils.toWei(
                optimizedGwei.toFixed(3), 
                'gwei'
            );
            
            return optimizedWei;
            
        } catch (error) {
            console.error('❌ 获取 gas price 失败:', error);
            
            // 失败时使用保守的低价
            const fallbackGwei = 0.1;
            const fallbackWei = this.web3.utils.toWei(fallbackGwei.toString(), 'gwei');
            
            console.log(`🔄 使用备用价格: ${fallbackGwei} Gwei`);
            return fallbackWei;
        }
    }
    
    /**
     * 获取当前 gas 价格信息（用于显示）
     */
    async getGasPriceInfo() {
        try {
            const gasPriceWei = await this.getOptimizedGasPrice();
            const gasPriceGwei = this.web3.utils.fromWei(gasPriceWei, 'gwei');
            
            // 计算不同类型交易的费用
            const gasLimits = {
                '标准转账': 61000,
                '代币授权': 50000,
                '共振交易': 450000,
                '绑定推荐': 220000
            };
            
            const fees = {};
            for (const [type, limit] of Object.entries(gasLimits)) {
                const totalWei = BigInt(gasPriceWei) * BigInt(limit);
                fees[type] = this.web3.utils.fromWei(totalWei.toString(), 'ether');
            }
            
            return {
                gasPrice: gasPriceGwei,
                gasPriceBNB: this.web3.utils.fromWei(gasPriceWei, 'ether'),
                fees: fees,
                timestamp: Date.now()
            };
        } catch (error) {
            console.error('获取 gas 信息失败:', error);
            return null;
        }
    }

    // ==================== 统一的交易方法 ====================

    /**
     * 统一的交易发送方法（自动优化gas）
     */
    async sendTransaction(contract, methodName, params = [], options = {}) {
        try {
            const method = contract.methods[methodName](...params);
            
            console.log(`📝 调用 ${methodName}:`, params.length > 0 ? params : '无参数');
            
            // 1. 获取优化的gas price（除非options中已指定）
            let gasPrice = options.gasPrice;
            if (!gasPrice) {
                gasPrice = await this.getOptimizedGasPrice();
                console.log(`⛽ Gas价格: ${this.web3.utils.fromWei(gasPrice, 'gwei')} Gwei`);
            }
            
            // 2. 估算gas limit（除非options中已指定）
            let gasLimit = options.gas;
            if (!gasLimit) {
                try {
                    const estimatedGas = await method.estimateGas({
                        from: this.account,
                        gasPrice: gasPrice,
                        ...options
                    });
                    console.log(`📏 估算gas: ${estimatedGas}`);
                    
                    // 增加15%安全边际
                    gasLimit = Math.round(estimatedGas * 1.15);
                } catch (estimateError) {
                    console.warn(`⚠️ 估算gas失败:`, estimateError.message);
                    
                    // 常见方法的默认gas limit
                    const defaultGasLimits = {
                        'approve': 50000,
                        'resonateVID': 490000,
                        'resonateUSDT': 450000,
                        'bindReferral': 220000,
                        'claimInterest': 200000,
                        'interestSwitch': 200000,
                        'transfer': 21000
                    };
                    
                    gasLimit = defaultGasLimits[methodName] || 300000;
                    console.log(`📏 使用默认gas: ${gasLimit}`);
                }
            }
            
            // 3. 计算预计费用
            const totalWei = BigInt(gasPrice) * BigInt(gasLimit);
            const totalBNB = this.web3.utils.fromWei(totalWei.toString(), 'ether');
            
            console.log(`📤 发送交易 ${methodName}:`);
            console.log(`   From: ${this.account.substring(0, 8)}...`);
            console.log(`   Gas价格: ${this.web3.utils.fromWei(gasPrice, 'gwei')} Gwei`);
            console.log(`   Gas限额: ${gasLimit}`);
            console.log(`   预计费用: ${totalBNB} BNB`);
            if (options.value) {
                console.log(`   Value: ${this.web3.utils.fromWei(options.value, 'ether')} BNB`);
            }
            
            // 4. 发送交易
            const tx = await method.send({
                from: this.account,
                gasPrice: gasPrice,
                gas: gasLimit,
                ...options
            });
            
            console.log(`✅ ${methodName} 成功: ${tx.transactionHash.substring(0, 16)}...`);
            return tx;
            
        } catch (error) {
            console.error(`❌ ${methodName} 失败:`, error);
            
            // 友好的错误消息
            let userMessage = '交易失败';
            if (error.code === 4001) {
                userMessage = '用户取消了交易';
            } else if (error.message.includes('insufficient funds')) {
                userMessage = '余额不足';
            } else if (error.message.includes('revert')) {
                userMessage = '合约执行失败';
            } else if (error.message.includes('gas required exceeds allowance')) {
                userMessage = 'Gas不足，请稍后重试';
            }
            
            throw new Error(`${userMessage}`);
        }
    }
    
	async approve(tokenAddress, spenderAddress, amount) {
		if (!this.account) {
			throw new Error('未连接钱包');
		}
		
		try {
			const contract = this.getContract(ERC20_ABI, tokenAddress);
			
			// 1. 先检查当前授权额度
			const currentAllowance = await contract.methods
				.allowance(this.account, spenderAddress)
				.call();
			
			console.log('🔍 当前授权额度检查:', {
				current: currentAllowance,
				required: amount
			});
			
			// 2. 如果当前授权足够本次使用，直接返回
			if (BigInt(currentAllowance) >= BigInt(amount)) {
				console.log('✅ 授权额度充足，无需重复授权');
				return { approved: false, allowance: currentAllowance };
			}
			
			console.log('授权代币:', {
				token: tokenAddress,
				spender: spenderAddress,
				amount: amount
			});
			
			// 3. 执行无限授权（一次性解决问题）
			const maxApproval = '115792089237316195423570985008687907853269984665640564039457584007913129639935';
			
			// 4. 使用统一发送方法
			const tx = await this.sendTransaction(
				contract,
				'approve',
				[spenderAddress, maxApproval]
			);
			
			console.log('✅ 无限授权成功:', tx.transactionHash);
			return { approved: true, tx: tx, allowance: maxApproval };
			
		} catch (error) {
			console.error('授权失败:', error);
			throw error;
		}
	}

    // 检查授权额度
    async getAllowance(tokenAddress, spenderAddress) {
        if (!this.account) return '0';
        
        try {
            const contract = this.getContract(ERC20_ABI, tokenAddress);
            const allowance = await contract.methods
                .allowance(this.account, spenderAddress)
                .call();
            
            return allowance;
        } catch (error) {
            console.error('获取授权额度失败:', error);
            return '0';
        }
    }
    
    /**
     * 简单 BNB 转账（使用统一方法）
     */
    async sendBNB(toAddress, amountBNB) {
        const amountWei = this.web3.utils.toWei(amountBNB, 'ether');
        
        // 创建简单的转账交易对象
        const txObject = {
            from: this.account,
            to: toAddress,
            value: amountWei
        };
        
        // 使用 web3.eth.sendTransaction，它会自动处理gas
        return await this.web3.eth.sendTransaction(txObject);
    }
}

// 创建全局实例
const web3Manager = new Web3Manager();