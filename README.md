# Verifiable Background Check System for Non-Profit Volunteers

A blockchain-based system built on the Stacks network that enables non-profit organizations to conduct secure, verifiable, and tamper-proof background checks for volunteers.


## Overview

The Verifiable Background Check System for Non-Profit Volunteers is a blockchain-based solution designed to streamline and secure the background verification process for individuals volunteering at non-profit organizations. It ensures:

- Transparent, tamper-proof background check records
- Volunteer privacy and data minimization through selective disclosure
- Trusted verification via authorized evaluators
- Easy access for non-profits to confirm volunteer credentials

Each smart contract is modular, handling a single responsibility, ensuring flexibility and security.

## Core Modules

The system consists of six core smart contracts:

### 1. VolunteerRegistry Contract
Registers volunteers on-chain with minimal metadata (unique ID, hash of personal data, not raw data).

### 2. ProviderRegistry Contract
Maintains a whitelist of accredited background check providers authorized to issue verifications.

### 3. BackgroundCheckAttestation Contract
Allows accredited providers to publish cryptographic attestations of completed checks for volunteers.

### 4. VerificationAccess Contract
Enables volunteers to grant non-profits access to specific background check attestations.

### 5. GovernanceDAO Contract
Provides community-led governance over provider accreditation, dispute resolution, and system upgrades.

### 6. ReputationNFT Contract
Mints non-transferable NFTs (soulbound tokens) to volunteers representing verified background check completion.

## System Workflow

1. **Volunteer Registration** - Volunteer signs up and is recorded in `VolunteerRegistry`
2. **Provider Accreditation** - Verified providers are onboarded via `ProviderRegistry`
3. **Background Check Attestation** - Provider issues check records via `BackgroundCheckAttestation`
4. **Volunteer Grants Access** - Volunteer shares attestations with non-profits using `VerificationAccess`
5. **Non-Profit Validation** - Non-profits verify attestation authenticity on-chain
6. **Recognition** - Volunteer receives `ReputationNFT` for completed verification
7. **Governance Oversight** - DAO manages disputes and approves/removes providers

## Technology Stack

- [Stacks Blockchain](https://www.stacks.co/) - Layer-2 blockchain anchored to Bitcoin
- [Clarity](https://clarity-lang.org/) - Smart contract language for Stacks
- [Clarinet](https://github.com/hirosystems/clarinet) - Development toolchain for Clarity smart contracts
- [Vitest](https://vitest.dev/) - Unit testing framework
- TypeScript - For testing and development tooling

## Project Structure

```
.
├── Clarinet.toml          # Project configuration
├── contracts/             # Smart contracts (Clarity)
├── settings/              # Network configuration
│   └── Devnet.toml        # Development network settings
├── tests/                 # Unit tests
├── package.json           # Node.js dependencies and scripts
└── docs/                  # Documentation
```

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v18 or higher)
- [Clarinet](https://github.com/hirosystems/clarinet#installation)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd Verifiable-Background-Check-System-for-Non-Profit-Volunteers
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

## Development

### Running Tests

To run the test suite:

```bash
npm test
```

To run tests with coverage report:

```bash
npm run test:report
```

To run tests in watch mode (automatically re-runs when files change):

```bash
npm run test:watch
```

### Deploying Contracts

To deploy contracts to a local development network:

1. Start the Clarinet console:
   ```bash
   clarinet console
   ```

2. Deploy contracts in the console:
   ```clarity
   ::deploy
   ```

## Stakeholders

- **Volunteers**: Individuals applying to work at non-profits
- **Non-Profit Organizations**: Entities requiring verified background information on volunteers
- **Accredited Check Providers**: Authorized agencies conducting background checks
- **Auditors/Regulators**: Oversight bodies ensuring process compliance
- **Community DAO**: Governance mechanism overseeing trusted providers and dispute resolution

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Built with ❤️ for the non-profit community*