# Smart Contract Escrow Services

A comprehensive escrow system built on Stacks blockchain using Clarity smart contracts. This system provides secure, automated escrow services for various transaction types with built-in dispute resolution and milestone-based payments.

## System Overview

The escrow services consist of five specialized smart contracts:

### 1. Multi-Party Agreement Contract (`multi-party-agreement.clar`)
- Manages complex transactions involving multiple parties
- Supports weighted voting for agreement modifications
- Handles fund distribution based on predefined ratios
- Tracks participant status and contributions

### 2. Milestone-Based Release Contract (`milestone-release.clar`)
- Enables phased payment releases based on project milestones
- Allows milestone verification by designated validators
- Supports partial fund releases upon milestone completion
- Includes milestone modification capabilities

### 3. Dispute Arbitration Contract (`dispute-arbitration.clar`)
- Provides neutral third-party dispute resolution
- Manages arbitrator selection and voting
- Handles evidence submission and review periods
- Executes binding arbitration decisions

### 4. Automatic Refund Contract (`automatic-refund.clar`)
- Implements time-based and condition-based refunds
- Monitors external conditions for automatic triggers
- Supports partial and full refund scenarios
- Includes emergency refund mechanisms

### 5. Fee Structure Contract (`fee-structure.clar`)
- Calculates dynamic escrow service fees
- Manages fee collection and distribution
- Supports tiered pricing based on transaction value
- Handles fee refunds for disputed transactions

## Key Features

- **Security First**: All contracts include comprehensive input validation and error handling
- **Flexible Terms**: Customizable agreement parameters for different use cases
- **Transparent Process**: All actions are recorded on-chain for full transparency
- **Automated Execution**: Smart contract logic reduces manual intervention
- **Dispute Resolution**: Built-in arbitration system for conflict resolution

## Contract Interactions

Each contract operates independently but can be used together for comprehensive escrow services:

1. **Fee Structure** calculates costs for escrow services
2. **Multi-Party Agreement** establishes the basic escrow terms
3. **Milestone Release** manages phased payments
4. **Dispute Arbitration** handles conflicts
5. **Automatic Refund** provides safety nets

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Basic understanding of Clarity smart contracts

### Installation
\`\`\`bash
git clone <repository-url>
cd clarity-escrow-services
npm install
\`\`\`

### Testing
\`\`\`bash
npm test
\`\`\`

### Deployment
\`\`\`bash
clarinet deploy
\`\`\`

## Usage Examples

### Creating a Multi-Party Escrow
\`\`\`clarity
(contract-call? .multi-party-agreement create-agreement
(list 'SP1... 'SP2... 'SP3...)
(list u100 u200 u300)
u1000
u144)
\`\`\`

### Setting Up Milestones
\`\`\`clarity
(contract-call? .milestone-release create-milestone-escrow
'SP1...
'SP2...
u5000
(list "Design Phase" "Development Phase" "Testing Phase")
(list u1500 u2500 u1000)
u144)
\`\`\`

### Initiating Dispute Resolution
\`\`\`clarity
(contract-call? .dispute-arbitration create-dispute
u1
"Payment not received as agreed"
u72)
\`\`\`

## Security Considerations

- All contracts include reentrancy protection
- Input validation prevents common attack vectors
- Time-based locks prevent premature actions
- Multi-signature requirements for critical operations

## Testing

The test suite covers:
- Contract deployment and initialization
- All public functions with various inputs
- Edge cases and error conditions
- Integration scenarios between contracts

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Submit a pull request

## License

MIT License - see LICENSE file for details
