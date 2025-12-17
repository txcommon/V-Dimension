// ==================== 合约配置文件 ====================
// 🔧 BUG修复 #21: 添加错误码常量，便于维护和国际化

const CONFIG = {
  // BSC主网RPC
  RPC_URL: 'https://bsc-dataseed.binance.org/',
  
  // 链ID
  CHAIN_ID: 56,
  CHAIN_ID_HEX: '0x38',
  
  // 合约地址
  CONTRACTS: {
    TokenBank: '0x22f457Ed9c3Ed8BB84d4796d601C23E69F715970',
    Temple: '0x8dbACDE486A129C2671AF4d37681372DeF06618D',
    VID: '0x65b8F22EF3F2fF7072744Fc4dC919E8e6dbE5E6A',
    USDT: '0x55d398326f99059fF775485246999027B3197955',
    VDS: '0xA92BD5D04121a6D02CC687129963dB9C2665cd05'
  },
  
  // 代币精度
  DECIMALS: {
    Vollar: 6,
    VID: 6,
    USDT: 18,
    VDS: 8,
    BNB: 18
  }
}

// 🔧 BUG修复 #21: 合约错误码映射（便于国际化和维护）
const CONTRACT_ERRORS = {
  // 通用错误
  'InsufficientBalance': 'Vollar余额不足',
  'InsufficientAllowance': '授权额度不足',
  'InsufficientContract': '合约余额不足',
  'ZeroAddress': '零地址错误',
  'ZeroAmount': '金额不能为零',
  'ValueTooLow': '金额过小',
  'ValueTooHigh': '金额过大',
  'InvalidTimestamp': '时间戳无效',
  'Expired': '已过期',
  
  // 共振相关错误
  'ExceedsTotalResonance': '超过共振总量限制（1000亿封顶）',
  'NoReferralProvided': '请先绑定推荐人',
  'NotStarted': '功能尚未启动',
  'CommunityExchangeNotStarted': '社区兑换尚未开放（2026-01-01开启）',
  'CommunityAmountInsu': '铸造金额不足以创建社区',
  
  // 生息相关错误
  'InterestEarningActivated': '持币生息已激活，无需重复开启',
  'NoActiveInterest': '尚未激活持币生息',
  'NoBNB': 'BNB余额不足支付手续费',
  
  // 推荐关系错误
  'AlreadyHasReferrer': '已有推荐人，无法更改',
  'InvalidReferrer': '推荐人无效',
  'SelfReferral': '不能推荐自己',
  'ContractAsReferrer': '不能使用合约地址作为推荐人',
  
  // 社区相关错误
  'CommunityOnly': '仅限社区成员',
  'NotEnoughMembers': '社区人数不足',
  'OnlyTop1000': '仅限前1000名社区',
  'QuotaExhausted': '配额已用尽',
  'InsufficientCirculatingSupply': '流通总量不足',
  
  // 授权相关错误
  'ApprovalAmountTooHigh': '授权金额超过当前限额',
  'ERC20InsufficientAllowance': '授权额度不足',
  'ERC20InsufficientBalance': '代币余额不足',
  'ERC20InvalidApprover': '授权者地址无效',
  'ERC20InvalidSpender': '授权对象地址无效',
  
  // 安全相关错误
  'NotEOA': '仅限外部账户（EOA）',
  'IsContract': '不能使用合约地址',
  'Reentrancy': '重入攻击检测',
  'Unauthorized': '未授权操作'
}

// 🔧 BUG修复 #21: 用户友好的错误消息映射（通用错误）
const USER_FRIENDLY_ERRORS = {
  // MetaMask 错误
  'User denied transaction signature': '用户取消了交易',
  'user rejected transaction': '用户取消了交易',
  'insufficient funds': '余额不足（包括Gas费）',
  'gas required exceeds allowance': 'Gas不足，请稍后重试',
  'nonce too low': '交易序号错误，请刷新页面',
  'replacement transaction underpriced': '交易费用过低，请提高Gas价格',
  'already known': '交易已提交，请勿重复操作',
  
  // 网络错误
  'Failed to fetch': '网络连接失败，请检查网络',
  'Network Error': '网络错误，请重试',
  'timeout': '请求超时，请重试',
  
  // RPC 错误
  'Internal JSON-RPC error': '节点错误，请稍后重试',
  'execution reverted': '合约执行失败'
}

// 🔧 BUG修复 #21: 错误解析函数（统一处理）
function parseContractError(error) {
  if (!error) return '未知错误';
  
  const errorMessage = error.message || error.toString();
  
  // 1. 检查用户友好错误
  for (const [key, message] of Object.entries(USER_FRIENDLY_ERRORS)) {
    if (errorMessage.includes(key)) {
      return message;
    }
  }
  
  // 2. 检查合约自定义错误
  for (const [key, message] of Object.entries(CONTRACT_ERRORS)) {
    if (errorMessage.includes(key)) {
      return message;
    }
  }
  
  // 3. 提取 revert 信息
  const revertMatch = errorMessage.match(/revert (.+?)["']?\s*$/);
  if (revertMatch) {
    const revertReason = revertMatch[1];
    return CONTRACT_ERRORS[revertReason] || `合约错误: ${revertReason}`;
  }
  
  // 4. 返回原始错误（开发环境有用）
  console.error('未处理的错误:', errorMessage);
  return '交易失败，请重试';
}

// ERC20 基础ABI
const ERC20_ABI = [
  {
    "constant": true,
    "inputs": [{"name": "_owner", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "balance", "type": "uint256"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "_spender", "type": "address"},
      {"name": "_value", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {"name": "_owner", "type": "address"},
      {"name": "_spender", "type": "address"}
    ],
    "name": "allowance",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  }
]

// TokenBank ABI（完整版）
const TOKENBANK_ABI = [
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "_token",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "_token2",
				"type": "address"
			}
		],
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"inputs": [],
		"name": "AlreadyHasReferrer",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "maxApprovalAmount",
				"type": "uint256"
			}
		],
		"name": "ApprovalAmountTooHigh",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ArrayLengthMismatch",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "CommunityAmountInsu",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "CommunityExchangeNotStarted",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "CommunityOnly",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ContractAsReferrer",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "spender",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "allowance",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "needed",
				"type": "uint256"
			}
		],
		"name": "ERC20InsufficientAllowance",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "sender",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "balance",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "needed",
				"type": "uint256"
			}
		],
		"name": "ERC20InsufficientBalance",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "approver",
				"type": "address"
			}
		],
		"name": "ERC20InvalidApprover",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "receiver",
				"type": "address"
			}
		],
		"name": "ERC20InvalidReceiver",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "sender",
				"type": "address"
			}
		],
		"name": "ERC20InvalidSender",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "spender",
				"type": "address"
			}
		],
		"name": "ERC20InvalidSpender",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "EmptyArray",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ExceedsTotalResonance",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "Expired",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InsufficientAllowance",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InsufficientBalance",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InsufficientCirculatingSupply",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InsufficientContract",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InterestEarningActivated",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InvalidCommunity",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InvalidCommunityIds",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InvalidCondition",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InvalidData",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InvalidRecommender",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InvalidReferrer",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InvalidSerialIndex",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InvalidSerialLayer",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "InvalidTimestamp",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "IsContract",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "MaxDirectReferralsReached",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "NoActiveInterest",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "NoBNB",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "NoReferralProvided",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "NotEOA",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "Members",
				"type": "uint256"
			}
		],
		"name": "NotEnoughMembers",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "NotStarted",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "OnlySelf",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "OnlyTop1000",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "QuotaExhausted",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "Reentrancy",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "token",
				"type": "address"
			}
		],
		"name": "SafeERC20FailedOperation",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "SelfReferral",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "Unauthorized",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ValueOutOfRange",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ValueTooHigh",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ValueTooLow",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ZeroAddres",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ZeroAddress",
		"type": "error"
	},
	{
		"inputs": [],
		"name": "ZeroAmount",
		"type": "error"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "owner",
				"type": "address"
			},
			{
				"indexed": true,
				"internalType": "address",
				"name": "spender",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "value",
				"type": "uint256"
			}
		],
		"name": "Approval",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "member",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "totalMembers",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "mintingFee",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "CommunityJoined",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "community",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "fromLayer",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "toLayer",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "performance",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "CommunityPromoted",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "community",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "layer",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "performance",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "CommunityRanked",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "usdtAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "vidAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "ExchangeUSDTtoVID",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint8",
				"name": "exchangeType",
				"type": "uint8"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "vollarAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "receivedAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "ExchangeVollar",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "costAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "InterestActivated",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "interestAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "bnbFee",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "InterestClaimed",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "community",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "layer",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "rewardAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "LayerRewardDistributed",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": true,
				"internalType": "address",
				"name": "referrer",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "ReferralBound",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "from",
				"type": "address"
			},
			{
				"indexed": true,
				"internalType": "address",
				"name": "to",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			}
		],
		"name": "ReferralReward",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "resonateAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "vollarAmount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "timestamp",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "bool",
				"name": "isVID",
				"type": "bool"
			}
		],
		"name": "ResonateDeposit",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "from",
				"type": "address"
			},
			{
				"indexed": true,
				"internalType": "address",
				"name": "to",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "value",
				"type": "uint256"
			}
		],
		"name": "Transfer",
		"type": "event"
	},
	{
		"inputs": [],
		"name": "AmountSecond",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "AmounttobeCollected",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "Token",
		"outputs": [
			{
				"internalType": "contract IERC20",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "Token2",
		"outputs": [
			{
				"internalType": "contract IERC20",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "owner",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "spender",
				"type": "address"
			}
		],
		"name": "allowance",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "amICommunityMember",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "spender",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "approve",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "account",
				"type": "address"
			}
		],
		"name": "balanceOf",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "ref",
				"type": "address"
			}
		],
		"name": "bindReferral",
		"outputs": [],
		"stateMutability": "payable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "ref",
				"type": "address"
			}
		],
		"name": "checkRefValid",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "claimInterest",
		"outputs": [],
		"stateMutability": "payable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "communityUSDTForVID",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "communityVollarForBNB",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "communityVollarForUSDT",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "communityVollarForVID",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "decimals",
		"outputs": [
			{
				"internalType": "uint8",
				"name": "",
				"type": "uint8"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getAllCommunityPerformance",
		"outputs": [
			{
				"internalType": "uint256[]",
				"name": "",
				"type": "uint256[]"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint8",
				"name": "dataType",
				"type": "uint8"
			},
			{
				"internalType": "uint256",
				"name": "startIndex",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "endIndex",
				"type": "uint256"
			}
		],
		"name": "getCommunityData",
		"outputs": [
			{
				"internalType": "uint256[]",
				"name": "",
				"type": "uint256[]"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getGlobalRankingInfo",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "totalGlobalCommunities",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "totalRankedCommunities",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "communityMintingFee",
				"type": "uint256"
			},
			{
				"internalType": "uint256[6]",
				"name": "layerSizesArray",
				"type": "uint256[6]"
			},
			{
				"internalType": "uint256[6]",
				"name": "layerCapacitiesArray",
				"type": "uint256[6]"
			},
			{
				"internalType": "uint256[6]",
				"name": "thresholds",
				"type": "uint256[6]"
			},
			{
				"internalType": "uint256[6]",
				"name": "topPerformances",
				"type": "uint256[6]"
			},
			{
				"internalType": "uint256[6]",
				"name": "minPerformances",
				"type": "uint256[6]"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getGlobalStats",
		"outputs": [
			{
				"components": [
					{
						"internalType": "uint256",
						"name": "startTimer",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "userCount",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allTotalAmount",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allVIDMintedVollar",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allUSDTMintedVollar",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allCompoundInterest",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allTotalVIDResonance",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allTotalUSDTResonance",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allVIDRewardAmount",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "totalUSDTReceived",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "totalRedeemedVID",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allBNBWithdrawn",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allUSDTWithdrawn",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allVIDWithdrawn",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "allTotalAmountS",
						"type": "uint256"
					}
				],
				"internalType": "struct UserDataManager.GlobalStats",
				"name": "",
				"type": "tuple"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "layer",
				"type": "uint256"
			}
		],
		"name": "getLayerPerformanceRanking",
		"outputs": [
			{
				"internalType": "uint256[]",
				"name": "",
				"type": "uint256[]"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getMemberCount",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getMyReferrer",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getPayBNBFee",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getRateStats",
		"outputs": [
			{
				"components": [
					{
						"internalType": "uint256",
						"name": "mintRate",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "tokenTax",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "interestRate",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "vidQuota",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "usdtAllocation",
						"type": "uint256"
					}
				],
				"internalType": "struct UserDataManager.RateStats",
				"name": "",
				"type": "tuple"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getUserInfo",
		"outputs": [
			{
				"components": [
					{
						"internalType": "uint256",
						"name": "totalMintedVollar",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "vollarFromVID",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "vollarFromUSDT",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "personalHoldingInterest",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "communitySubsidyMint",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "vidResonanceAmount",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "usdtResonanceAmount",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "vidRewardsFromRef",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "vidRewardsFromCommunity",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "usdtForVIDAmount",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "getTotalVID",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "exchangedBNB",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "exchangedUSDT",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "exchangedVID",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "exchangedBurnedVollar",
						"type": "uint256"
					}
				],
				"internalType": "struct UserDataManager.UserInfo",
				"name": "",
				"type": "tuple"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getUserRankingInfo",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "globalRank",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "layer",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "performance",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "rankInLayer",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "layerTotal",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "exchangeRate",
				"type": "uint256"
			},
			{
				"internalType": "bool",
				"name": "isRanked",
				"type": "bool"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getUserRefInterestStatus",
		"outputs": [
			{
				"components": [
					{
						"internalType": "address",
						"name": "myReferrer",
						"type": "address"
					},
					{
						"internalType": "address",
						"name": "myReferrerCommunity",
						"type": "address"
					},
					{
						"internalType": "uint256",
						"name": "totalFirstLevelMembers",
						"type": "uint256"
					},
					{
						"internalType": "uint256",
						"name": "activeInterestCount",
						"type": "uint256"
					},
					{
						"components": [
							{
								"internalType": "address",
								"name": "memberAddress",
								"type": "address"
							},
							{
								"internalType": "bool",
								"name": "interestStatus",
								"type": "bool"
							}
						],
						"internalType": "struct ReferralManager.MemberStatus[]",
						"name": "memberStatuses",
						"type": "tuple[]"
					}
				],
				"internalType": "struct ReferralManager.UserRefInterestStatus",
				"name": "status",
				"type": "tuple"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getUserTimestamps",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "lastInterestTime",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "lastBnbTime",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "lastUsdtTime",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "lastVidTime",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "lastUSwapVTime",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "interestSwitch",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "myInterestPermission",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "name",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "owner",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "resonateUSDT",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "resonateVID",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "symbol",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "totalSupply",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "to",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "transfer",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "from",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "to",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "value",
				"type": "uint256"
			}
		],
		"name": "transferFrom",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"stateMutability": "payable",
		"type": "receive"
	}
]

// Temple ABI（完整版）
const TEMPLE_ABI = [
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "_stakingToken",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "_rewardToken",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "_purseOfFortuna",
				"type": "address"
			}
		],
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "previousOwner",
				"type": "address"
			},
			{
				"indexed": true,
				"internalType": "address",
				"name": "newOwner",
				"type": "address"
			}
		],
		"name": "OwnershipTransferred",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "address",
				"name": "purseAddress",
				"type": "address"
			}
		],
		"name": "PurseConnected",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "RewardClaimed",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "newAccRewardPerShare",
				"type": "uint256"
			}
		],
		"name": "RewardsDistributed",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "Staked",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "UnstakeCancelled",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "unlockTime",
				"type": "uint256"
			}
		],
		"name": "UnstakeRequested",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"internalType": "address",
				"name": "user",
				"type": "address"
			},
			{
				"indexed": false,
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "Withdrawn",
		"type": "event"
	},
	{
		"inputs": [],
		"name": "DISTRIBUTION_INTERVAL",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "MIN_STAKE_AMOUNT",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "MIN_STAKE_FOR_DIVIDENDS",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "UNSTAKE_LOCK_PERIOD",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "account",
				"type": "address"
			}
		],
		"name": "balanceOf",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "cancelUnstake",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "claimReward",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "decimals",
		"outputs": [
			{
				"internalType": "uint8",
				"name": "",
				"type": "uint8"
			}
		],
		"stateMutability": "pure",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "distributeRewards",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getTempleInfo",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "totalStaked",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "totalDistributed",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "purseBal",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "contractBal",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "accRewardPerShare",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "estimatedNextDividend",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "nextDistributionTime",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getUserInfo",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "stakedAmount",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "totalRewardDistributed",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "estimateVIDReward",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "pendingRewardAmount",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "pendingUnstakeAmount",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "unlockTime",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "name",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "pure",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "owner",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "purseOfFortuna",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "requestUnstake",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "rewardToken",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "stake",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "stakingToken",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "symbol",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "pure",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "to",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "transfer",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "withdraw",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	}

]
