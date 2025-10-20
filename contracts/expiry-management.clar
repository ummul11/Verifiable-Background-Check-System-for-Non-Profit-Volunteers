;; Title: Expiry Management Contract
;; Description: Centralized expiry tracking and management for attestations and access grants
;; Version: 1.0.0
;; Author: Verifiable Background Check System
;; License: MIT

;; This contract provides centralized expiry management functionality for the entire system,
;; enabling efficient tracking of expired attestations and grants, and providing utilities
;; for batch expiry checks and cleanup operations.

;; ===== CONSTANTS =====

;; Contract owner (deployer)
(define-constant contract-owner tx-sender)

;; Error codes - Authorization (100-199)
(define-constant err-unauthorized (err u100))
(define-constant err-not-contract-owner (err u101))

;; Error codes - Validation (200-299)
(define-constant err-invalid-expiry-time (err u200))
(define-constant err-invalid-item-id (err u201))
(define-constant err-invalid-item-type (err u202))
(define-constant err-item-not-found (err u203))

;; Error codes - Business Logic (300-399)
(define-constant err-already-expired (err u300))
(define-constant err-not-expired (err u301))

;; Item types for expiry tracking
(define-constant item-type-attestation "attestation")
(define-constant item-type-grant "grant")

;; Time constants (in blocks)
(define-constant blocks-per-day u144)
(define-constant blocks-per-week u1008)
(define-constant blocks-per-month u4380)
(define-constant blocks-per-year u52560)

;; ===== DATA STRUCTURES =====

;; Track expiry items by block height for efficient querying
(define-map expiry-schedule uint (list 100 { item-type: (string-ascii 20), item-id: uint }))

;; Track individual item expiry details
(define-map item-expiry { item-type: (string-ascii 20), item-id: uint } {
  expiry-height: uint,
  created-at: uint,
  is-expired: bool
})

;; Counter for tracking total items
(define-data-var total-tracked-items uint u0)

;; ===== PRIVATE FUNCTIONS =====

;; Validate item type
(define-private (is-valid-item-type (item-type (string-ascii 20)))
  (or 
    (is-eq item-type item-type-attestation)
    (is-eq item-type item-type-grant)
  )
)

;; Validate expiry time is in the future
(define-private (is-valid-expiry-time (expiry-height uint))
  (> expiry-height stacks-block-height)
)

;; Add item to expiry schedule at specific block height
(define-private (add-to-expiry-schedule (expiry-height uint) (item-type (string-ascii 20)) (item-id uint))
  (let ((current-list (default-to (list) (map-get? expiry-schedule expiry-height))))
    (map-set expiry-schedule expiry-height
      (unwrap! (as-max-len? (append current-list { item-type: item-type, item-id: item-id }) u100) (err u999))
    )
    (ok true)
  )
)

;; ===== READ-ONLY FUNCTIONS =====

;; Get expiry information for a specific item
(define-read-only (get-item-expiry (item-type (string-ascii 20)) (item-id uint))
  (map-get? item-expiry { item-type: item-type, item-id: item-id })
)

;; Check if an item is expired
(define-read-only (is-item-expired (item-type (string-ascii 20)) (item-id uint))
  (match (get-item-expiry item-type item-id)
    expiry-data 
      (or 
        (get is-expired expiry-data)
        (>= stacks-block-height (get expiry-height expiry-data))
      )
    false
  )
)

;; Check if an item is still valid (not expired)
(define-read-only (is-item-valid (item-type (string-ascii 20)) (item-id uint))
  (not (is-item-expired item-type item-id))
)

;; Get all items expiring at a specific block height
(define-read-only (get-items-expiring-at (expiry-block uint))
  (default-to (list) (map-get? expiry-schedule expiry-block))
)

;; Get time until expiry for an item (in blocks)
(define-read-only (get-time-until-expiry (item-type (string-ascii 20)) (item-id uint))
  (match (get-item-expiry item-type item-id)
    expiry-data
      (if (>= stacks-block-height (get expiry-height expiry-data))
        (some u0)
        (some (- (get expiry-height expiry-data) stacks-block-height))
      )
    none
  )
)

;; Check if item will expire within specified blocks
(define-read-only (will-expire-within (item-type (string-ascii 20)) (item-id uint) (blocks uint))
  (match (get-time-until-expiry item-type item-id)
    time-left (<= time-left blocks)
    false
  )
)

;; Get total tracked items
(define-read-only (get-total-tracked-items)
  (var-get total-tracked-items)
)

;; Get contract information
(define-read-only (get-contract-info)
  {
    name: "ExpiryManagement",
    version: "1.0.0",
    owner: contract-owner,
    total-tracked-items: (var-get total-tracked-items),
    current-block-height: stacks-block-height
  }
)

;; Calculate expiry time from current block with duration
(define-read-only (calculate-expiry-from-now (duration-blocks uint))
  (+ stacks-block-height duration-blocks)
)

;; Batch check if multiple attestations are valid
(define-read-only (batch-check-attestations-valid (attestation-ids (list 50 uint)))
  (map check-attestation-valid attestation-ids)
)

;; Helper for batch check
(define-private (check-attestation-valid (attestation-id uint))
  { 
    attestation-id: attestation-id, 
    is-valid: (is-item-valid item-type-attestation attestation-id) 
  }
)

;; Batch check if multiple grants are valid
(define-read-only (batch-check-grants-valid (grant-ids (list 100 uint)))
  (map check-grant-valid grant-ids)
)

;; Helper for batch check
(define-private (check-grant-valid (grant-id uint))
  { 
    grant-id: grant-id, 
    is-valid: (is-item-valid item-type-grant grant-id) 
  }
)

;; ===== PUBLIC FUNCTIONS =====

;; Register an item for expiry tracking
;; @param item-type: Type of item (attestation or grant)
;; @param item-id: ID of the item
;; @param expiry-height: Block height when item expires
;; @returns: (response bool uint) - success or error code
(define-public (register-expiry (item-type (string-ascii 20)) (item-id uint) (expiry-height uint))
  (begin
    ;; Validation checks
    (asserts! (is-valid-item-type item-type) err-invalid-item-type)
    (asserts! (> item-id u0) err-invalid-item-id)
    (asserts! (is-valid-expiry-time expiry-height) err-invalid-expiry-time)
    
    ;; Create expiry record
    (map-set item-expiry { item-type: item-type, item-id: item-id } {
      expiry-height: expiry-height,
      created-at: stacks-block-height,
      is-expired: false
    })
    
    ;; Add to expiry schedule
    (try! (add-to-expiry-schedule expiry-height item-type item-id))
    
    ;; Increment counter
    (var-set total-tracked-items (+ (var-get total-tracked-items) u1))
    
    ;; Emit event
    (print {
      event: "expiry-registered",
      item-type: item-type,
      item-id: item-id,
      expiry-height: expiry-height,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; Mark an item as expired (can be called by anyone once expiry time is reached)
;; @param item-type: Type of item
;; @param item-id: ID of the item
;; @returns: (response bool uint) - success or error code
(define-public (mark-as-expired (item-type (string-ascii 20)) (item-id uint))
  (let ((expiry-data (unwrap! (get-item-expiry item-type item-id) err-item-not-found)))
    ;; Check that expiry time has been reached
    (asserts! (>= stacks-block-height (get expiry-height expiry-data)) err-not-expired)
    (asserts! (not (get is-expired expiry-data)) err-already-expired)
    
    ;; Update expiry status
    (map-set item-expiry { item-type: item-type, item-id: item-id }
      (merge expiry-data { is-expired: true })
    )
    
    ;; Emit event
    (print {
      event: "item-marked-expired",
      item-type: item-type,
      item-id: item-id,
      expiry-height: (get expiry-height expiry-data),
      marked-at: stacks-block-height
    })
    
    (ok true)
  )
)

;; Update expiry time for an item (contract owner only, for emergency adjustments)
;; @param item-type: Type of item
;; @param item-id: ID of the item
;; @param new-expiry-height: New expiry block height
;; @returns: (response bool uint) - success or error code
(define-public (update-expiry (item-type (string-ascii 20)) (item-id uint) (new-expiry-height uint))
  (let ((expiry-data (unwrap! (get-item-expiry item-type item-id) err-item-not-found)))
    ;; Only contract owner can update expiry
    (asserts! (is-eq contract-caller contract-owner) err-not-contract-owner)
    (asserts! (is-valid-expiry-time new-expiry-height) err-invalid-expiry-time)
    
    ;; Update expiry height
    (map-set item-expiry { item-type: item-type, item-id: item-id }
      (merge expiry-data { 
        expiry-height: new-expiry-height,
        is-expired: false
      })
    )
    
    ;; Emit event
    (print {
      event: "expiry-updated",
      item-type: item-type,
      item-id: item-id,
      old-expiry-height: (get expiry-height expiry-data),
      new-expiry-height: new-expiry-height,
      updated-at: stacks-block-height
    })
    
    (ok true)
  )
)

