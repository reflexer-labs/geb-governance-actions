# geb-governance-actions

A `Proposal` is an un-owned object that performs one action (or series of atomic actions[1])
one time only. Think of it as a one-off `DSProxy` with no owner (no `DSAuth` mixin, it is not a `DSThing`).

This primitive is useful to express objects that do actions which shouldn't depend on "sender",
like an upgrade to a contract system that needs to be given root permission.

Note that the spell is only marked as 'executed' if the CALL it makes succeeds, meaning it did not end in
an exceptional condition and it did not revert. Conversely, contracts that use return values instead of
exceptions to signal errors could be successfully called without having the effect you might desire.
"Approving" spells to take action on a system after the spell is deployed generally requires the system
to use exception-based error handling to avoid griefing.


```
var proposal = proposalFactory.create(mySystem, calldata);
// ... deliberate, System owners grant the spell permissions
proposal.executeProposal();
```

## Proposals
This repository includes several pre-made proposals (check unit tests for examples of usage):
- AccessManagement: grant or revoke any access within GEB
- CollateralStabilityFee: change the stability fee of one or more collateralTypes
- DebtCeilingProposal: change debt ceiling for a single collateralType
- FixedDiscountCollateralAuctionHouse: change any of the parameters
- GlobalAuctionParamsProposal: change global auction parameters (initialDebtMintedTokens, debtAuctionBidSize)
- LiquidationCRatio: change liquidation collateralization ratio for one or more collateralTypes
- LiquidationPenalty: change liquidation penalty for one or more collateralTypes
- MultiDebtCeilingProposal: change debt ceiling for multiple collateralTypes
- NewCollateral: add a new collateral to the system
- SafetyCRatio: change safety collateralization ratio for one or more collateralTypes
- SecondaryTaxReceivers: add or remove one or more secondary tax receivers. Also use to edit the tax percentages
