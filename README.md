# GHO Wrapper

GHO Wrapper is a smart contract that wraps the ERC20 token **[GHO](https://etherscan.io/address/0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f)**, enabling deposits, withdrawals, and permit-based approvals for seamless integration. The token metadata (name and symbol) is configurable, allowing the deployer to set custom values during initialization.


## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Deploy

Copy the example environment file and populate the necessary parameters:

```shell
$ cp .env.example .env
```

Ensure all parameters are correct, as they will be used for the actual deployment.

```shell
make deploy
```

## Security

You can find all audit reports under the [audits](./audits) folder

- [2025-02-08 - Pashov Audit Group](./audits/2025-02-08_PashovAuditGroup.pdf)
