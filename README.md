# 🌱 Carbon-Neutral NFT Marketplace

A sustainable NFT marketplace built on Stacks blockchain that enforces carbon offsetting for every transaction, ensuring environmentally responsible digital art trading.

## 🌍 Overview

This marketplace revolutionizes NFT trading by automatically requiring carbon offset purchases for minting, buying, and transferring NFTs. Every transaction contributes to environmental sustainability through mandatory carbon credit purchases.

## ✨ Features

- 🎨 **NFT Minting**: Create digital art with automatic carbon footprint calculation
- 🛒 **Sustainable Trading**: Buy/sell NFTs with enforced carbon offsetting
- 💚 **Carbon Credits**: Automatic carbon credit purchase system
- 📊 **Transparency**: Track total carbon offset contributions
- 🔒 **Secure Transfers**: Safe NFT ownership transfers with offset requirements
- 💰 **Fair Marketplace**: Built-in marketplace fees and seller protection

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet with STX tokens
- Basic understanding of Clarity smart contracts

### Installation

```bash
clarinet new carbon-nft-marketplace
cd carbon-nft-marketplace
```

Copy the contract code into `contracts/Carbon-Neutral.clar`

### Testing

```bash
clarinet test
```

### Deployment

```bash
clarinet deploy
```

## 📖 Usage

### Minting an NFT

```clarity
(contract-call? .Carbon-Neutral mint-nft 
  "My Artwork" 
  "Beautiful digital art piece" 
  "https://example.com/image.jpg" 
  u100)
```

### Listing NFT for Sale

```clarity
(contract-call? .Carbon-Neutral list-nft u1 u1000000)
```

### Buying an NFT

```clarity
(contract-call? .Carbon-Neutral buy-nft u1)
```

### Purchasing Carbon Credits

```clarity
(contract-call? .Carbon-Neutral purchase-carbon-credits tx-sender u50)
```

## 🔧 Contract Functions

### Public Functions

- `mint-nft` - Create new NFT with carbon offset
- `list-nft` - List NFT for sale
- `buy-nft` - Purchase listed NFT
- `transfer-nft` - Transfer NFT ownership
- `purchase-carbon-credits` - Buy carbon offset credits
- `cancel-listing` - Remove NFT from marketplace

### Read-Only Functions

- `get-nft` - Retrieve NFT details
- `get-listing` - Get marketplace listing info
- `get-user-carbon-credits` - Check user's carbon credits
- `get-total-carbon-offset` - View total offset contributions
- `calculate-carbon-offset` - Calculate required offset amount

## 🌿 Carbon Offset System

- **Rate**: 10 credits per unit of carbon footprint (configurable)
- **Cost**: 1 STX per carbon credit
- **Automatic**: All transactions require offset purchase
- **Transparent**: Total offset tracking for community impact

## 🛡️ Security Features

- Owner-only administrative functions
- Authorization checks for all operations
- Safe transfer mechanisms
- Input validation and error handling

## 📊 Marketplace Economics

- **Marketplace Fee**: 2.5% (250 basis points)
- **Carbon Credits**: 1 STX per credit
- **Automatic Offsetting**: Built into every transaction
- **Transparent Pricing**: All costs calculated on-chain

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request

## 📄 License

MIT License - Build sustainable NFT solutions freely!

## 🌟 Impact

Every transaction on this marketplace contributes to carbon neutrality, making digital art trading environmentally responsible. Join the movement toward sustainable blockchain technology!

---

*Built with 💚 for a sustainable future*
```

**Git Commit Message:**
```
feat: implement carbon-neutral NFT marketplace with enforced offsetting
```

**GitHub Pull Request Title:**
```
🌱 Add Carbon-Neutral NFT Marketplace MVP with Mandatory Offset System
```

**GitHub Pull Request Description:**
```
## 🌍 Carbon-Neutral NFT Marketplace MVP

This PR introduces a complete MVP for a sustainable NFT marketplace that enforces carbon offsetting on every transaction.

### ✨ Features Added
- NFT minting with automatic carbon footprint calculation
- Marketplace listing and buying functionality  
- Mandatory carbon credit purchase system
- Secure NFT transfers with offset requirements
- Administrative controls for offset rates and fees
- Comprehensive read-only functions for transparency

### 🔧 Technical Implementation
- 150+ lines of clean Clarity code
- Robust error handling and validation
- Owner authorization and security checks
- Efficient data storage with maps and variables
- Carbon offset tracking and calculation utilities

### 🌱 Environmental Impact
- Enforces carbon neutrality for all NFT operations
- Tracks total community carbon offset contributions
- Configurable offset rates for different carbon footprints
- Transparent pricing for carbon credits (1 STX per credit)

### 📊 Marketplace Features
- 2.5% marketplace fee structure
- Safe buyer/seller transaction handling
- Listing management and cancellation
- Transfer restrictions to prevent self-transactions

Ready for testing and deployment on Stacks testnet/mainnet.
