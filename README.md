# 🏛️ Insurance on Bitcoin Layer

## 📋 Overview

A parametric insurance smart contract built on the Stacks blockchain that provides automated payouts triggered by verified oracle data. Perfect for weather insurance, flight delays, and other measurable events! ⚡

## ✨ Features

- 🔐 **Secure Policy Management**: Create, manage, and track insurance policies
- 🤖 **Oracle Integration**: Automated payouts triggered by verified external data
- ⚡ **Instant Settlements**: No manual claims processing required
- 💰 **Flexible Coverage**: Support for various insurance types and amounts
- 🛡️ **Multi-Oracle Support**: Authorized oracle network for data verification
- 📊 **Transparent Tracking**: Full policy lifecycle visibility

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run `clarinet check` to verify the contract

### 📝 Contract Functions

#### Public Functions

**🏗️ Policy Management**
- `create-policy(coverage-amount, trigger-condition, duration, policy-type)` - Create new insurance policy
- `cancel-policy(policy-id)` - Cancel active policy (50% refund)
- `process-claim(policy-id, trigger-value)` - Process insurance claim

**👥 Oracle Management**
- `add-oracle(oracle-principal)` - Add authorized oracle (owner only)
- `remove-oracle(oracle-principal)` - Remove oracle authorization
- `submit-oracle-data(policy-id, value)` - Submit trigger data

**⚙️ Administration**
- `withdraw-fees()` - Withdraw contract fees (owner only)
- `update-oracle-fee(new-fee)` - Update oracle fee structure
- `update-min-premium(new-minimum)` - Set minimum premium amount

#### Read-Only Functions

**📊 Policy Information**
- `get-policy(policy-id)` - Get complete policy details
- `get-policy-status(policy-id)` - Check policy status
- `get-policy-payout(policy-id)` - View payout information
- `is-policy-claimable(policy-id)` - Check if policy can be claimed

**💡 Utility Functions**
- `calculate-premium(coverage-amount)` - Calculate required premium (10% of coverage)
- `get-contract-balance()` - View total contract balance
- `get-oracle-data(policy-id)` - Get oracle data for policy

## 🎯 Usage Examples

### Creating a Weather Insurance Policy

```clarity
;; Create weather insurance with 1000 STX coverage
;; Triggers when temperature exceeds 35°C (350 in contract units)
(contract-call? .Insurance-on-Bitcoin-Layer create-policy u100000000 u350 u1000 "weather")
```

### Submitting Oracle Data

```clarity
;; Oracle submits temperature reading of 38°C
(contract-call? .Insurance-on-Bitcoin-Layer submit-oracle-data u1 u380)
```

### Checking Policy Status

```clarity
;; Check if policy 1 is still active
(contract-call? .Insurance-on-Bitcoin-Layer get-policy-status u1)
```

## 🔧 Configuration

### Default Settings

- **Minimum Premium**: 5 STX
- **Premium Rate**: 10% of coverage amount
- **Oracle Fee**: 1 STX

### Policy Types Supported

- 🌦️ **Weather Insurance**: Temperature, rainfall, wind speed
- ✈️ **Flight Insurance**: Departure delays, cancellations
- 🌊 **Flood Insurance**: Water level measurements
- 📈 **Index Insurance**: Market indicators, commodity prices

## 🛡️ Security Features

- Oracle authorization system prevents unauthorized data submission
- Policy expiration prevents indefinite claims
- Owner-only administrative functions
- Automatic claim processing eliminates human error
- Transparent on-chain settlement tracking

## 📈 Contract Economics

### Premium Calculation
Premium = Coverage Amount × 10%

### Payout Triggers
Policies pay out when oracle data meets or exceeds the trigger condition specified during policy creation.

### Fee Structure
- Oracle submission fees support network maintenance
- Contract owner can withdraw accumulated fees
- Policy holders receive 50% premium refund on cancellation

## 🔍 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For questions or support, please open an issue in this repository.

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Always test thoroughly before deploying to mainnet.
