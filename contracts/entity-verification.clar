;; Entity Verification Contract
;; Validates supply chain participants and manages their credentials

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_ENTITY_EXISTS (err u402))
(define-constant ERR_ENTITY_NOT_FOUND (err u403))
(define-constant ERR_INVALID_STATUS (err u404))

;; Entity verification statuses
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map entities
  { entity-id: principal }
  {
    name: (string-ascii 100),
    entity-type: (string-ascii 50),
    registration-date: uint,
    verification-status: uint,
    risk-score: uint,
    verified-by: principal
  }
)

(define-map entity-credentials
  { entity-id: principal, credential-type: (string-ascii 50) }
  {
    credential-value: (string-ascii 200),
    issued-date: uint,
    expiry-date: uint,
    is-valid: bool
  }
)

(define-data-var total-entities uint u0)

;; Register new entity
(define-public (register-entity
  (entity-id principal)
  (name (string-ascii 100))
  (entity-type (string-ascii 50))
)
  (begin
    (asserts! (is-none (map-get? entities { entity-id: entity-id })) ERR_ENTITY_EXISTS)
    (map-set entities
      { entity-id: entity-id }
      {
        name: name,
        entity-type: entity-type,
        registration-date: block-height,
        verification-status: STATUS_PENDING,
        risk-score: u50,
        verified-by: CONTRACT_OWNER
      }
    )
    (var-set total-entities (+ (var-get total-entities) u1))
    (ok entity-id)
  )
)

;; Verify entity (only contract owner)
(define-public (verify-entity (entity-id principal) (new-status uint))
  (let ((entity (unwrap! (map-get? entities { entity-id: entity-id }) ERR_ENTITY_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-status STATUS_REVOKED) ERR_INVALID_STATUS)
    (map-set entities
      { entity-id: entity-id }
      (merge entity { verification-status: new-status })
    )
    (ok true)
  )
)

;; Add credential to entity
(define-public (add-credential
  (entity-id principal)
  (credential-type (string-ascii 50))
  (credential-value (string-ascii 200))
  (expiry-date uint)
)
  (begin
    (asserts! (is-some (map-get? entities { entity-id: entity-id })) ERR_ENTITY_NOT_FOUND)
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set entity-credentials
      { entity-id: entity-id, credential-type: credential-type }
      {
        credential-value: credential-value,
        issued-date: block-height,
        expiry-date: expiry-date,
        is-valid: true
      }
    )
    (ok true)
  )
)

;; Get entity details
(define-read-only (get-entity (entity-id principal))
  (map-get? entities { entity-id: entity-id })
)

;; Check if entity is verified
(define-read-only (is-entity-verified (entity-id principal))
  (match (map-get? entities { entity-id: entity-id })
    entity (is-eq (get verification-status entity) STATUS_VERIFIED)
    false
  )
)

;; Get credential
(define-read-only (get-credential (entity-id principal) (credential-type (string-ascii 50)))
  (map-get? entity-credentials { entity-id: entity-id, credential-type: credential-type })
)

;; Get total entities count
(define-read-only (get-total-entities)
  (var-get total-entities)
)
