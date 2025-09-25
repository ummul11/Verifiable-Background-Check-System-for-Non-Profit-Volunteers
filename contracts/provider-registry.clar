;; Title: Provider Registry Contract
;; Description: Maintain a whitelist of accredited background check providers authorized to issue verifications
;; Version: 1.0.0
;; Author: Verifiable Background Check System
;; License: MIT

;; This contract ensures only trusted, verified agencies can issue background check attestations,
;; preventing fraudulent claims and maintaining system integrity.

;; ===== CONSTANTS =====

;; Contract owner (deployer)
(define-constant contract-owner tx-sender)

;; Error codes - Authorization (100-199)
(define-constant err-unauthorized (err u100))
(define-constant err-not-contract-owner (err u101))

;; Error codes - Validation (200-299)
(define-constant err-invalid-provider-name (err u200))
(define-constant err-invalid-metadata-length (err u201))
(define-constant err-provider-not-found (err u202))
(define-constant err-provider-already-exists (err u203))
(define-constant err-invalid-provider-id (err u204))

;; Error codes - Business Logic (300-399)
(define-constant err-provider-not-verified (err u300))
(define-constant err-provider-already-verified (err u301))

;; Maximum string lengths for validation
(define-constant max-provider-name-length u100)
(define-constant max-metadata-length u500)

;; ===== DATA STRUCTURES =====

;; Auto-incrementing provider ID counter
(define-data-var provider-counter uint u0)

;; Map provider ID to provider data
(define-map providers uint {
  name: (string-ascii 100),
  verified: bool,
  metadata: (string-utf8 500),
  added-at: uint,
  added-by: principal,
  verified-at: (optional uint),
  verified-by: (optional principal)
})

;; Map provider name to provider ID for uniqueness check
(define-map provider-names (string-ascii 100) uint)

;; Map principal to provider ID for reverse lookup
(define-map provider-principals principal uint)

;; ===== PRIVATE FUNCTIONS =====

;; Validate provider name format and length
(define-private (is-valid-provider-name (name (string-ascii 100)))
  (and 
    (> (len name) u0)
    (<= (len name) max-provider-name-length)
  )
)

;; Validate metadata length
(define-private (is-valid-metadata (metadata (string-utf8 500)))
  (<= (len metadata) max-metadata-length)
)

;; Check if provider name already exists
(define-private (is-provider-name-taken (name (string-ascii 100)))
  (is-some (map-get? provider-names name))
)

;; Generate next provider ID
(define-private (get-next-provider-id)
  (let ((current-id (var-get provider-counter)))
    (var-set provider-counter (+ current-id u1))
    (+ current-id u1)
  )
)

;; ===== READ-ONLY FUNCTIONS =====

;; Get provider data by ID
(define-read-only (get-provider (provider-id uint))
  (map-get? providers provider-id)
)

;; Check if provider ID exists and is verified
(define-read-only (is-verified-provider (provider-id uint))
  (match (map-get? providers provider-id)
    provider-data (get verified provider-data)
    false
  )
)

;; Get provider ID by name
(define-read-only (get-provider-by-name (name (string-ascii 100)))
  (map-get? provider-names name)
)

;; Get provider ID by principal address
(define-read-only (get-provider-by-principal (provider-principal principal))
  (map-get? provider-principals provider-principal)
)

;; Get current provider counter
(define-read-only (get-provider-counter)
  (var-get provider-counter)
)

;; Get contract information
(define-read-only (get-contract-info)
  {
    name: "ProviderRegistry",
    version: "1.0.0",
    owner: contract-owner,
    total-providers: (var-get provider-counter)
  }
)

;; Check if a principal is a verified provider
(define-read-only (is-caller-verified-provider)
  (match (get-provider-by-principal contract-caller)
    provider-id (is-verified-provider provider-id)
    false
  )
)

;; ===== PUBLIC FUNCTIONS =====

;; Add a new background check provider (admin only)
;; @param name: Name of the provider organization
;; @param metadata: Additional information about the provider
;; @param provider-principal: Principal address of the provider
;; @returns: (response uint uint) - success with provider ID or error code
(define-public (add-provider (name (string-ascii 100)) (metadata (string-utf8 500)) (provider-principal principal))
  (let ((provider-id (get-next-provider-id)))
    ;; Only contract owner can add providers
    (asserts! (is-eq contract-caller contract-owner) err-not-contract-owner)
    
    ;; Validation checks
    (asserts! (is-valid-provider-name name) err-invalid-provider-name)
    (asserts! (is-valid-metadata metadata) err-invalid-metadata-length)
    (asserts! (not (is-provider-name-taken name)) err-provider-already-exists)
    
    ;; Create provider record (initially unverified)
    (map-set providers provider-id {
      name: name,
      verified: false,
      metadata: metadata,
      added-at: stacks-block-height,
      added-by: contract-caller,
      verified-at: none,
      verified-by: none
    })
    
    ;; Create name and principal mappings
    (map-set provider-names name provider-id)
    (map-set provider-principals provider-principal provider-id)
    
    ;; Emit provider added event
    (print {
      event: "provider-added",
      provider-id: provider-id,
      name: name,
      provider-principal: provider-principal,
      added-by: contract-caller,
      block-height: stacks-block-height
    })
    
    (ok provider-id)
  )
)

;; Verify a provider (admin only)
;; @param provider-id: ID of provider to verify
;; @returns: (response bool uint) - success or error code
(define-public (verify-provider (provider-id uint))
  (let ((current-data (unwrap! (get-provider provider-id) err-provider-not-found)))
    ;; Only contract owner can verify providers
    (asserts! (is-eq contract-caller contract-owner) err-not-contract-owner)
    (asserts! (not (get verified current-data)) err-provider-already-verified)
    
    ;; Update provider verification status
    (map-set providers provider-id (merge current-data {
      verified: true,
      verified-at: (some stacks-block-height),
      verified-by: (some contract-caller)
    }))
    
    ;; Emit provider verified event
    (print {
      event: "provider-verified",
      provider-id: provider-id,
      name: (get name current-data),
      verified-by: contract-caller,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; Revoke provider verification (admin only)
;; @param provider-id: ID of provider to revoke verification
;; @returns: (response bool uint) - success or error code
(define-public (revoke-provider-verification (provider-id uint))
  (let ((current-data (unwrap! (get-provider provider-id) err-provider-not-found)))
    ;; Only contract owner can revoke verification
    (asserts! (is-eq contract-caller contract-owner) err-not-contract-owner)
    (asserts! (get verified current-data) err-provider-not-verified)
    
    ;; Update provider verification status
    (map-set providers provider-id (merge current-data {
      verified: false,
      verified-at: none,
      verified-by: none
    }))
    
    ;; Emit provider verification revoked event
    (print {
      event: "provider-verification-revoked",
      provider-id: provider-id,
      name: (get name current-data),
      revoked-by: contract-caller,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; Update provider metadata (admin only)
;; @param provider-id: ID of provider to update
;; @param metadata: New metadata for the provider
;; @returns: (response bool uint) - success or error code
(define-public (update-provider-metadata (provider-id uint) (metadata (string-utf8 500)))
  (let ((current-data (unwrap! (get-provider provider-id) err-provider-not-found)))
    ;; Only contract owner can update metadata
    (asserts! (is-eq contract-caller contract-owner) err-not-contract-owner)
    (asserts! (is-valid-metadata metadata) err-invalid-metadata-length)
    
    ;; Update provider metadata
    (map-set providers provider-id (merge current-data { metadata: metadata }))
    
    ;; Emit metadata updated event
    (print {
      event: "provider-metadata-updated",
      provider-id: provider-id,
      updated-by: contract-caller,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)
