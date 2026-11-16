# Solidity audit samples

Six bug classes I report most often, each with a small contract that carries the
bug and a Foundry test that proves the loss. Nothing here is a scanner output and
nothing is theoretical: `forge test` is green because each test drives the attack
and asserts what the victim loses.

```
forge test
```

| # | Sample | Class | What the test shows |
|---|---|---|---|
| 01 | `FeeDistributor` | Swap with `amountOutMin = 0` | Searcher sells ahead of the distribution, the treasury fills 13% under the pre-trade quote, attacker keeps the difference |
| 02 | `Vault` | Share inflation, no virtual offset | First depositor mints 1 wei, donates 10,000, the next depositor's 5,000 mints **zero** shares |
| 03 | `Payout` | Unchecked ERC20 return | Token returns `false`, invoice is marked settled anyway, funds never move |
| 04 | `Distributor` | Unbounded push-payment loop | Gas scales with the holder set: 1.27M at 50 holders, 9.1M at 400, a 300k budget dies |
| 05 | `CDP` | Stale oracle | Feed frozen for three days, borrower mints debt larger than the collateral is actually worth |
| 06 | `FoTBank` | Fee-on-transfer accounting | Ledger credits the amount sent, not the amount received, both depositors lose 1% each way |

Each contract carries the fix at the level of the invariant in its header, not a
one-line patch: virtual offset or dead shares for the vault, pull payments for the
distributor, `updatedAt` and round checks plus a sequencer feed for the oracle,
balance deltas around `transferFrom` for the fee token, and a manipulation-resistant
minimum out for the swap.

## Reading order

01, 03 and 06 are the ones worth reading first: they are two files of contract code
each and the economics are obvious once the test runs. 02 is the classic accounting
trap and the one most often dismissed as "known". 04 is a scaling bug rather than a
theft. 05 needs a feed mock to be interesting.

## What is deliberately missing

- No fuzzing, no invariant suite, no fork tests. These are demonstrations of one
  class each, sized to be read in a minute.
- The mocks are the smallest thing that behaves like the real dependency: a
  constant-product pool for the swap sample, a false-returning token, a 1% fee
  token, a settable feed. They are not production implementations.
- Debt in sample 05 is denominated in the feed's unit and paid 1:1 in wei, to keep
  the example to one feed.

## Who

Andrei Dodu, [Dodu Security](https://dodu.se). Fixed-fee smart contract audits:
[services](https://dodu.se/services) · [what a report looks like](https://dodu.se/audit-report-template).

MIT.
