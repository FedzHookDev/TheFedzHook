

# Fedz Deployment

1. `TimeSlotSystem` with address `0x2a3E3A5D164FE0667c92896987857E32Ae53E198` deployed on https://arbiscan.io/address/0x2a3E3A5D164FE0667c92896987857E32Ae53E198

2. `FedzHook` with address `0x4E3Fa5D73314Ef96f06D861C35A92e6626e7CAC0` deployed on https://arbiscan.io/tx/0xfc65be49ee0307894cb92b1e3368c11d37829f85eb7a271fabb11f370074aacf

3. `FedzModifyLiquidityWrapper` (`FedzPositionManager`) with address `0x4687AD6A7DD44287317fCc725089F04F7e12Aa80` deployed on https://arbiscan.io/tx/0x3af948d617700dc5c7a448bae37b3ef0e0019f82aa36f59a86a3f48ada566a65

4. `FedzSwapRouter` with address `0xa857555633F521C3E0397c54a0CbF489011ff919` deployed on https://arbiscan.io/tx/0xa91df9b036e9bd669920315c725ed99b375ddbb04f0c6eab60843ca872c8e8a8

5. Pool with id `C96626B1A4FB5C7785FFA8BFFEDDAA4FE8E3F7BBF7477C1FC7B30ECBE2E8CE2A` created on https://arbiscan.io/address/0x5ad517f4b2ff846c408e1ff554ccc7c224760dc0

6. Token 0 is `0x894341be568Eae3697408c420f1d0AcFCE6E55f9`
7. Token 1 is `0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9`
8. NFT contract `0xE073a53a2Ba1709e2c8F481f1D7dbabA1eF611FD`


# How to Modify Liquidity and Swap - Fedz Pool

## Add Liquidity

Steps:
1. Approve (add transfer allowance) to `FedzPositionManager` (`0x4687AD6A7DD44287317fCc725089F04F7e12Aa80`) for `USDT`
[Go to approve function on contract write](https://arbiscan.io/address/0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9#writeProxyContract#F2)
2. Approve allowance to `FedzPositionManager` (`0x4687AD6A7DD44287317fCc725089F04F7e12Aa80`) for `FUSD`
3. Execute `modifyLiquidity` on `FedzPositionManager` [take the action](https://arbiscan.io/address/0x4687AD6A7DD44287317fCc725089F04F7e12Aa80#writeContract#F1)

* remove liquidity is the same but not required the first two steps, and with negative `liquidityDelta`

## Remove Liqudity
It is very similar to `AddLiquidity` but Approvals are not needed and the `liquidityDelta` is negative (add = positive `liqiudityDelta`)

1. Execute `modifyLiquidity` on `FedzPositionManager` 
[take the action](https://arbiscan.io/address/0x4687AD6A7DD44287317fCc725089F04F7e12Aa80#writeContract#F1)


## Swap

1. Approve `USDT` (or `FUSDC`) to `FedzSwapRouter` (`0xa857555633f521c3e0397c54a0cbf489011ff919`) for `USDT`
[Go to approve function on contract write](https://arbiscan.io/address/0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9#writeProxyContract#F2)
2. Execute `swap` on `FedzSwapRouter` [take the action](https://arbiscan.io/address/0xa857555633f521c3e0397c54a0cbf489011ff919#writeContract#F1)


