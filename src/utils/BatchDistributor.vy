# @version ^0.3.7
"""
@title Batch Sending Both Native and ERC-20 Tokens
@license GNU Affero General Public License v3.0
@author pcaversaccio
@notice These functions can be used for batch sending
        both native and ERC-20 tokens. The implementation
        is inspired by my implementation here:
        https://github.com/pcaversaccio/batch-distributor/blob/main/contracts/BatchDistributor.sol,
        as well as by the original implementation of banteg:
        https://github.com/banteg/disperse-research.
"""


from vyper.interfaces import ERC20


# @dev Transaction struct for the transaction payload.
struct Transaction:
    recipient: address
    amount: uint256


# @dev Batch struct for the array of transactions.
struct Batch:
     txns: DynArray[Transaction, max_value(uint8)]


@external
@payable
def __init__():
    """
    @dev To omit the opcodes for checking the `msg.value`
         in the creation-time EVM bytecode, the constructor
         is declared as `payable`.
    """
    pass


@external
@payable
@nonreentrant("lock")
def distribute_ether(data: Batch):
    """
    @dev Distributes ether, denominated in wei, to a
         predefined batch of recipient addresses.
    @notice In the event that excessive ether is sent,
            the residual amount is returned back to the
            `msg.sender`.
    @param data Nested struct object that contains an array
           of tuples that contain each a recipient address &
           ether amount in wei.
    """
    for batch in data.txns:
        # A low-level call is used to guarantee compatibility
        # with smart contract wallets. As a general pre-emptive
        # safety measure, a reentrancy guard is used.
        raw_call(batch.recipient, b"", value=batch.amount)

    if (self.balance != 0):
        raw_call(msg.sender, b"", value=self.balance)


@external
def distribute_token(token: ERC20, data: Batch):
    """
    @dev Distributes ERC-20 tokens, denominated in their corresponding
         lowest unit, to a predefined batch of recipient addresses.
    @notice To deal with (potentially) non-compliant ERC-20 tokens that do have
            no return value, we use the kwarg `default_return_value` for external
            calls. This function was introduced in Vyper version 0.3.4. For more
            details see:
            - https://github.com/vyperlang/vyper/pull/2839,
            - https://github.com/vyperlang/vyper/issues/2812,
            - https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca.
            Note: Since we cast the token address into the official ERC-20 interface,
            the use of non-compliant ERC-20 tokens is prevented by design. Nevertheless,
            we keep this guardrail for security reasons.
    @param token ERC-20 token contract address.
    @param data Nested struct object that contains an array
           of tuples that contain each a recipient address &
           token amount.
    """
    total: uint256 = 0
    for batch in data.txns:
        total += batch.amount

    assert token.transferFrom(msg.sender, self, total, default_return_value=True)

    for batch in data.txns:
        assert token.transfer(batch.recipient, batch.amount, default_return_value=True)
