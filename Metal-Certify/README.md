# Precious Metals Tokenization Smart Contract

A comprehensive smart contract for tokenizing precious metals on the Stacks blockchain, enabling digital representation of physical gold, silver, platinum, and palladium with full audit trails and vault management.

## Overview

This smart contract provides a complete solution for tokenizing precious metals, allowing users to mint, transfer, and manage digital tokens that represent physical precious metals stored in authorized vaults. Each token contains detailed metadata about the physical metal including weight, purity, certificate information, and current market value.

## Features

### Core Functionality
- **Metal Tokenization**: Mint tokens representing physical precious metals
- **Multi-Metal Support**: Gold, Silver, Platinum, and Palladium
- **Comprehensive Metadata**: Weight, purity, certificates, vault location, market value
- **Secure Transfers**: Token ownership transfers with restriction capabilities
- **Audit Trail**: Complete tracking of all token operations and audits

### Administrative Features
- **Vault Management**: Authorize and manage secure storage facilities
- **Auditor Authorization**: Manage certified auditors for token verification
- **Price Updates**: Real-time metal price management
- **Emergency Controls**: Pause functionality for security incidents
- **Token Restrictions**: Ability to restrict specific tokens from trading

### Advanced Features
- **Batch Operations**: Efficient bulk token minting
- **Market Value Calculation**: Automatic token valuation based on current prices
- **Vault Capacity Tracking**: Monitor storage facility utilization
- **Transfer Restrictions**: Compliance and security controls

## Supported Metal Types

| Metal | Constant | Value |
|-------|----------|-------|
| Gold | `METAL_GOLD` | 1 |
| Silver | `METAL_SILVER` | 2 |
| Platinum | `METAL_PLATINUM` | 3 |
| Palladium | `METAL_PALLADIUM` | 4 |

## Contract Architecture

### Data Structures

#### Token Information
Each token contains:
- Owner address
- Metal type (Gold/Silver/Platinum/Palladium)
- Weight in grams
- Purity (in basis points, e.g., 9999 = 99.99%)
- Certificate hash for authenticity
- Vault location
- Creation and last audit block heights
- Current market value in USD cents

#### Vault Management
Authorized vaults track:
- Name and location
- Authorization status
- Total capacity and current holdings
- Real-time capacity utilization

#### Auditor System
Certified auditors maintain:
- Professional credentials
- Authorization status
- Audit history and capabilities

## Key Functions

### Administrative Functions

#### `authorize-vault`
Authorize a new vault facility for metal storage.
```clarity
(authorize-vault vault-address name location capacity)
```

#### `authorize-auditor`
Authorize a certified auditor for token verification.
```clarity
(authorize-auditor auditor-address name certification)
```

#### `update-metal-price`
Update current market prices for metals (owner only).
```clarity
(update-metal-price metal-type price-per-gram-usd)
```

### Token Management

#### `mint-token`
Create a new token representing physical metal (authorized vaults only).
```clarity
(mint-token recipient metal-type weight-grams purity certificate-hash vault-location)
```

#### `transfer-token`
Transfer token ownership between addresses.
```clarity
(transfer-token token-id sender recipient)
```

#### `burn-token`
Permanently destroy a token (owner or authorized vault only).
```clarity
(burn-token token-id)
```

#### `audit-token`
Update token audit information (authorized auditors only).
```clarity
(audit-token token-id new-certificate-hash)
```

### Query Functions

#### `get-token-info`
Retrieve complete token metadata.
```clarity
(get-token-info token-id)
```

#### `get-token-balance`
Check token ownership for an address.
```clarity
(get-token-balance owner token-id)
```

#### `calculate-token-value`
Get current market value of a token.
```clarity
(calculate-token-value token-id)
```

#### `get-contract-stats`
View overall contract statistics.
```clarity
(get-contract-stats)
```

## Security Features

### Access Control
- **Contract Owner**: Full administrative control
- **Authorized Vaults**: Can mint and burn tokens
- **Authorized Auditors**: Can update audit information
- **Token Owners**: Can transfer their tokens

### Emergency Controls
- Contract pause/unpause functionality
- Emergency pause for critical situations
- Token transfer restrictions for compliance
- Vault authorization revocation

### Data Integrity
- Certificate hash verification
- Purity validation (0-100.00%)
- Weight and amount validation
- Metal type verification

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `ERR_UNAUTHORIZED` | Insufficient permissions |
| u101 | `ERR_NOT_FOUND` | Resource not found |
| u102 | `ERR_ALREADY_EXISTS` | Resource already exists |
| u103 | `ERR_INVALID_AMOUNT` | Invalid amount specified |
| u104 | `ERR_INSUFFICIENT_BALANCE` | Insufficient token balance |
| u105 | `ERR_INVALID_METAL_TYPE` | Unsupported metal type |
| u106 | `ERR_VAULT_NOT_AUTHORIZED` | Vault not authorized |
| u107 | `ERR_CERTIFICATE_EXPIRED` | Certificate has expired |
| u108 | `ERR_INVALID_PURITY` | Invalid purity value |
| u109 | `ERR_TRANSFER_FAILED` | Transfer operation failed |
| u110 | `ERR_INVALID_PRICE` | Invalid price specified |

## Usage Examples

### Setting Up Vaults and Auditors
```clarity
;; Authorize a vault
(contract-call? .precious-metals authorize-vault 'SP123...VAULT "SecureVault Ltd" "New York, USA" u1000000)

;; Authorize an auditor
(contract-call? .precious-metals authorize-auditor 'SP456...AUDITOR "GoldCert Inc" "ISO 9001 Certified")
```

### Minting Tokens
```clarity
;; Mint 100g of 99.99% pure gold
(contract-call? .precious-metals mint-token 
  'SP789...RECIPIENT 
  u1  ;; METAL_GOLD
  u100 
  u9999 
  0x1234567890abcdef... 
  "Vault A - NYC")
```

### Transferring Tokens
```clarity
;; Transfer token to new owner
(contract-call? .precious-metals transfer-token u1 tx-sender 'SP999...NEW-OWNER)
```

## Deployment Considerations

### Prerequisites
- Stacks blockchain deployment environment
- Authorized vault partnerships
- Certified auditor relationships
- Metal price feed integration

### Initial Setup
1. Deploy the contract
2. Authorize initial vaults
3. Set up certified auditors
4. Initialize metal prices
5. Configure operational parameters

### Ongoing Maintenance
- Regular price updates
- Vault capacity monitoring
- Audit schedule compliance
- Security parameter reviews

## Integration

### Price Feeds
The contract supports integration with external price oracles for real-time metal valuation. Prices are stored in USD cents for precision.

### Vault Systems
Integration points for vault management systems to automate token minting and burning based on physical metal deposits and withdrawals.

### Audit Systems
API endpoints for audit system integration to maintain token authenticity and compliance.