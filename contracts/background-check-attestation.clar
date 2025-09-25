;; Title: Background Check Attestation Contract
;; Description: Allow accredited providers to publish cryptographic attestations of completed checks for volunteers
;; Version: 1.0.0
;; Author: Verifiable Background Check System
;; License: MIT

;; This contract provides immutable, time-bound verification records while keeping 
;; sensitive details off-chain, ensuring transparency and privacy.

;; ===== CONSTANTS =====

;; Contract owner (deployer)
(define-constant contract-owner tx-sender)

;; Error codes - Authorization (100-199)
(define-constant err-unauthorized (err u100))
(define-constant err-not-verified-provider (err u101))

;; Error codes - Validation (200-299)
(define-constant err-invalid-volunteer-id (err u200))
(define-constant err-invalid-provider-id (err u201))
(define-constant err-invalid-check-type (err u202))
(define-constant err-invalid-status (err u203))
(define-constant err-invalid-validity-period (err u204))
(define-constant err-attestation-not-found (err u205))

;; Error codes - Business Logic (300-399)
(define-constant err-volunteer-not-registered (err u300))
(define-constant err-provider-not-verified (err u301))
(define-constant err-attestation-expired (err u302))

;; Maximum string lengths for validation
(define-constant max-check-type-length u50)
(define-constant max-status-length u20)

;; Valid check types
(define-constant check-type-criminal "criminal")
(define-constant check-type-employment "employment")
(define-constant check-type-education "education")
(define-constant check-type-reference "reference")

;; Valid status values
(define-constant status-passed "passed")
(define-constant status-failed "failed")
(define-constant status-pending "pending")

;; Maximum validity period (in blocks) - approximately 1 year
(define-constant max-validity-blocks u52560)

;; ===== DATA STRUCTURES =====

;; Auto-incrementing attestation ID counter
(define-data-var attestation-counter uint u0)

;; Map attestation ID to attestation data
(define-map attestations uint {
  volunteer-id: uint,
  provider-id: uint,
  check-type: (string-ascii 50),
  status: (string-ascii 20),
  issued-at: uint,
  valid-until: uint,
  issued-by: principal
})

;; Map volunteer ID to list of their attestation IDs
(define-map volunteer-attestations uint (list 50 uint))

;; Map provider ID to list of attestations they issued
(define-map provider-attestations uint (list 100 uint))

;; ===== PRIVATE FUNCTIONS =====

;; Validate check type
(define-private (is-valid-check-type (check-type (string-ascii 50)))
  (or 
    (is-eq check-type check-type-criminal)
    (is-eq check-type check-type-employment)
    (is-eq check-type check-type-education)
    (is-eq check-type check-type-reference)
  )
)

;; Validate status
(define-private (is-valid-status (status (string-ascii 20)))
  (or 
    (is-eq status status-passed)
    (is-eq status status-failed)
    (is-eq status status-pending)
  )
)

;; Validate validity period
(define-private (is-valid-validity-period (valid-until uint))
  (and 
    (> valid-until stacks-block-height)
    (<= (- valid-until stacks-block-height) max-validity-blocks)
  )
)

;; Generate next attestation ID
(define-private (get-next-attestation-id)
  (let ((current-id (var-get attestation-counter)))
    (var-set attestation-counter (+ current-id u1))
    (+ current-id u1)
  )
)

;; Add attestation to volunteer's list
(define-private (add-to-volunteer-attestations (volunteer-id uint) (attestation-id uint))
  (let ((current-list (default-to (list) (map-get? volunteer-attestations volunteer-id))))
    (map-set volunteer-attestations volunteer-id
      (unwrap! (as-max-len? (append current-list attestation-id) u50) (err u999))
    )
    (ok true)
  )
)

;; Add attestation to provider's list
(define-private (add-to-provider-attestations (provider-id uint) (attestation-id uint))
  (let ((current-list (default-to (list) (map-get? provider-attestations provider-id))))
    (map-set provider-attestations provider-id
      (unwrap! (as-max-len? (append current-list attestation-id) u100) (err u999))
    )
    (ok true)
  )
)

;; ===== READ-ONLY FUNCTIONS =====

;; Get attestation data by ID
(define-read-only (get-attestation (attestation-id uint))
  (map-get? attestations attestation-id)
)

;; Check if attestation exists and is still valid (not expired)
(define-read-only (is-valid-attestation (attestation-id uint))
  (match (map-get? attestations attestation-id)
    attestation-data (> (get valid-until attestation-data) stacks-block-height)
    false
  )
)

;; Get all attestation IDs for a volunteer
(define-read-only (get-volunteer-attestations (volunteer-id uint))
  (default-to (list) (map-get? volunteer-attestations volunteer-id))
)

;; Get all attestation IDs issued by a provider
(define-read-only (get-provider-attestations (provider-id uint))
  (default-to (list) (map-get? provider-attestations provider-id))
)

;; Get current attestation counter
(define-read-only (get-attestation-counter)
  (var-get attestation-counter)
)

;; Get contract information
(define-read-only (get-contract-info)
  {
    name: "BackgroundCheckAttestation",
    version: "1.0.0",
    owner: contract-owner,
    total-attestations: (var-get attestation-counter)
  }
)

;; Get valid attestations for a volunteer (non-expired only)
(define-read-only (get-valid-volunteer-attestations (volunteer-id uint))
  (filter is-valid-attestation (get-volunteer-attestations volunteer-id))
)

;; ===== PUBLIC FUNCTIONS =====

;; Issue a new background check attestation (verified providers only)
;; @param volunteer-id: ID of the volunteer being attested
;; @param check-type: Type of background check performed
;; @param status: Result status of the check
;; @param valid-until: Block height when attestation expires
;; @returns: (response uint uint) - success with attestation ID or error code
(define-public (issue-attestation (volunteer-id uint) (check-type (string-ascii 50)) (status (string-ascii 20)) (valid-until uint))
  (let ((attestation-id (get-next-attestation-id)))
    ;; Get provider ID for the caller
    (let ((provider-id (unwrap! (contract-call? .provider-registry get-provider-by-principal contract-caller) err-invalid-provider-id)))
      ;; Validation checks
      (asserts! (contract-call? .volunteer-registry is-registered volunteer-id) err-volunteer-not-registered)
      (asserts! (contract-call? .provider-registry is-verified-provider provider-id) err-not-verified-provider)
      (asserts! (is-valid-check-type check-type) err-invalid-check-type)
      (asserts! (is-valid-status status) err-invalid-status)
      (asserts! (is-valid-validity-period valid-until) err-invalid-validity-period)
      
      ;; Create attestation record
      (map-set attestations attestation-id {
        volunteer-id: volunteer-id,
        provider-id: provider-id,
        check-type: check-type,
        status: status,
        issued-at: stacks-block-height,
        valid-until: valid-until,
        issued-by: contract-caller
      })
      
      ;; Add to volunteer and provider lists
      (try! (add-to-volunteer-attestations volunteer-id attestation-id))
      (try! (add-to-provider-attestations provider-id attestation-id))
      
      ;; Emit attestation issued event
      (print {
        event: "attestation-issued",
        attestation-id: attestation-id,
        volunteer-id: volunteer-id,
        provider-id: provider-id,
        check-type: check-type,
        status: status,
        valid-until: valid-until,
        issued-by: contract-caller,
        block-height: stacks-block-height
      })
      
      (ok attestation-id)
    )
  )
)

;; Revoke an attestation (provider who issued it only)
;; @param attestation-id: ID of attestation to revoke
;; @returns: (response bool uint) - success or error code
(define-public (revoke-attestation (attestation-id uint))
  (let ((attestation-data (unwrap! (get-attestation attestation-id) err-attestation-not-found)))
    ;; Only the provider who issued the attestation can revoke it
    (asserts! (is-eq (get issued-by attestation-data) contract-caller) err-unauthorized)
    
    ;; Mark attestation as expired by setting valid-until to current block
    (map-set attestations attestation-id (merge attestation-data { valid-until: stacks-block-height }))
    
    ;; Emit attestation revoked event
    (print {
      event: "attestation-revoked",
      attestation-id: attestation-id,
      volunteer-id: (get volunteer-id attestation-data),
      provider-id: (get provider-id attestation-data),
      revoked-by: contract-caller,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)
