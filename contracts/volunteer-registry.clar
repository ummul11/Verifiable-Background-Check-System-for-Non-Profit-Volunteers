;; Title: Volunteer Registry Contract
;; Description: Register volunteers on-chain with minimal metadata (unique ID, hash of personal data)
;; Version: 1.0.0
;; Author: Verifiable Background Check System
;; License: MIT

;; This contract establishes a tamper-proof identity anchor for volunteers 
;; without exposing sensitive personal data on-chain.

;; ===== CONSTANTS =====

;; Contract owner (deployer)
(define-constant contract-owner tx-sender)

;; Error codes - Authorization (100-199)
(define-constant err-unauthorized (err u100))
(define-constant err-not-contract-owner (err u101))

;; Error codes - Validation (200-299)
(define-constant err-invalid-hashed-identity (err u200))
(define-constant err-invalid-metadata-length (err u201))
(define-constant err-volunteer-not-found (err u202))
(define-constant err-volunteer-already-registered (err u203))

;; Error codes - Business Logic (300-399)
(define-constant err-registration-failed (err u300))

;; Maximum string lengths for validation
(define-constant max-hashed-identity-length u128)
(define-constant max-metadata-length u500)

;; ===== DATA STRUCTURES =====

;; Auto-incrementing volunteer ID counter
(define-data-var volunteer-counter uint u0)

;; Map volunteer ID to volunteer data
(define-map volunteers uint {
  hashed-identity: (string-ascii 128),
  registered: bool,
  metadata: (string-utf8 500),
  registered-at: uint,
  registered-by: principal
})

;; Map principal to volunteer ID for reverse lookup
(define-map volunteer-principals principal uint)

;; ===== PRIVATE FUNCTIONS =====

;; Validate hashed identity format and length
(define-private (is-valid-hashed-identity (hashed-identity (string-ascii 128)))
  (and 
    (> (len hashed-identity) u0)
    (<= (len hashed-identity) max-hashed-identity-length)
  )
)

;; Validate metadata length
(define-private (is-valid-metadata (metadata (string-utf8 500)))
  (<= (len metadata) max-metadata-length)
)

;; Check if volunteer is already registered by principal
(define-private (is-principal-registered (volunteer-principal principal))
  (is-some (map-get? volunteer-principals volunteer-principal))
)

;; Generate next volunteer ID
(define-private (get-next-volunteer-id)
  (let ((current-id (var-get volunteer-counter)))
    (var-set volunteer-counter (+ current-id u1))
    (+ current-id u1)
  )
)

;; ===== READ-ONLY FUNCTIONS =====

;; Get volunteer data by ID
(define-read-only (get-volunteer (volunteer-id uint))
  (map-get? volunteers volunteer-id)
)

;; Check if volunteer ID exists and is registered
(define-read-only (is-registered (volunteer-id uint))
  (match (map-get? volunteers volunteer-id)
    volunteer-data (get registered volunteer-data)
    false
  )
)

;; Get volunteer ID by principal address
(define-read-only (get-volunteer-by-principal (volunteer-principal principal))
  (map-get? volunteer-principals volunteer-principal)
)

;; Get volunteer ID for the calling principal
(define-read-only (get-volunteer-by-caller)
  (get-volunteer-by-principal contract-caller)
)

;; Get current volunteer counter
(define-read-only (get-volunteer-counter)
  (var-get volunteer-counter)
)

;; Get contract information
(define-read-only (get-contract-info)
  {
    name: "VolunteerRegistry",
    version: "1.0.0",
    owner: contract-owner,
    total-volunteers: (var-get volunteer-counter)
  }
)

;; ===== PUBLIC FUNCTIONS =====

;; Register a new volunteer
;; @param hashed-identity: Hash of volunteer's personal data (not raw data)
;; @param metadata: Additional metadata about the volunteer
;; @returns: (response uint uint) - success with volunteer ID or error code
(define-public (register-volunteer (hashed-identity (string-ascii 128)) (metadata (string-utf8 500)))
  (let ((volunteer-id (get-next-volunteer-id)))
    ;; Validation checks
    (asserts! (is-valid-hashed-identity hashed-identity) err-invalid-hashed-identity)
    (asserts! (is-valid-metadata metadata) err-invalid-metadata-length)
    (asserts! (not (is-principal-registered contract-caller)) err-volunteer-already-registered)
    
    ;; Create volunteer record
    (map-set volunteers volunteer-id {
      hashed-identity: hashed-identity,
      registered: true,
      metadata: metadata,
      registered-at: stacks-block-height,
      registered-by: contract-caller
    })
    
    ;; Create reverse lookup mapping
    (map-set volunteer-principals contract-caller volunteer-id)
    
    ;; Emit registration event
    (print {
      event: "volunteer-registered",
      volunteer-id: volunteer-id,
      hashed-identity: hashed-identity,
      registered-by: contract-caller,
      block-height: stacks-block-height
    })
    
    (ok volunteer-id)
  )
)

;; Update volunteer metadata (only by the volunteer themselves)
;; @param metadata: New metadata for the volunteer
;; @returns: (response bool uint) - success or error code
(define-public (update-volunteer-metadata (metadata (string-utf8 500)))
  (let ((volunteer-id (unwrap! (get-volunteer-by-caller) err-volunteer-not-found)))
    (let ((current-data (unwrap! (get-volunteer volunteer-id) err-volunteer-not-found)))
      ;; Validation checks
      (asserts! (is-valid-metadata metadata) err-invalid-metadata-length)
      (asserts! (is-eq (get registered-by current-data) contract-caller) err-unauthorized)
      
      ;; Update volunteer record
      (map-set volunteers volunteer-id (merge current-data { metadata: metadata }))
      
      ;; Emit update event
      (print {
        event: "volunteer-metadata-updated",
        volunteer-id: volunteer-id,
        updated-by: contract-caller,
        block-height: stacks-block-height
      })
      
      (ok true)
    )
  )
)

;; Administrative function to deactivate a volunteer (emergency use only)
;; @param volunteer-id: ID of volunteer to deactivate
;; @returns: (response bool uint) - success or error code
(define-public (deactivate-volunteer (volunteer-id uint))
  (let ((current-data (unwrap! (get-volunteer volunteer-id) err-volunteer-not-found)))
    ;; Only contract owner can deactivate
    (asserts! (is-eq contract-caller contract-owner) err-not-contract-owner)
    
    ;; Update registration status
    (map-set volunteers volunteer-id (merge current-data { registered: false }))
    
    ;; Emit deactivation event
    (print {
      event: "volunteer-deactivated",
      volunteer-id: volunteer-id,
      deactivated-by: contract-caller,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)
