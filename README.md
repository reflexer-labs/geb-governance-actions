# ds-spell

A `DSSpell` is an un-owned object that performs one action (or series of atomic actions[1])
one time only. Think of it as a one-off `DSProxy` with no owner (no `DSAuth` mixin, it is not a `DSThing`).

This primitive is useful to express objects that do actions which shouldn't depend on "sender",
like an upgrade to a contract system that needs to be given root permission.

Note that the spell is only marked as 'done' if the CALL it makes succeeds, meaning it did not end in
an exceptional condition and it did not revert. Conversely, contracts that use return values instead of
exceptions to signal errors could be successfully called without having the effect you might desire.
"Approving" spells to take action on a system after the spell is deployed generally requires the system
to use exception-based error handling to avoid griefing.


```
var spell = spellbook.create(mySystem, calldata);
// ... deliberate, System owners grant the spell permissions
spell.cast();
```

# line-spell

A spell-like contract that sets the debt ceiling (`line`) of a collateral type
  (`ilk`) through a DSProxy-like `mom` contract.

# Dss Add Ilk Spell

Spell contract to deploy a new collateral type in the DSS system.

## Additional Documentation

- `dss-deploy` [source code](https://github.com/makerdao/dss-deploy)
- `dss` [source code](https://github.com/makerdao/dss)

## Deployment

### Prerequisites:

- seth/dapp (https://dapp.tools/)
- Have a DSS instance running

### Steps:

1) Export contract variables

- `export TOKEN=<TOKEN ADDR>`
- `export PIP=<TOKEN/USD FEED ADDR>`
- `export ILK="$(seth --to-bytes32 "$(seth --from-ascii "<COLLATERAL NAME>")")"`
- `export MCD_VAT=<VAT ADDR>`
- `export MCD_CAT=<CAT ADDR>`
- `export MCD_JUG=<JUG ADDR>`
- `export MCD_SPOT=<SPOTTER ADDR>`
- `export MCD_PAUSE=<PAUSE ADDR>`
- `export MCD_PAUSE_PROXY=<PAUSE PROXY ADDR>`
- `export MCD_ADM=<CHIEF ADDR>`
- `export MCD_END=<END ADDR>`

2) Deploy Adapter (e.g. [GemJoin](https://github.com/makerdao/dss/blob/master/src/join.sol#L62))

- `export JOIN=$(dapp create GemJoin "$MCD_VAT" "$ILK" "$TOKEN")`

3) Deploy Flip Auction and set permissions (e.g. [Flipper](https://github.com/makerdao/dss/blob/master/src/flip.sol))

- `export FLIP=$(dapp create Flipper "$MCD_VAT" "$ILK")`

- `seth send "$FLIP" 'rely(address)' "$MCD_PAUSE_PROXY"`

- `seth send "$FLIP" 'deny(address)' "$ETH_FROM"`

4) Export New Collateral Type variables
- `export LINE=<DEBT CEILING VALUE>` (e.g. 5M DAI `"$(seth --to-uint256 $(echo "5000000"*10^45 | bc))"`)
- `export MAT=<LIQUIDATION RATIO VALUE>` (e.g. 150% `"$(seth --to-uint256 $(echo "150"*10^25 | bc))"`)
- `export DUTY=<STABILITY FEE VALUE>` (e.g. 1% yearly `"$(seth --to-uint256 1000000000315522921573372069)"`)
- `export CHOP=<LIQUIDATION PENALTY VALUE>` (e.g. 10% `"$(seth --to-uint256 $(echo "110"*10^25 | bc))"`)
- `export LUMP=<LIQUIDATION QUANTITY VALUE>` (e.g. 1K DAI `"$(seth --to-uint256 $(echo "1000"*10^18 | bc))"`)

5) Deploy Spell

- `export SPELL=$(seth send --create out/DssAddIlkSpell.bin 'DssAddIlkSpell(bytes32,address,address[8] memory,uint256[5] memory)' $ILK $MCD_PAUSE ["${MCD_VAT#0x}","${MCD_CAT#0x}","${MCD_JUG#0x}","${MCD_SPOT#0x}","${MCD_END#0x}","${JOIN#0x}","${PIP#0x}","${FLIP#0x}"] ["$LINE","$MAT","$DUTY","$CHOP","$LUMP"])`

6) Create slate

- `seth send "$MCD_ADM" 'etch(address[] memory)' ["${SPELL#0x}"]`

7) Wait for the Spell to be elected

8) Schedule Spell

- `seth send "$SPELL" 'schedule()'`

9) Wait for Pause delay

10) Cast Spell

- `seth send "$SPELL" 'cast()'`
