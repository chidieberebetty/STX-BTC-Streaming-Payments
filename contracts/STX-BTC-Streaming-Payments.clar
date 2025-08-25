;; BTC Streaming Payments Contract
;; Continuous payments per second using Bitcoin blocks as time reference

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-STREAM-NOT-FOUND u101)
(define-constant ERR-INSUFFICIENT-BALANCE u102)
(define-constant ERR-STREAM-ALREADY-EXISTS u103)
(define-constant ERR-INVALID-PARAMETERS u104)
(define-constant ERR-STREAM-ENDED u105)

;; Assuming ~10 minutes per block, ~6 blocks per hour, ~144 blocks per day
(define-constant BLOCKS-PER-SECOND u1)

;; Data Variables
(define-data-var stream-id-nonce uint u0)

;; Data Maps
(define-map streams
  uint
  {
    sender: principal,
    recipient: principal,
    amount-per-second: uint,
    start-block: uint,
    end-block: uint,
    total-amount: uint,
    withdrawn-amount: uint,
    is-active: bool
  }
)

(define-map user-streams principal (list 100 uint))

;; Read-only functions
(define-read-only (get-stream (stream-id uint))
  (map-get? streams stream-id)
)

(define-read-only (get-user-streams (user principal))
  (default-to (list) (map-get? user-streams user))
)

(define-read-only (calculate-withdrawable-amount (stream-id uint))
  (match (map-get? streams stream-id)
    stream
    (let
      (
        (current-block block-height)
        (start-block (get start-block stream))
        (end-block (get end-block stream))
        (amount-per-second (get amount-per-second stream))
        (withdrawn-amount (get withdrawn-amount stream))
      )
      (if (get is-active stream)
        (let
          (
            (effective-end-block (if (< current-block end-block) current-block end-block))
            (blocks-elapsed (if (> effective-end-block start-block) (- effective-end-block start-block) u0))
            (total-earned (* blocks-elapsed amount-per-second))
            (available (if (> total-earned withdrawn-amount) (- total-earned withdrawn-amount) u0))
          )
          (ok available)
        )
        (ok u0)
      )
    )
(err ERR-STREAM-NOT-FOUND)
  )
)

;; Public functions
(define-public (create-stream 
  (recipient principal) 
  (amount-per-second uint) 
  (duration-blocks uint)
)
  (let
    (
      (stream-id (+ (var-get stream-id-nonce) u1))
      (start-block block-height)
      (end-block (+ start-block duration-blocks))
      (total-amount (* amount-per-second duration-blocks))
      (sender-streams (get-user-streams tx-sender))
    )
    (asserts! (> amount-per-second u0) (err ERR-INVALID-PARAMETERS))
    (asserts! (> duration-blocks u0) (err ERR-INVALID-PARAMETERS))
    (asserts! (>= (stx-get-balance tx-sender) total-amount) (err ERR-INSUFFICIENT-BALANCE))

    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))

    (map-set streams stream-id {
      sender: tx-sender,
      recipient: recipient,
      amount-per-second: amount-per-second,
      start-block: start-block,
      end-block: end-block,
      total-amount: total-amount,
      withdrawn-amount: u0,
      is-active: true
    })

    (map-set user-streams tx-sender 
      (unwrap-panic (as-max-len? (append sender-streams stream-id) u100)))

    (let ((recipient-streams (get-user-streams recipient)))
      (map-set user-streams recipient 
        (unwrap-panic (as-max-len? (append recipient-streams stream-id) u100)))
    )

    (var-set stream-id-nonce stream-id)
    (ok stream-id)
  )
)

(define-public (withdraw-from-stream (stream-id uint))
  (match (map-get? streams stream-id)
    stream
    (let ((withdrawable (unwrap! (calculate-withdrawable-amount stream-id) (err ERR-STREAM-NOT-FOUND))))
      (asserts! (is-eq tx-sender (get recipient stream)) (err ERR-NOT-AUTHORIZED))
      (asserts! (get is-active stream) (err ERR-STREAM-ENDED))
      (asserts! (> withdrawable u0) (err ERR-INSUFFICIENT-BALANCE))

      (try! (as-contract (stx-transfer? withdrawable tx-sender (get recipient stream))))

      (map-set streams stream-id 
        (merge stream { withdrawn-amount: (+ (get withdrawn-amount stream) withdrawable) }))

      (ok withdrawable)
    )
(err ERR-STREAM-NOT-FOUND)
  )
)

(define-public (cancel-stream (stream-id uint))
  (match (map-get? streams stream-id)
    stream
    (let
      (
        (withdrawable (unwrap! (calculate-withdrawable-amount stream-id) (err ERR-STREAM-NOT-FOUND)))
        (sender (get sender stream))
        (recipient (get recipient stream))
        (total-amount (get total-amount stream))
        (withdrawn-amount (get withdrawn-amount stream))
        (refund-amount (- total-amount withdrawn-amount withdrawable))
      )
      (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
      (asserts! (get is-active stream) (err ERR-STREAM-ENDED))

      (if (> withdrawable u0)
        (begin
          (try! (as-contract (stx-transfer? withdrawable tx-sender recipient)))
          true
        )
        true
      )

      (if (> refund-amount u0)
        (begin
          (try! (as-contract (stx-transfer? refund-amount tx-sender sender)))
          true
        )
        true
      )

      (map-set streams stream-id 
        (merge stream { 
          is-active: false,
          withdrawn-amount: (+ withdrawn-amount withdrawable)
        }))

      (ok { withdrawn: withdrawable, refunded: refund-amount })
    )
(err ERR-STREAM-NOT-FOUND)
  )
)

(define-public (get-stream-status (stream-id uint))
  (match (map-get? streams stream-id)
    stream
    (let 
      (
        (current-block block-height)
        (start-block (get start-block stream))
        (end-block (get end-block stream))
        (is-active (get is-active stream))
        (withdrawable (unwrap! (calculate-withdrawable-amount stream-id) (err ERR-STREAM-NOT-FOUND)))
      )
      (ok {
        stream: stream,
        current-block: current-block,
        blocks-remaining: (if (and is-active (< current-block end-block)) (- end-block current-block) u0),
        withdrawable-amount: withdrawable,
        is-ended: (or (not is-active) (>= current-block end-block))
      })
    )
(err ERR-STREAM-NOT-FOUND)
  )
)