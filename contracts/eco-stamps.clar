;; -----------------------------------------------------------
;; Eco Stamps Protocol (ESP)
;; On-chain Carbon Offset & Reforestation Rewards
;; -----------------------------------------------------------

(define-constant ERR-NOT-ADMIN u100)
(define-constant ERR-INVALID-REQUEST u101)
(define-constant ERR-INSUFFICIENT-FUNDS u102)
(define-constant ERR-NOT-VALIDATOR u103)

;; -----------------------------------------------------------
;; Data Structures
;; -----------------------------------------------------------

;; Store admin (can onboard validators, manage registry)
(define-constant contract-admin tx-sender)

;; Registry of reforestation/carbon projects
(define-data-var project-counter uint u0)

(define-map projects
  uint
  {
    creator: principal,
    name: (string-utf8 50),
    description: (string-utf8 200),
    funds: uint,
    active: bool
  }
)

;; Donor history
(define-map donor-history
  { donor: principal, project-id: uint }
  { total-donated: uint }
)

;; Validators who can log actions
(define-map validators principal bool)

;; Action logs (tree planting, carbon offset, etc.)
(define-map action-logs
  uint
  {
    project-id: uint,
    validator: principal,
    description: (string-utf8 200),
    timestamp: uint
  }
)

(define-data-var action-counter uint u0)

;; -----------------------------------------------------------
;; Admin Functions
;; -----------------------------------------------------------

(define-public (add-validator (who principal))
  (begin
    (if (is-eq tx-sender contract-admin)
        (begin
          (map-set validators who true)
          (ok true)
        )
        (err ERR-NOT-ADMIN)
    )
  )
)

;; Create new project
(define-public (create-project (name (string-utf8 50)) (desc (string-utf8 200)))
  (let ((id (+ (var-get project-counter) u1)))
    (begin
      (var-set project-counter id)
      (map-set projects id
        {
          creator: tx-sender,
          name: name,
          description: desc,
          funds: u0,
          active: true
        }
      )
      (ok id)
    )
  )
)

;; -----------------------------------------------------------
;; Donation System
;; -----------------------------------------------------------

(define-public (donate (project-id uint) (amount uint))
  (if (<= amount u0)
      (err ERR-INVALID-REQUEST)
      (match (map-get? projects project-id)
        project
        (begin
          (map-set projects project-id
            {
              creator: (get creator project),
              name: (get name project),
              description: (get description project),
              funds: (+ (get funds project) amount),
              active: (get active project)
            }
          )
          (map-insert donor-history { donor: tx-sender, project-id: project-id }
            { total-donated: amount }
          )
          (ok true)
        )
        (err ERR-INVALID-REQUEST)
      )
  )
)

;; -----------------------------------------------------------
;; Validators Logging Proof-of-Action
;; -----------------------------------------------------------

(define-public (log-action (project-id uint) (desc (string-utf8 200)))
  (if (is-some (map-get? validators tx-sender))
      (let ((id (+ (var-get action-counter) u1)))
        (begin
          (var-set action-counter id)
          (map-set action-logs id
            {
              project-id: project-id,
              validator: tx-sender,
              description: desc,
              ;; Use action-counter as a proxy for timestamp here to avoid
              ;; reliance on environment-specific builtins like `get-block-info?`.
              timestamp: (var-get action-counter)
            }
          )
          ;; Future: Mint Eco-Stamp NFT here
          (ok id)
        )
      )
      (err ERR-NOT-VALIDATOR)
  )
)

;; -----------------------------------------------------------
;; Read-Only Functions
;; -----------------------------------------------------------

(define-read-only (get-project (id uint))
  (map-get? projects id)
)

(define-read-only (get-donations (donor principal) (project-id uint))
  (map-get? donor-history { donor: donor, project-id: project-id })
)

(define-read-only (get-action (id uint))
  (map-get? action-logs id)
)
