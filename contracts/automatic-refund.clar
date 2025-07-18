;; Automatic Refund Contract
;; Implements time-based and condition-based automatic refunds

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-REFUND (err u401))
(define-constant ERR-REFUND-NOT-FOUND (err u402))
(define-constant ERR-INSUFFICIENT-FUNDS (err u403))
(define-constant ERR-REFUND-EXPIRED (err u404))
(define-constant ERR-CONDITION-NOT-MET (err u405))
(define-constant ERR-ALREADY-PROCESSED (err u406))

;; Data Variables
(define-data-var next-refund-id uint u1)

;; Data Maps
(define-map refund-policies
  uint
  {
    escrow-id: uint,
    payer: principal,
    payee: principal,
    amount: uint,
    refund-type: (string-ascii 20), ;; "time-based", "condition-based", "emergency"
    trigger-block: uint,
    condition-met: bool,
    status: (string-ascii 20),
    created-at: uint,
    processed-at: (optional uint)
  }
)

(define-map refund-balances
  uint
  uint
)

(define-map refund-conditions
  uint
  {
    condition-type: (string-ascii 50),
    condition-value: uint,
    current-value: uint,
    operator: (string-ascii 10) ;; "eq", "gt", "lt", "gte", "lte"
  }
)

(define-map emergency-refund-requests
  uint
  {
    requester: principal,
    reason: (string-ascii 200),
    approved: bool,
    approver: (optional principal)
  }
)

;; Public Functions

;; Create a time-based refund policy
(define-public (create-time-based-refund
  (escrow-id uint)
  (payer principal)
  (payee principal)
  (amount uint)
  (refund-delay-blocks uint))
  (let
    ((refund-id (var-get next-refund-id))
     (trigger-block (+ block-height refund-delay-blocks)))

    ;; Validate inputs
    (asserts! (not (is-eq payer payee)) ERR-INVALID-REFUND)
    (asserts! (> amount u0) ERR-INVALID-REFUND)
    (asserts! (> refund-delay-blocks u0) ERR-INVALID-REFUND)

    ;; Store refund policy
    (map-set refund-policies refund-id
      {
        escrow-id: escrow-id,
        payer: payer,
        payee: payee,
        amount: amount,
        refund-type: "time-based",
        trigger-block: trigger-block,
        condition-met: false,
        status: "active",
        created-at: block-height,
        processed-at: none
      })

    ;; Initialize balance
    (map-set refund-balances refund-id u0)

    ;; Increment next ID
    (var-set next-refund-id (+ refund-id u1))

    (ok refund-id)))

;; Create a condition-based refund policy
(define-public (create-condition-based-refund
  (escrow-id uint)
  (payer principal)
  (payee principal)
  (amount uint)
  (condition-type (string-ascii 50))
  (condition-value uint)
  (operator (string-ascii 10))
  (max-wait-blocks uint))
  (let
    ((refund-id (var-get next-refund-id))
     (trigger-block (+ block-height max-wait-blocks)))

    ;; Validate inputs
    (asserts! (not (is-eq payer payee)) ERR-INVALID-REFUND)
    (asserts! (> amount u0) ERR-INVALID-REFUND)
    (asserts! (> max-wait-blocks u0) ERR-INVALID-REFUND)

    ;; Store refund policy
    (map-set refund-policies refund-id
      {
        escrow-id: escrow-id,
        payer: payer,
        payee: payee,
        amount: amount,
        refund-type: "condition-based",
        trigger-block: trigger-block,
        condition-met: false,
        status: "active",
        created-at: block-height,
        processed-at: none
      })

    ;; Store condition details
    (map-set refund-conditions refund-id
      {
        condition-type: condition-type,
        condition-value: condition-value,
        current-value: u0,
        operator: operator
      })

    ;; Initialize balance
    (map-set refund-balances refund-id u0)

    ;; Increment next ID
    (var-set next-refund-id (+ refund-id u1))

    (ok refund-id)))

;; Fund a refund policy
(define-public (fund-refund (refund-id uint) (amount uint))
  (let
    ((refund-policy (unwrap! (map-get? refund-policies refund-id) ERR-REFUND-NOT-FOUND))
     (current-balance (default-to u0 (map-get? refund-balances refund-id))))

    ;; Validate caller is payer
    (asserts! (is-eq tx-sender (get payer refund-policy)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status refund-policy) "active") ERR-INVALID-REFUND)

    ;; Transfer funds
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update balance
    (map-set refund-balances refund-id (+ current-balance amount))

    (ok true)))

;; Process automatic refund (time-based)
(define-public (process-time-refund (refund-id uint))
  (let
    ((refund-policy (unwrap! (map-get? refund-policies refund-id) ERR-REFUND-NOT-FOUND))
     (current-balance (default-to u0 (map-get? refund-balances refund-id))))

    ;; Validate refund conditions
    (asserts! (is-eq (get refund-type refund-policy) "time-based") ERR-INVALID-REFUND)
    (asserts! (>= block-height (get trigger-block refund-policy)) ERR-CONDITION-NOT-MET)
    (asserts! (is-eq (get status refund-policy) "active") ERR-ALREADY-PROCESSED)
    (asserts! (>= current-balance (get amount refund-policy)) ERR-INSUFFICIENT-FUNDS)

    ;; Process refund
    (try! (as-contract (stx-transfer? (get amount refund-policy) tx-sender (get payer refund-policy))))

    ;; Update policy status
    (map-set refund-policies refund-id
      (merge refund-policy {
        status: "processed",
        processed-at: (some block-height)
      }))

    ;; Update balance
    (map-set refund-balances refund-id (- current-balance (get amount refund-policy)))

    (ok true)))

;; Update condition value for condition-based refunds
(define-public (update-condition-value (refund-id uint) (new-value uint))
  (let
    ((refund-policy (unwrap! (map-get? refund-policies refund-id) ERR-REFUND-NOT-FOUND))
     (condition (unwrap! (map-get? refund-conditions refund-id) ERR-REFUND-NOT-FOUND)))

    ;; Only contract owner or authorized oracle can update
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get refund-type refund-policy) "condition-based") ERR-INVALID-REFUND)
    (asserts! (is-eq (get status refund-policy) "active") ERR-ALREADY-PROCESSED)

    ;; Update condition value
    (map-set refund-conditions refund-id
      (merge condition {current-value: new-value}))

    ;; Check if condition is now met
    (let ((condition-met (evaluate-condition condition new-value)))
      (if condition-met
        (begin
          ;; Mark condition as met
          (map-set refund-policies refund-id
            (merge refund-policy {condition-met: true}))
          ;; Automatically process refund
          (process-condition-refund refund-id))
        (ok true)))))

;; Process condition-based refund
(define-private (process-condition-refund (refund-id uint))
  (let
    ((refund-policy (unwrap! (map-get? refund-policies refund-id) ERR-REFUND-NOT-FOUND))
     (current-balance (default-to u0 (map-get? refund-balances refund-id))))

    ;; Validate conditions
    (asserts! (get condition-met refund-policy) ERR-CONDITION-NOT-MET)
    (asserts! (>= current-balance (get amount refund-policy)) ERR-INSUFFICIENT-FUNDS)

    ;; Process refund
    (try! (as-contract (stx-transfer? (get amount refund-policy) tx-sender (get payer refund-policy))))

    ;; Update policy status
    (map-set refund-policies refund-id
      (merge refund-policy {
        status: "processed",
        processed-at: (some block-height)
      }))

    ;; Update balance
    (map-set refund-balances refund-id (- current-balance (get amount refund-policy)))

    (ok true)))

;; Evaluate if condition is met
(define-private (evaluate-condition (condition {condition-type: (string-ascii 50), condition-value: uint, current-value: uint, operator: (string-ascii 10)}) (current-value uint))
  (let ((operator (get operator condition))
        (target-value (get condition-value condition)))
    (if (is-eq operator "eq")
      (is-eq current-value target-value)
      (if (is-eq operator "gt")
        (> current-value target-value)
        (if (is-eq operator "lt")
          (< current-value target-value)
          (if (is-eq operator "gte")
            (>= current-value target-value)
            (if (is-eq operator "lte")
              (<= current-value target-value)
              false)))))))

;; Request emergency refund
(define-public (request-emergency-refund (refund-id uint) (reason (string-ascii 200)))
  (let
    ((refund-policy (unwrap! (map-get? refund-policies refund-id) ERR-REFUND-NOT-FOUND)))

    ;; Validate caller is involved in the refund
    (asserts! (or (is-eq tx-sender (get payer refund-policy))
                  (is-eq tx-sender (get payee refund-policy))) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status refund-policy) "active") ERR-ALREADY-PROCESSED)

    ;; Store emergency request
    (map-set emergency-refund-requests refund-id
      {
        requester: tx-sender,
        reason: reason,
        approved: false,
        approver: none
      })

    (ok true)))

;; Approve emergency refund (contract owner only)
(define-public (approve-emergency-refund (refund-id uint))
  (let
    ((refund-policy (unwrap! (map-get? refund-policies refund-id) ERR-REFUND-NOT-FOUND))
     (emergency-request (unwrap! (map-get? emergency-refund-requests refund-id) ERR-REFUND-NOT-FOUND))
     (current-balance (default-to u0 (map-get? refund-balances refund-id))))

    ;; Only contract owner can approve
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (get approved emergency-request)) ERR-ALREADY-PROCESSED)
    (asserts! (>= current-balance (get amount refund-policy)) ERR-INSUFFICIENT-FUNDS)

    ;; Approve request
    (map-set emergency-refund-requests refund-id
      (merge emergency-request {
        approved: true,
        approver: (some tx-sender)
      }))

    ;; Process emergency refund
    (try! (as-contract (stx-transfer? (get amount refund-policy) tx-sender (get payer refund-policy))))

    ;; Update policy status
    (map-set refund-policies refund-id
      (merge refund-policy {
        status: "emergency-processed",
        processed-at: (some block-height)
      }))

    ;; Update balance
    (map-set refund-balances refund-id (- current-balance (get amount refund-policy)))

    (ok true)))

;; Cancel refund policy (payer only, before processing)
(define-public (cancel-refund (refund-id uint))
  (let
    ((refund-policy (unwrap! (map-get? refund-policies refund-id) ERR-REFUND-NOT-FOUND))
     (current-balance (default-to u0 (map-get? refund-balances refund-id))))

    ;; Only payer can cancel
    (asserts! (is-eq tx-sender (get payer refund-policy)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status refund-policy) "active") ERR-ALREADY-PROCESSED)

    ;; Update status
    (map-set refund-policies refund-id
      (merge refund-policy {status: "cancelled"}))

    ;; Return any deposited funds
    (if (> current-balance u0)
      (begin
        (try! (as-contract (stx-transfer? current-balance tx-sender (get payer refund-policy))))
        (map-set refund-balances refund-id u0)
        (ok true))
      (ok true))))

;; Read-only functions

(define-read-only (get-refund-policy (refund-id uint))
  (map-get? refund-policies refund-id))

(define-read-only (get-refund-balance (refund-id uint))
  (default-to u0 (map-get? refund-balances refund-id)))

(define-read-only (get-refund-condition (refund-id uint))
  (map-get? refund-conditions refund-id))

(define-read-only (get-emergency-request (refund-id uint))
  (map-get? emergency-refund-requests refund-id))

(define-read-only (get-next-refund-id)
  (var-get next-refund-id))

(define-read-only (is-refund-ready (refund-id uint))
  (match (map-get? refund-policies refund-id)
    refund-policy
      (if (is-eq (get refund-type refund-policy) "time-based")
        (>= block-height (get trigger-block refund-policy))
        (get condition-met refund-policy))
    false))
