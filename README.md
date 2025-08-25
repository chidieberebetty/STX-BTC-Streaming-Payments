BTC Streaming Payments Contract

Overview

The BTC Streaming Payments Contract enables continuous streaming of STX tokens from a sender to a recipient over time, using Bitcoin blocks as a reference clock.
Instead of sending funds in a single lump sum, this contract allows micro-payments per block, simulating "payments per second" through the predictable cadence of Bitcoin block confirmations (~10 minutes per block).

This is useful for scenarios like:

Payroll streaming

Subscription services

Renting resources (e.g., bandwidth, storage, NFTs)

Continuous grants and funding mechanisms

Key Features

Create Streams: Lock a predefined amount of STX into a payment stream toward a recipient.

Withdraw Earnings: Recipients can withdraw earned funds as blocks progress.

Cancel Streams: Senders can cancel a stream, refunding unused funds while ensuring recipients get what they’ve earned.

Real-Time Status: Query current status, withdrawable balance, and remaining duration.

User History: Both senders and recipients can view active and past streams.

Data Structures
Stream Object

Each stream stores:

sender – The payer.

recipient – The payee.

amount-per-second – Payment rate per block.

start-block – Block when the stream starts.

end-block – Block when the stream ends.

total-amount – Total amount allocated for the stream.

withdrawn-amount – Already withdrawn funds.

is-active – Whether the stream is still active.

Maps

streams: Stores stream details by ID.

user-streams: Stores a list of stream IDs per user (sender/recipient).

Functions
Read-Only

get-stream (stream-id) → Returns details of a given stream.

get-user-streams (user) → Lists all streams associated with a user.

calculate-withdrawable-amount (stream-id) → Returns how much the recipient can withdraw at the current block.

Public

create-stream (recipient amount-per-second duration-blocks)
Creates and funds a new payment stream.

withdraw-from-stream (stream-id)
Allows the recipient to withdraw available funds.

cancel-stream (stream-id)
Allows the sender to cancel the stream, refunding unspent funds while paying out any earned but unclaimed balance to the recipient.

get-stream-status (stream-id)
Returns stream details, remaining blocks, withdrawable balance, and end status.

Error Codes

u100 → Not authorized

u101 → Stream not found

u102 → Insufficient balance

u103 → Stream already exists

u104 → Invalid parameters

u105 → Stream already ended

Usage Example
;; Sender creates a stream to recipient for 100 STX over 144 blocks (~1 day)
(contract-call? .btc-stream create-stream 'SP123... 1 u144)

;; Recipient withdraws earnings after some blocks have passed
(contract-call? .btc-stream withdraw-from-stream u1)

;; Sender cancels stream, reclaiming unspent balance
(contract-call? .btc-stream cancel-stream u1)

;; Anyone checks stream status
(contract-call? .btc-stream get-stream-status u1)

Security Notes

The entire stream amount is locked upfront by transferring funds into the contract.

Withdrawals and refunds are only possible by authorized parties.

A stream becomes inactive either when it is canceled or when the end block is reached.