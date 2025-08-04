;; sovBit DAO Smart Contract
;; A decentralized autonomous organization platform with enhanced governance and treasury management

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
(define-constant ERR_PROPOSAL_EXPIRED u111)
(define-constant ERR_VOTING_PERIOD_ACTIVE u112)
(define-constant ERR_INSUFFICIENT_QUORUM u113)
(define-constant ERR_INVALID_DATA u114)

;; Enhanced Governance Constants
(define-constant VOTING_PERIOD u144) ;; ~24 hours in blocks (assuming 10min blocks)
(define-constant EXECUTION_WINDOW u1008) ;; ~7 days in blocks
(define-constant MIN_QUORUM_PERCENTAGE u20) ;; 20% minimum participation

;; Role definitions for Multi-Sig Treasury
(define-constant ROLE_ADMIN u1)
(define-constant ROLE_TREASURER u2)
(define-constant ROLE_MEMBER u3)

;; Original Data Maps
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

;; Enhanced Governance Maps
(define-map enhanced-proposals
  { dao-id: uint, proposal-id: uint }
  {
    title: (string-utf8 100),
    description: (string-utf8 280),
    creator: principal,
    yes-votes: uint,
    no-votes: uint,
    total-voters: uint,
    executed: bool,
    created-at: uint,
    voting-ends-at: uint,
    execution-deadline: uint,
    proposal-type: (string-ascii 20),
    target-amount: (optional uint),
    target-recipient: (optional principal)
  }
)

;; Multi-Signature Treasury Maps
(define-map treasury-config
  { dao-id: uint }
  {
    required-signatures: uint,
    max-single-withdrawal: uint,
    daily-withdrawal-limit: uint,
    emergency-multisig-required: uint
  }
)

(define-map member-roles
  { dao-id: uint, member: principal }
  {
    role: uint,
    assigned-at: uint,
    assigned-by: principal
  }
)

(define-map pending-transactions
  { dao-id: uint, tx-id: uint }
  {
    amount: uint,
    recipient: principal,
    purpose: (string-utf8 100),
    created-by: principal,
    created-at: uint,
    required-sigs: uint,
    current-sigs: uint,
    executed: bool,
    expired: bool,
    tx-type: (string-ascii 20)
  }
)

(define-map transaction-signatures
  { dao-id: uint, tx-id: uint, signer: principal }
  {
    signed-at: uint
  }
)

(define-map daily-withdrawals
  { dao-id: uint, date: uint }
  {
    total-withdrawn: uint
  }
)

;; Data Variables
(define-data-var next-dao-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-tx-id uint u1)

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

;; Safe data access helpers
(define-private (safe-get-dao (dao-id uint))
  (ok (unwrap! (map-get? daos { dao-id: dao-id }) (err ERR_NOT_FOUND)))
)

(define-private (safe-get-enhanced-proposal (dao-id uint) (proposal-id uint))
  (ok (unwrap! (map-get? enhanced-proposals { dao-id: dao-id, proposal-id: proposal-id }) (err ERR_NOT_FOUND)))
)

(define-private (safe-get-pending-transaction (dao-id uint) (tx-id uint))
  (ok (unwrap! (map-get? pending-transactions { dao-id: dao-id, tx-id: tx-id }) (err ERR_NOT_FOUND)))
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
      (asserts! (<= initial-token-supply u1000000000000) (err ERR_INVALID_AMOUNT)) ;; Max supply check
      
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
      
      ;; Setup default treasury configuration
      (map-set treasury-config
        { dao-id: id }
        {
          required-signatures: u2,
          max-single-withdrawal: u1000000, ;; 1 STX in microSTX
          daily-withdrawal-limit: u5000000, ;; 5 STX in microSTX
          emergency-multisig-required: u3
        }
      )
      
      ;; Assign admin role to creator
      (map-set member-roles
        { dao-id: id, member: sender }
        {
          role: ROLE_ADMIN,
          assigned-at: stacks-block-height,
          assigned-by: sender
        }
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
      (asserts! (<= amount u1000000000000) (err ERR_INVALID_AMOUNT)) ;; Max transfer check
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
            
            ;; Assign member role to new member
            (map-set member-roles
              { dao-id: dao-id, member: to }
              {
                role: ROLE_MEMBER,
                assigned-at: stacks-block-height,
                assigned-by: tx-sender
              }
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

;; ===== ENHANCED GOVERNANCE FUNCTIONS =====

;; Get proposal state
(define-read-only (get-proposal-state (dao-id uint) (proposal-id uint))
  (let (
    (proposal (map-get? enhanced-proposals { dao-id: dao-id, proposal-id: proposal-id }))
    (current-block stacks-block-height)
  )
    (match proposal
      prop (let (
        (voting-ended (>= current-block (get voting-ends-at prop)))
        (execution-expired (>= current-block (get execution-deadline prop)))
        (executed (get executed prop))
        (dao-result (safe-get-dao dao-id))
      )
        (match dao-result
          dao-info (let (
            (total-members (get total-members dao-info))
            (quorum-met (>= (* (get total-voters prop) u100) (* total-members MIN_QUORUM_PERCENTAGE)))
          )
            (if executed
              "executed"
              (if execution-expired
                "expired"
                (if voting-ended
                  (if (and 
                        (> (get yes-votes prop) (get no-votes prop))
                        quorum-met)
                    "passed"
                    "failed")
                  "active"))))
          err-code "dao-not-found"))
      "not-found")))

;; Enhanced proposal submission
(define-public (submit-enhanced-proposal 
  (dao-id uint) 
  (title (string-utf8 100)) 
  (description (string-utf8 280))
  (proposal-type (string-ascii 20))
  (target-amount (optional uint))
  (target-recipient (optional principal)))
  (let (
    (pid (var-get next-proposal-id))
    (member-bal (get-balance dao-id tx-sender))
    (dao-exists (is-some (map-get? daos { dao-id: dao-id })))
    (current-block stacks-block-height)
  )
    (begin
      ;; Validate inputs
      (asserts! dao-exists (err ERR_NOT_FOUND))
      (asserts! (> member-bal u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (is-non-empty-string-100 title) (err ERR_EMPTY_STRING))
      (asserts! (is-non-empty-string description) (err ERR_EMPTY_STRING))
      (asserts! (< (len proposal-type) u21) (err ERR_INVALID_DATA))
      
      ;; Validate proposal type specific requirements
      (if (is-eq proposal-type "treasury")
        (begin
          (asserts! (is-some target-amount) (err ERR_INVALID_AMOUNT))
          (asserts! (is-some target-recipient) (err ERR_UNAUTHORIZED))
          (let ((amount (unwrap! target-amount (err ERR_INVALID_AMOUNT))))
            (begin
              (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
              (asserts! (<= amount (get-treasury dao-id)) (err ERR_INSUFFICIENT_BALANCE))
            )
          )
        )
        true
      )
      
      (map-set enhanced-proposals
        { dao-id: dao-id, proposal-id: pid }
        {
          title: title,
          description: description,
          creator: tx-sender,
          yes-votes: u0,
          no-votes: u0,
          total-voters: u0,
          executed: false,
          created-at: current-block,
          voting-ends-at: (+ current-block VOTING_PERIOD),
          execution-deadline: (+ current-block VOTING_PERIOD EXECUTION_WINDOW),
          proposal-type: proposal-type,
          target-amount: target-amount,
          target-recipient: target-recipient
        }
      )
      (var-set next-proposal-id (+ pid u1))
      (ok pid)
    )
  )
)

;; Enhanced voting with time checks
(define-public (vote-enhanced-proposal (dao-id uint) (proposal-id uint) (support bool))
  (let (
    (voter tx-sender)
    (weight (get-balance dao-id voter))
    (already-voted? (is-some (map-get? proposal-votes { dao-id: dao-id, proposal-id: proposal-id, voter: voter })))
    (proposal-data (map-get? enhanced-proposals { dao-id: dao-id, proposal-id: proposal-id }))
    (current-block stacks-block-height)
  )
    (begin
      ;; Validate
      (asserts! (> weight u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (not already-voted?) (err ERR_ALREADY_VOTED))
      (asserts! (is-some proposal-data) (err ERR_NOT_FOUND))
      
      (match proposal-data
        prop (begin
          ;; Check voting period
          (asserts! (< current-block (get voting-ends-at prop)) (err ERR_PROPOSAL_EXPIRED))
          (asserts! (not (get executed prop)) (err ERR_ALREADY_EXECUTED))
          
          ;; Record vote
          (map-set proposal-votes
            { dao-id: dao-id, proposal-id: proposal-id, voter: voter }
            { vote: support }
          )
          
          ;; Update proposal with weighted voting - FIXED: consistent tuple structure
          (map-set enhanced-proposals 
            { dao-id: dao-id, proposal-id: proposal-id }
            (merge prop
              (if support
                { 
                  yes-votes: (+ (get yes-votes prop) weight),
                  no-votes: (get no-votes prop),
                  total-voters: (+ (get total-voters prop) u1)
                }
                { 
                  yes-votes: (get yes-votes prop),
                  no-votes: (+ (get no-votes prop) weight),
                  total-voters: (+ (get total-voters prop) u1)
                }
              )
            )
          )
          (ok weight)
        )
        (err ERR_NOT_FOUND)
      )
    )
  )
)

;; Auto-execution function
(define-public (execute-enhanced-proposal (dao-id uint) (proposal-id uint))
  (let (
    (proposal-result (safe-get-enhanced-proposal dao-id proposal-id))
    (state (get-proposal-state dao-id proposal-id))
  )
    (begin
      (asserts! (is-eq state "passed") (err ERR_NOT_ENOUGH_VOTES))
      
      (match proposal-result
        prop (begin
          ;; Mark as executed first
          (map-set enhanced-proposals 
            { dao-id: dao-id, proposal-id: proposal-id }
            (merge prop { executed: true })
          )
          
          ;; Execute based on proposal type
          (if (is-eq (get proposal-type prop) "treasury")
            ;; Treasury proposal - create multisig transaction
            (match (get target-amount prop)
              amount (match (get target-recipient prop)
                recipient (begin
                  (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
                  (try! (request-withdrawal dao-id amount recipient u"Proposal execution"))
                  (ok "treasury-proposal-created")
                )
                (err ERR_INVALID_DATA)
              )
              (err ERR_INVALID_DATA)
            )
            ;; Other proposal types
            (ok "executed")
          )
        )
        error-code (err error-code)
      )
    )
  )
)

;; ===== MULTI-SIGNATURE TREASURY FUNCTIONS =====

;; Setup treasury configuration
(define-public (setup-treasury-config 
  (dao-id uint)
  (required-sigs uint)
  (max-single uint)
  (daily-limit uint)
  (emergency-sigs uint))
  (let (
    (dao-info (map-get? daos { dao-id: dao-id }))
  )
    (begin
      (asserts! (is-some dao-info) (err ERR_NOT_FOUND))
      (asserts! (> required-sigs u0) (err ERR_INVALID_AMOUNT))
      (asserts! (<= required-sigs u10) (err ERR_INVALID_AMOUNT)) ;; Max 10 signatures
      (asserts! (> emergency-sigs u0) (err ERR_INVALID_AMOUNT))
      (asserts! (<= emergency-sigs u10) (err ERR_INVALID_AMOUNT))
      (asserts! (> max-single u0) (err ERR_INVALID_AMOUNT))
      (asserts! (> daily-limit u0) (err ERR_INVALID_AMOUNT))
      
      ;; Only admin can setup
      (try! (match dao-info
        dao (if (is-eq tx-sender (get admin dao))
          (ok true)
          (err ERR_UNAUTHORIZED)
        )
        (err ERR_NOT_FOUND)
      ))
      
      (map-set treasury-config
        { dao-id: dao-id }
        {
          required-signatures: required-sigs,
          max-single-withdrawal: max-single,
          daily-withdrawal-limit: daily-limit,
          emergency-multisig-required: emergency-sigs
        }
      )
      
      (ok true)
    )
  )
)

;; Assign roles
(define-public (assign-role (dao-id uint) (member principal) (role uint))
  (let (
    (caller-role (get-member-role dao-id tx-sender))
  )
    (begin
      (asserts! (is-eq caller-role ROLE_ADMIN) (err ERR_UNAUTHORIZED))
      (asserts! (> (get-balance dao-id member) u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (or (is-eq role ROLE_ADMIN) (is-eq role ROLE_TREASURER) (is-eq role ROLE_MEMBER)) (err ERR_INVALID_AMOUNT))
      
      (map-set member-roles
        { dao-id: dao-id, member: member }
        {
          role: role,
          assigned-at: stacks-block-height,
          assigned-by: tx-sender
        }
      )
      
      (ok true)
    )
  )
)

;; Create withdrawal request
(define-public (request-withdrawal 
  (dao-id uint) 
  (amount uint) 
  (recipient principal) 
  (purpose (string-utf8 100)))
  (let (
    (tx-id (var-get next-tx-id))
    (caller-role (get-member-role dao-id tx-sender))
    (config (map-get? treasury-config { dao-id: dao-id }))
    (current-balance (get-treasury dao-id))
    (today (/ stacks-block-height u144))
    (daily-withdrawn (get-daily-withdrawn dao-id today))
  )
    (begin
      ;; Validate permissions and inputs
      (asserts! (or (is-eq caller-role ROLE_ADMIN) (is-eq caller-role ROLE_TREASURER)) (err ERR_UNAUTHORIZED))
      (asserts! (is-some config) (err ERR_NOT_FOUND))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (<= amount current-balance) (err ERR_INSUFFICIENT_BALANCE))
      (asserts! (is-non-empty-string-100 purpose) (err ERR_EMPTY_STRING))
      
      (match config
        cfg (let (
          (is-large-withdrawal (> amount (get max-single-withdrawal cfg)))
          (exceeds-daily-limit (> (+ daily-withdrawn amount) (get daily-withdrawal-limit cfg)))
          (required-sigs (if (or is-large-withdrawal exceeds-daily-limit)
                           (get emergency-multisig-required cfg)
                           (get required-signatures cfg)))
        )
          (begin
            (map-set pending-transactions
              { dao-id: dao-id, tx-id: tx-id }
              {
                amount: amount,
                recipient: recipient,
                purpose: purpose,
                created-by: tx-sender,
                created-at: stacks-block-height,
                required-sigs: required-sigs,
                current-sigs: u0,
                executed: false,
                expired: false,
                tx-type: (if (or is-large-withdrawal exceeds-daily-limit) "emergency" "withdrawal")
              }
            )
            
            (var-set next-tx-id (+ tx-id u1))
            (ok tx-id)
          )
        )
        (err ERR_NOT_FOUND)
      )
    )
  )
)

;; Sign transaction
(define-public (sign-transaction (dao-id uint) (tx-id uint))
  (let (
    (caller-role (get-member-role dao-id tx-sender))
    (tx-data-result (safe-get-pending-transaction dao-id tx-id))
    (already-signed (is-some (map-get? transaction-signatures { dao-id: dao-id, tx-id: tx-id, signer: tx-sender })))
  )
    (begin
      ;; Validate
      (asserts! (or (is-eq caller-role ROLE_ADMIN) (is-eq caller-role ROLE_TREASURER)) (err ERR_UNAUTHORIZED))
      (asserts! (not already-signed) (err ERR_ALREADY_VOTED))
      
      (match tx-data-result
        tx (begin
          (asserts! (not (get executed tx)) (err ERR_ALREADY_EXECUTED))
          (asserts! (not (get expired tx)) (err ERR_ALREADY_EXECUTED))
          
          ;; Record signature
          (map-set transaction-signatures
            { dao-id: dao-id, tx-id: tx-id, signer: tx-sender }
            {
              signed-at: stacks-block-height
            }
          )
          
          ;; Update signature count
          (let ((new-sig-count (+ (get current-sigs tx) u1)))
            (map-set pending-transactions
              { dao-id: dao-id, tx-id: tx-id }
              (merge tx { current-sigs: new-sig-count })
            )
            
            ;; Auto-execute if enough signatures
            (if (>= new-sig-count (get required-sigs tx))
              (execute-multisig-transaction dao-id tx-id)
              (ok true)
            )
          )
        )
        error-code (err error-code)
      )
    )
  )
)

;; Execute multisig transaction
(define-private (execute-multisig-transaction (dao-id uint) (tx-id uint))
  (let (
    (tx-data-result (safe-get-pending-transaction dao-id tx-id))
    (today (/ stacks-block-height u144))
  )
    (match tx-data-result
      tx-data (begin
        ;; Mark as executed
        (map-set pending-transactions
          { dao-id: dao-id, tx-id: tx-id }
          (merge tx-data { executed: true })
        )
        
        ;; Update daily withdrawal tracking
        (let ((current-daily (get-daily-withdrawn dao-id today)))
          (map-set daily-withdrawals
            { dao-id: dao-id, date: today }
            { total-withdrawn: (+ current-daily (get amount tx-data)) }
          )
        )
        
        ;; Execute the withdrawal
        (let (
          (amount (get amount tx-data))
          (recipient (get recipient tx-data))
          (current-bal (get-treasury dao-id))
        )
          (begin
            (asserts! (>= current-bal amount) (err ERR_INSUFFICIENT_BALANCE))
            (map-set dao-treasury 
              { dao-id: dao-id }
              { balance: (- current-bal amount) }
            )
            (as-contract (stx-transfer? amount tx-sender recipient))
          )
        )
      )
      error-code (err error-code)
    )
  )
)

;; ===== ORIGINAL PROPOSALS (BACKWARD COMPATIBILITY) =====
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
      (asserts! (<= amount u1000000000000) (err ERR_INVALID_AMOUNT)) ;; Max deposit check
      
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

;; Legacy withdraw function (now creates multisig transaction)
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
      
      ;; Create multisig transaction instead of direct withdrawal
      (request-withdrawal dao-id amount to u"Admin withdrawal")
    )
  )
)

;; ===== HELPER FUNCTIONS =====
(define-read-only (get-member-role (dao-id uint) (member principal))
  (default-to ROLE_MEMBER (get role (map-get? member-roles { dao-id: dao-id, member: member })))
)

(define-read-only (get-daily-withdrawn (dao-id uint) (date uint))
  (default-to u0 (get total-withdrawn (map-get? daily-withdrawals { dao-id: dao-id, date: date })))
)

(define-read-only (get-pending-transaction (dao-id uint) (tx-id uint))
  (map-get? pending-transactions { dao-id: dao-id, tx-id: tx-id })
)

(define-read-only (has-signed-transaction (dao-id uint) (tx-id uint) (signer principal))
  (is-some (map-get? transaction-signatures { dao-id: dao-id, tx-id: tx-id, signer: signer }))
)

(define-read-only (get-enhanced-proposal (dao-id uint) (proposal-id uint))
  (map-get? enhanced-proposals { dao-id: dao-id, proposal-id: proposal-id })
)

(define-read-only (get-treasury-config (dao-id uint))
  (map-get? treasury-config { dao-id: dao-id })
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

(define-read-only (get-next-tx-id)
  (var-get next-tx-id)
)
