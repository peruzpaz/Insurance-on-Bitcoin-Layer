(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_POLICY_NOT_FOUND (err u101))
(define-constant ERR_POLICY_EXPIRED (err u102))
(define-constant ERR_POLICY_CLAIMED (err u103))
(define-constant ERR_INSUFFICIENT_PREMIUM (err u104))
(define-constant ERR_ORACLE_NOT_AUTHORIZED (err u105))
(define-constant ERR_INVALID_THRESHOLD (err u106))
(define-constant ERR_POLICY_ACTIVE (err u107))
(define-constant ERR_INSUFFICIENT_BALANCE (err u108))
(define-constant ERR_POLICY_NOT_ELIGIBLE_FOR_RENEWAL (err u109))
(define-constant ERR_CANNOT_RENEW_CLAIMED_POLICY (err u110))

(define-data-var contract-owner principal tx-sender)
(define-data-var policy-counter uint u0)
(define-data-var oracle-fee uint u1000000)
(define-data-var min-premium uint u5000000)

(define-map authorized-oracles principal bool)
(define-map policies 
  uint 
  {
    policy-holder: principal,
    premium: uint,
    coverage-amount: uint,
    trigger-condition: uint,
    expiry-block: uint,
    claimed: bool,
    policy-type: (string-ascii 20),
    created-block: uint
  }
)

(define-map oracle-data 
  uint 
  {
    value: uint,
    timestamp: uint,
    oracle: principal,
    verified: bool
  }
)

(define-map policy-payouts 
  uint 
  {
    amount: uint,
    paid-block: uint,
    trigger-value: uint
  }
)

(define-map renewal-history 
  principal 
  {
    total-renewals: uint,
    last-renewal-block: uint,
    policies-without-claims: uint
  }
)

(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (map-set authorized-oracles tx-sender true)
    (ok true)
  )
)

(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (map-set authorized-oracles oracle true)
    (ok true)
  )
)

(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (map-set authorized-oracles oracle false)
    (ok true)
  )
)

(define-public (create-policy 
  (coverage-amount uint) 
  (trigger-condition uint) 
  (duration uint) 
  (policy-type (string-ascii 20))
)
  (let 
    (
      (policy-id (+ (var-get policy-counter) u1))
      (required-premium (/ (* coverage-amount u10) u100))
      (expiry-block (+ stacks-block-height duration))
    )
    (asserts! (>= required-premium (var-get min-premium)) ERR_INSUFFICIENT_PREMIUM)
    (try! (stx-transfer? required-premium tx-sender (as-contract tx-sender)))
    (map-set policies policy-id {
      policy-holder: tx-sender,
      premium: required-premium,
      coverage-amount: coverage-amount,
      trigger-condition: trigger-condition,
      expiry-block: expiry-block,
      claimed: false,
      policy-type: policy-type,
      created-block: stacks-block-height
    })
    (var-set policy-counter policy-id)
    (ok policy-id)
  )
)

(define-public (submit-oracle-data (policy-id uint) (value uint))
  (let 
    (
      (oracle-authorized (default-to false (map-get? authorized-oracles tx-sender)))
    )
    (asserts! oracle-authorized ERR_ORACLE_NOT_AUTHORIZED)
    (map-set oracle-data policy-id {
      value: value,
      timestamp: stacks-block-height,
      oracle: tx-sender,
      verified: true
    })
    (try! (process-claim policy-id value))
    (ok true)
  )
)

(define-public (process-claim (policy-id uint) (trigger-value uint))
  (let 
    (
      (policy (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND))
      (oracle-info (unwrap! (map-get? oracle-data policy-id) ERR_POLICY_NOT_FOUND))
    )
    (asserts! (not (get claimed policy)) ERR_POLICY_CLAIMED)
    (asserts! (< stacks-block-height (get expiry-block policy)) ERR_POLICY_EXPIRED)
    (asserts! (get verified oracle-info) ERR_ORACLE_NOT_AUTHORIZED)
    
    (if (>= trigger-value (get trigger-condition policy))
      (begin
        (try! (as-contract (stx-transfer? (get coverage-amount policy) tx-sender (get policy-holder policy))))
        (map-set policies policy-id (merge policy { claimed: true }))
        (map-set policy-payouts policy-id {
          amount: (get coverage-amount policy),
          paid-block: stacks-block-height,
          trigger-value: trigger-value
        })
        (ok true)
      )
      (ok false)
    )
  )
)

(define-public (cancel-policy (policy-id uint))
  (let 
    (
      (policy (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND))
      (refund-amount (/ (get premium policy) u2))
    )
    (asserts! (is-eq tx-sender (get policy-holder policy)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get claimed policy)) ERR_POLICY_CLAIMED)
    (asserts! (> (get expiry-block policy) stacks-block-height) ERR_POLICY_EXPIRED)
    
    (try! (as-contract (stx-transfer? refund-amount tx-sender (get policy-holder policy))))
    (map-set policies policy-id (merge policy { claimed: true }))
    (ok refund-amount)
  )
)

(define-public (withdraw-fees)
  (let 
    (
      (contract-balance (stx-get-balance (as-contract tx-sender)))
      (withdraw-amount (- contract-balance u1000000))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> withdraw-amount u0) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (stx-transfer? withdraw-amount tx-sender (var-get contract-owner))))
    (ok withdraw-amount)
  )
)

(define-public (update-oracle-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (var-set oracle-fee new-fee)
    (ok new-fee)
  )
)

(define-public (update-min-premium (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (var-set min-premium new-minimum)
    (ok new-minimum)
  )
)

(define-public (renew-policy (old-policy-id uint) (new-duration uint))
  (let 
    (
      (old-policy (unwrap! (map-get? policies old-policy-id) ERR_POLICY_NOT_FOUND))
      (policy-holder (get policy-holder old-policy))
      (renewal-record (default-to 
        { total-renewals: u0, last-renewal-block: u0, policies-without-claims: u0 }
        (map-get? renewal-history policy-holder)
      ))
      (discount-rate (calculate-renewal-discount (get total-renewals renewal-record) (get claimed old-policy)))
      (base-premium (/ (* (get coverage-amount old-policy) u10) u100))
      (discounted-premium (- base-premium (/ (* base-premium discount-rate) u100)))
      (new-policy-id (+ (var-get policy-counter) u1))
      (new-expiry-block (+ stacks-block-height new-duration))
    )
    (asserts! (is-eq tx-sender policy-holder) ERR_NOT_AUTHORIZED)
    (asserts! (>= stacks-block-height (get expiry-block old-policy)) ERR_POLICY_NOT_ELIGIBLE_FOR_RENEWAL)
    (asserts! (>= discounted-premium (var-get min-premium)) ERR_INSUFFICIENT_PREMIUM)
    
    (try! (stx-transfer? discounted-premium tx-sender (as-contract tx-sender)))
    
    (map-set policies new-policy-id {
      policy-holder: policy-holder,
      premium: discounted-premium,
      coverage-amount: (get coverage-amount old-policy),
      trigger-condition: (get trigger-condition old-policy),
      expiry-block: new-expiry-block,
      claimed: false,
      policy-type: (get policy-type old-policy),
      created-block: stacks-block-height
    })
    
    (map-set renewal-history policy-holder {
      total-renewals: (+ (get total-renewals renewal-record) u1),
      last-renewal-block: stacks-block-height,
      policies-without-claims: (if (get claimed old-policy) 
        (get policies-without-claims renewal-record)
        (+ (get policies-without-claims renewal-record) u1)
      )
    })
    
    (var-set policy-counter new-policy-id)
    (ok { new-policy-id: new-policy-id, discount-applied: discount-rate, premium-paid: discounted-premium })
  )
)

(define-private (calculate-renewal-discount (renewal-count uint) (was-claimed bool))
  (let 
    (
      (base-discount (if (<= renewal-count u0) u0
        (if (<= renewal-count u2) u5
          (if (<= renewal-count u5) u10
            (if (<= renewal-count u10) u15 u20)
          )
        )
      ))
      (claim-penalty (if was-claimed u5 u0))
    )
    (if (>= base-discount claim-penalty)
      (- base-discount claim-penalty)
      u0
    )
  )
)

(define-read-only (get-policy (policy-id uint))
  (map-get? policies policy-id)
)

(define-read-only (get-oracle-data (policy-id uint))
  (map-get? oracle-data policy-id)
)

(define-read-only (get-policy-payout (policy-id uint))
  (map-get? policy-payouts policy-id)
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to false (map-get? authorized-oracles oracle))
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-policy-count)
  (var-get policy-counter)
)

(define-read-only (get-oracle-fee)
  (var-get oracle-fee)
)

(define-read-only (get-min-premium)
  (var-get min-premium)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (calculate-premium (coverage-amount uint))
  (/ (* coverage-amount u10) u100)
)

(define-read-only (is-policy-expired (policy-id uint))
  (match (map-get? policies policy-id)
    policy (> stacks-block-height (get expiry-block policy))
    true
  )
)

(define-read-only (is-policy-claimable (policy-id uint))
  (match (map-get? policies policy-id)
    policy 
      (and 
        (not (get claimed policy))
        (< stacks-block-height (get expiry-block policy))
      )
    false
  )
)

(define-read-only (get-policy-status (policy-id uint))
  (match (map-get? policies policy-id)
    policy 
      (if (get claimed policy)
        "claimed"
        (if (> stacks-block-height (get expiry-block policy))
          "expired"
          "active"
        )
      )
    "not-found"
  )
)

(define-read-only (get-renewal-history (holder principal))
  (map-get? renewal-history holder)
)

(define-read-only (get-renewal-discount (holder principal))
  (let 
    (
      (renewal-record (map-get? renewal-history holder))
    )
    (match renewal-record
      record (calculate-renewal-discount (get total-renewals record) false)
      u0
    )
  )
)

(define-read-only (estimate-renewal-premium (policy-id uint))
  (match (map-get? policies policy-id)
    policy 
      (let 
        (
          (policy-holder (get policy-holder policy))
          (renewal-record (default-to 
            { total-renewals: u0, last-renewal-block: u0, policies-without-claims: u0 }
            (map-get? renewal-history policy-holder)
          ))
          (discount-rate (calculate-renewal-discount (get total-renewals renewal-record) (get claimed policy)))
          (base-premium (/ (* (get coverage-amount policy) u10) u100))
          (discounted-premium (- base-premium (/ (* base-premium discount-rate) u100)))
        )
        (some { base-premium: base-premium, discount-rate: discount-rate, final-premium: discounted-premium })
      )
    none
  )
)
