;; Title: Verification Access Contract
;; Description: Enable volunteers to grant non-profits access to specific background check attestations
;; Version: 1.0.0
;; Author: Verifiable Background Check System
;; License: MIT

;; This contract empowers volunteers to control who can view their records, 
;; supporting selective disclosure and privacy while enabling verification.

;; ===== CONSTANTS =====

;; Contract owner (deployer)
(define-constant contract-owner tx-sender)

;; Error codes - Authorization (100-199)
(define-constant err-unauthorized (err u100))
(define-constant err-not-volunteer-owner (err u101))
(define-constant err-access-denied (err u102))

;; Error codes - Validation (200-299)
(define-constant err-invalid-org-id (err u200))
(define-constant err-invalid-attestation-id (err u201))
(define-constant err-invalid-expiry (err u202))
(define-constant err-grant-not-found (err u203))
(define-constant err-volunteer-not-found (err u204))

;; Error codes - Business Logic (300-399)
(define-constant err-attestation-not-found (err u300))
(define-constant err-attestation-expired (err u301))
(define-constant err-grant-already-exists (err u302))
(define-constant err-grant-expired (err u303))
(define-constant err-grant-inactive (err u304))

;; Maximum expiry period (in blocks) - approximately 6 months
(define-constant max-expiry-blocks u26280)

;; ===== DATA STRUCTURES =====

;; Auto-incrementing grant ID counter
(define-data-var grant-counter uint u0)

;; Map grant ID to access grant data
(define-map access-grants uint {
  volunteer-id: uint,
  org-id: principal,
  attestation-id: uint,
  granted-at: uint,
  expiry: uint,
  active: bool,
  granted-by: principal
})

;; Map volunteer ID to list of their grant IDs
(define-map volunteer-grants uint (list 100 uint))

;; Map organization to list of grants they have access to
(define-map org-grants principal (list 100 uint))

;; Map (org-id, attestation-id) to grant ID for quick access checks
(define-map org-attestation-grants { org-id: principal, attestation-id: uint } uint)

;; ===== PRIVATE FUNCTIONS =====

;; Validate expiry period
(define-private (is-valid-expiry (expiry uint))
  (and 
    (> expiry stacks-block-height)
    (<= (- expiry stacks-block-height) max-expiry-blocks)
  )
)

;; Generate next grant ID
(define-private (get-next-grant-id)
  (let ((current-id (var-get grant-counter)))
    (var-set grant-counter (+ current-id u1))
    (+ current-id u1)
  )
)

;; Add grant to volunteer's list
(define-private (add-to-volunteer-grants (volunteer-id uint) (grant-id uint))
  (let ((current-list (default-to (list) (map-get? volunteer-grants volunteer-id))))
    (map-set volunteer-grants volunteer-id
      (unwrap! (as-max-len? (append current-list grant-id) u100) (err u999))
    )
    (ok true)
  )
)

;; Add grant to organization's list
(define-private (add-to-org-grants (org-id principal) (grant-id uint))
  (let ((current-list (default-to (list) (map-get? org-grants org-id))))
    (map-set org-grants org-id
      (unwrap! (as-max-len? (append current-list grant-id) u100) (err u999))
    )
    (ok true)
  )
)

;; Check if grant already exists for org-attestation pair
(define-private (grant-exists-for-org-attestation (org-id principal) (attestation-id uint))
  (is-some (map-get? org-attestation-grants { org-id: org-id, attestation-id: attestation-id }))
)

;; ===== READ-ONLY FUNCTIONS =====

;; Get access grant data by ID
(define-read-only (get-access-grant (grant-id uint))
  (map-get? access-grants grant-id)
)

;; Check if organization has active access to specific attestation
(define-read-only (check-access (org-id principal) (attestation-id uint))
  (match (map-get? org-attestation-grants { org-id: org-id, attestation-id: attestation-id })
    grant-id 
      (match (get-access-grant grant-id)
        grant-data 
          (and 
            (get active grant-data)
            (> (get expiry grant-data) stacks-block-height)
          )
        false
      )
    false
  )
)

;; Get all grant IDs for a volunteer
(define-read-only (get-volunteer-grants (volunteer-id uint))
  (default-to (list) (map-get? volunteer-grants volunteer-id))
)

;; Get all grant IDs for an organization
(define-read-only (get-org-grants (org-id principal))
  (default-to (list) (map-get? org-grants org-id))
)

;; Get current grant counter
(define-read-only (get-grant-counter)
  (var-get grant-counter)
)

;; Get contract information
(define-read-only (get-contract-info)
  {
    name: "VerificationAccess",
    version: "1.0.0",
    owner: contract-owner,
    total-grants: (var-get grant-counter)
  }
)

;; Get accessible attestation IDs for an organization
(define-read-only (get-accessible-attestations (org-id principal))
  (let ((grant-ids (get-org-grants org-id)))
    (fold extract-accessible-attestations grant-ids (list))
  )
)

;; Helper function to extract attestation ID if grant is accessible
(define-private (extract-accessible-attestations (grant-id uint) (acc (list 100 uint)))
  (match (get-access-grant grant-id)
    grant-data
      (if (and
            (get active grant-data)
            (> (get expiry grant-data) stacks-block-height)
          )
        (unwrap! (as-max-len? (append acc (get attestation-id grant-data)) u100) acc)
        acc
      )
    acc
  )
)

;; ===== PUBLIC FUNCTIONS =====

;; Grant access to an attestation for a specific organization
;; @param org-id: Principal address of the organization
;; @param attestation-id: ID of the attestation to grant access to
;; @param expiry: Block height when access expires
;; @returns: (response uint uint) - success with grant ID or error code
(define-public (grant-access (org-id principal) (attestation-id uint) (expiry uint))
  (let ((grant-id (get-next-grant-id)))
    ;; Get volunteer ID for the caller
    (let ((volunteer-id (unwrap! (contract-call? .volunteer-registry get-volunteer-by-principal contract-caller) err-volunteer-not-found)))
      ;; Validation checks
      (asserts! (is-valid-expiry expiry) err-invalid-expiry)
      (asserts! (contract-call? .background-check-attestation is-valid-attestation attestation-id) err-attestation-expired)
      (asserts! (not (grant-exists-for-org-attestation org-id attestation-id)) err-grant-already-exists)
      
      ;; Verify volunteer owns the attestation
      (let ((attestation-data (unwrap! (contract-call? .background-check-attestation get-attestation attestation-id) err-attestation-not-found)))
        (asserts! (is-eq (get volunteer-id attestation-data) volunteer-id) err-not-volunteer-owner)
        
        ;; Create access grant record
        (map-set access-grants grant-id {
          volunteer-id: volunteer-id,
          org-id: org-id,
          attestation-id: attestation-id,
          granted-at: stacks-block-height,
          expiry: expiry,
          active: true,
          granted-by: contract-caller
        })
        
        ;; Create mappings for quick lookups
        (map-set org-attestation-grants { org-id: org-id, attestation-id: attestation-id } grant-id)
        
        ;; Add to volunteer and organization lists
        (try! (add-to-volunteer-grants volunteer-id grant-id))
        (try! (add-to-org-grants org-id grant-id))
        
        ;; Emit access granted event
        (print {
          event: "access-granted",
          grant-id: grant-id,
          volunteer-id: volunteer-id,
          org-id: org-id,
          attestation-id: attestation-id,
          expiry: expiry,
          granted-by: contract-caller,
          block-height: stacks-block-height
        })
        
        (ok grant-id)
      )
    )
  )
)

;; Revoke access grant (volunteer only)
;; @param grant-id: ID of the grant to revoke
;; @returns: (response bool uint) - success or error code
(define-public (revoke-access (grant-id uint))
  (let ((grant-data (unwrap! (get-access-grant grant-id) err-grant-not-found)))
    ;; Only the volunteer who granted access can revoke it
    (asserts! (is-eq (get granted-by grant-data) contract-caller) err-unauthorized)
    (asserts! (get active grant-data) err-grant-inactive)
    
    ;; Deactivate the grant
    (map-set access-grants grant-id (merge grant-data { active: false }))
    
    ;; Remove from org-attestation mapping
    (map-delete org-attestation-grants { 
      org-id: (get org-id grant-data), 
      attestation-id: (get attestation-id grant-data) 
    })
    
    ;; Emit access revoked event
    (print {
      event: "access-revoked",
      grant-id: grant-id,
      volunteer-id: (get volunteer-id grant-data),
      org-id: (get org-id grant-data),
      attestation-id: (get attestation-id grant-data),
      revoked-by: contract-caller,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; Verify access and get attestation data (organizations use this)
;; @param attestation-id: ID of the attestation to access
;; @returns: (response (optional attestation-data) uint) - attestation data if accessible or error
(define-public (verify-and-get-attestation (attestation-id uint))
  (begin
    ;; Check if caller has access to this attestation
    (asserts! (check-access contract-caller attestation-id) err-access-denied)

    ;; Return the attestation data
    (ok (contract-call? .background-check-attestation get-attestation attestation-id))
  )
)
