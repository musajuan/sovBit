;; sovBit DAO Smart Contract
;; A decentralized autonomous organization platform

;; Constants
(define-constant ERR_NOT_DAO_MEMBER u100)
(define-constant ERR_NOT_FOUND u101)
(define-constant ERR_ALREADY_VOTED u102)
(define-constant ERR_ALREADY_EXECUTED u103)
(define-constant ERR_NOT_ENOUGH_VOTES u104)
(define-constant ERR_UNAUTHORIZED u105)
(define-constant ERR_INSUFFICIENT_BALANCE u106)
(define-constant ERR_INVALID_AMOUNT u107)
(define-constant ERR_INVALID_DAO_ID u108)
(define-constant ERR_INVALID_PROPOSAL_ID u109)
(define-constant ERR_EMPTY_STRING u110)

;; Data Maps
(define-map daos
  { dao-id: uint }
  {
    name: (string-utf8 50),
    admin: principal,
    total-members: uint,
    token-supply: uint
  }
)

(define-map dao-members
  { dao-id: uint, member: principal }
  {
    tokens: uint
  }
)

(define-map proposals
  { dao-id: uint, proposal-id: uint }
  {
    title: (string-utf8 100),
    description: (string-utf8 280),
    creator: principal,
    yes-votes: uint,
    no-votes: uint,
    executed: bool
  }
)

(define-map proposal-votes
  { dao-id: uint, proposal-id: uint, voter: principal }
  {
    vote: bool
  }
)

(define-map dao-treasury
  { dao-id: uint }
  {
    balance: uint
  }
)

;; Data Variables
(define-data-var next-dao-id uint u1)
(define-data-var next-proposal-id uint u1)

;; ===== VALIDATION HELPERS =====
(define-private (is-valid-dao-id (dao-id uint))
  (and (> dao-id u0) (< dao-id (var-get next-dao-id)))
)

(define-private (is-valid-proposal-id (proposal-id uint))
  (and (> proposal-id u0) (< proposal-id (var-get next-proposal-id)))
)

(define-private (is-non-empty-string (str (string-utf8 280)))
  (> (len str) u0)
)

(define-private (is-non-empty-string-50 (str (string-utf8 50)))
  (> (len str) u0)
)

(define-private (is-non-empty-string-100 (str (string-utf8 100)))
  (> (len str) u0)
)

;; ===== DAO CREATION =====
(define-public (create-dao (name (string-utf8 50)) (initial-token-supply uint))
  (let (
    (id (var-get next-dao-id))
    (sender tx-sender)
  )
    (begin
      ;; Validate inputs
      (asserts! (is-non-empty-string-50 name) (err ERR_EMPTY_STRING))
      (asserts! (> initial-token-supply u0) (err ERR_INVALID_AMOUNT))
      
      (map-set daos
        { dao-id: id }
        {
          name: name,
          admin: sender,
          total-members: u1,
          token-supply: initial-token-supply
        }
      )
      (map-set dao-members
        { dao-id: id, member: sender }
        { tokens: initial-token-supply }
      )
      (map-set dao-treasury
        { dao-id: id }
        { balance: u0 }
      )
      (var-set next-dao-id (+ id u1))
      (ok id)
    )
  )
)

;; ===== DAO MEMBERSHIP / TOKENS =====
(define-read-only (get-balance (dao-id uint) (user principal))
  (begin
    ;; Validate dao-id exists
    (asserts! (is-some (map-get? daos { dao-id: dao-id })) u0)
    (default-to u0 (get tokens (map-get? dao-members { dao-id: dao-id, member: user })))
  )
)

(define-public (transfer-token (dao-id uint) (to principal) (amount uint))
  (let (
    (from-bal (get-balance dao-id tx-sender))
    (to-bal (get-balance dao-id to))
    (dao-exists (is-some (map-get? daos { dao-id: dao-id })))
  )
    (begin
      ;; Validate inputs
      (asserts! dao-exists (err ERR_NOT_FOUND))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (>= from-bal amount) (err ERR_INSUFFICIENT_BALANCE))
      (asserts! (> from-bal u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (not (is-eq tx-sender to)) (err ERR_INVALID_AMOUNT))
      
      ;; Update sender's balance
      (map-set dao-members
        { dao-id: dao-id, member: tx-sender }
        { tokens: (- from-bal amount) }
      )
      
      ;; Update recipient's balance
      (map-set dao-members
        { dao-id: dao-id, member: to }
        { tokens: (+ to-bal amount) }
      )
      
      ;; Update member count if new member
      (if (is-eq to-bal u0)
        (match (map-get? daos { dao-id: dao-id })
          dao-info (begin
            (map-set daos
              { dao-id: dao-id }
              (merge dao-info { total-members: (+ (get total-members dao-info) u1) })
            )
            true
          )
          false
        )
        true
      )
      
      (ok true)
    )
  )
)

;; ===== PROPOSALS =====
(define-public (submit-proposal (dao-id uint) (title (string-utf8 100)) (description (string-utf8 280)))
  (let (
    (pid (var-get next-proposal-id))
    (member-bal (get-balance dao-id tx-sender))
    (dao-exists (is-some (map-get? daos { dao-id: dao-id })))
  )
    (begin
      ;; Validate inputs
      (asserts! dao-exists (err ERR_NOT_FOUND))
      (asserts! (is-non-empty-string-100 title) (err ERR_EMPTY_STRING))
      (asserts! (is-non-empty-string description) (err ERR_EMPTY_STRING))
      (asserts! (> member-bal u0) (err ERR_NOT_DAO_MEMBER))
      
      (map-set proposals
        { dao-id: dao-id, proposal-id: pid }
        {
          title: title,
          description: description,
          creator: tx-sender,
          yes-votes: u0,
          no-votes: u0,
          executed: false
        }
      )
      (var-set next-proposal-id (+ pid u1))
      (ok pid)
    )
  )
)

(define-public (vote-proposal (dao-id uint) (proposal-id uint) (support bool))
  (let (
    (already-voted? (is-some (map-get? proposal-votes { dao-id: dao-id, proposal-id: proposal-id, voter: tx-sender })))
    (weight (get-balance dao-id tx-sender))
    (proposal-data (map-get? proposals { dao-id: dao-id, proposal-id: proposal-id }))
    (dao-exists (is-some (map-get? daos { dao-id: dao-id })))
  )
    (begin
      ;; Validate inputs
      (asserts! dao-exists (err ERR_NOT_FOUND))
      (asserts! (not already-voted?) (err ERR_ALREADY_VOTED))
      (asserts! (> weight u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (is-some proposal-data) (err ERR_NOT_FOUND))
      
      ;; Record the vote
      (map-set proposal-votes
        { dao-id: dao-id, proposal-id: proposal-id, voter: tx-sender }
        { vote: support }
      )
      
      ;; Update proposal vote counts
      (match proposal-data
        prop (begin
          (map-set proposals 
            { dao-id: dao-id, proposal-id: proposal-id }
            (merge prop
              (if support
                { yes-votes: (+ (get yes-votes prop) weight), no-votes: (get no-votes prop) }
                { yes-votes: (get yes-votes prop), no-votes: (+ (get no-votes prop) weight) }
              )
            )
          )
          (ok true)
        )
        (err ERR_NOT_FOUND)
      )
    )
  )
)

(define-public (execute-proposal (dao-id uint) (proposal-id uint))
  (let (
    (dao-exists (is-some (map-get? daos { dao-id: dao-id })))
    (proposal-data (map-get? proposals { dao-id: dao-id, proposal-id: proposal-id }))
  )
    (begin
      ;; Validate inputs
      (asserts! dao-exists (err ERR_NOT_FOUND))
      
      (match proposal-data
        prop (begin
          (asserts! (not (get executed prop)) (err ERR_ALREADY_EXECUTED))
          (asserts! (> (get yes-votes prop) (get no-votes prop)) (err ERR_NOT_ENOUGH_VOTES))

          ;; Mark proposal as executed
          (map-set proposals 
            { dao-id: dao-id, proposal-id: proposal-id }
            (merge prop { executed: true })
          )
          
          ;; TODO: Add actual proposal execution logic here
          ;; This could include treasury transfers, member additions, etc.
          
          (ok true)
        )
        (err ERR_NOT_FOUND)
      )
    )
  )
)

;; ===== DAO TREASURY =====
(define-public (deposit-treasury (dao-id uint) (amount uint))
  (let (
    (dao-exists (is-some (map-get? daos { dao-id: dao-id })))
  )
    (begin
      ;; Validate inputs
      (asserts! dao-exists (err ERR_NOT_FOUND))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      
      ;; Transfer STX to contract
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      
      ;; Update treasury balance
      (let ((current-bal (get-treasury dao-id)))
        (map-set dao-treasury 
          { dao-id: dao-id }
          { balance: (+ current-bal amount) }
        )
      )
      
      (ok true)
    )
  )
)

(define-public (withdraw-treasury (dao-id uint) (amount uint) (to principal))
  (let (
    (caller tx-sender)
    (dao-info (map-get? daos { dao-id: dao-id }))
    (current-bal (get-treasury dao-id))
  )
    (begin
      ;; Validate inputs
      (asserts! (is-some dao-info) (err ERR_NOT_FOUND))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (>= current-bal amount) (err ERR_INSUFFICIENT_BALANCE))
      
      ;; Check if caller is admin
      (try! (match dao-info
        dao (if (is-eq caller (get admin dao))
          (ok true)
          (err ERR_UNAUTHORIZED)
        )
        (err ERR_NOT_FOUND)
      ))
      
      ;; Update treasury balance
      (map-set dao-treasury 
        { dao-id: dao-id }
        { balance: (- current-bal amount) }
      )
      
      ;; Transfer STX from contract
      (as-contract (stx-transfer? amount tx-sender to))
    )
  )
)

;; ===== READ-ONLY HELPERS =====
(define-read-only (get-dao (dao-id uint))
  (map-get? daos { dao-id: dao-id })
)

(define-read-only (get-proposal (dao-id uint) (proposal-id uint))
  (map-get? proposals { dao-id: dao-id, proposal-id: proposal-id })
)

(define-read-only (get-treasury (dao-id uint))
  (default-to u0 (get balance (map-get? dao-treasury { dao-id: dao-id })))
)

(define-read-only (get-vote (dao-id uint) (proposal-id uint) (voter principal))
  (map-get? proposal-votes { dao-id: dao-id, proposal-id: proposal-id, voter: voter })
)

(define-read-only (has-voted (dao-id uint) (proposal-id uint) (voter principal))
  (is-some (get-vote dao-id proposal-id voter))
)

(define-read-only (get-next-dao-id)
  (var-get next-dao-id)
)

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id)
)