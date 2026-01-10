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
(define-constant ERR_OVERFLOW u115)

;; Enhanced Governance Constants
(define-constant VOTING_PERIOD u144) ;; ~24 hours in blocks (assuming 10min blocks)
(define-constant EXECUTION_WINDOW u1008) ;; ~7 days in blocks
(define-constant MIN_QUORUM_PERCENTAGE u20) ;; 20% minimum participation

;; Role definitions for Multi-Sig Treasury
(define-constant ROLE_ADMIN u1)
(define-constant ROLE_TREASURER u2)
(define-constant ROLE_MEMBER u3)

;; Maximum bounds for security
(define-constant MAX_TOKEN_SUPPLY u1000000000000)
(define-constant MAX_TRANSFER_AMOUNT u1000000000000)
(define-constant MAX_DEPOSIT_AMOUNT u1000000000000)
(define-constant MAX_WITHDRAWAL_AMOUNT u1000000000000)
(define-constant MAX_SIGNATURES u10)
(define-constant MAX_MEMBERS u1000000)
(define-constant MAX_VOTES u1000000000000)

;; Additional security constants
(define-constant MIN_TOKEN_SUPPLY u1)
(define-constant MIN_TRANSFER_AMOUNT u1)
(define-constant MIN_DEPOSIT_AMOUNT u1)
(define-constant MIN_WITHDRAWAL_AMOUNT u1)
(define-constant MAX_STRING_LENGTH u280)
(define-constant MAX_TITLE_LENGTH u100)
(define-constant MAX_NAME_LENGTH u50)
(define-constant MAX_PURPOSE_LENGTH u100)
(define-constant MAX_TYPE_LENGTH u20)

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

;; ===== ENHANCED VALIDATION HELPERS =====
(define-private (is-valid-dao-id (dao-id uint))
  (and (> dao-id u0) (< dao-id (var-get next-dao-id)))
)

(define-private (is-valid-proposal-id (proposal-id uint))
  (and (> proposal-id u0) (< proposal-id (var-get next-proposal-id)))
)

(define-private (is-valid-tx-id (tx-id uint))
  (and (> tx-id u0) (< tx-id (var-get next-tx-id)))
)

(define-private (is-non-empty-string (str (string-utf8 280)))
  (and (> (len str) u0) (<= (len str) MAX_STRING_LENGTH))
)

(define-private (is-non-empty-string-50 (str (string-utf8 50)))
  (and (> (len str) u0) (<= (len str) MAX_NAME_LENGTH))
)

(define-private (is-non-empty-string-100 (str (string-utf8 100)))
  (and (> (len str) u0) (<= (len str) MAX_TITLE_LENGTH))
)

(define-private (is-valid-amount (amount uint))
  (and (> amount u0) (<= amount MAX_WITHDRAWAL_AMOUNT))
)

(define-private (is-valid-token-amount (amount uint))
  (and (>= amount MIN_TOKEN_SUPPLY) (<= amount MAX_TOKEN_SUPPLY))
)

(define-private (is-valid-role (role uint))
  (or (is-eq role ROLE_ADMIN) (is-eq role ROLE_TREASURER) (is-eq role ROLE_MEMBER))
)

(define-private (is-valid-signature-count (count uint))
  (and (> count u0) (<= count MAX_SIGNATURES))
)

(define-private (is-valid-vote-count (count uint))
  (and (>= count u0) (<= count MAX_VOTES))
)

(define-private (is-valid-member-count (count uint))
  (and (> count u0) (<= count MAX_MEMBERS))
)

(define-private (is-valid-block-height (height uint))
  (and (>= height u0) (<= height u4294967295)) ;; Max uint value
)

;; Enhanced data validation functions
(define-private (validate-dao-data (dao-data (tuple (name (string-utf8 50)) (admin principal) (total-members uint) (token-supply uint))))
  (and 
    (is-non-empty-string-50 (get name dao-data))
    (is-valid-member-count (get total-members dao-data))
    (is-valid-token-amount (get token-supply dao-data))
  )
)

(define-private (validate-proposal-data (prop-data (tuple 
    (title (string-utf8 100))
    (description (string-utf8 280))
    (creator principal)
    (yes-votes uint) 
    (no-votes uint) 
    (executed bool))))
  (and 
    (is-non-empty-string-100 (get title prop-data))
    (is-non-empty-string (get description prop-data))
    (is-valid-vote-count (get yes-votes prop-data))
    (is-valid-vote-count (get no-votes prop-data))
  )
)

(define-private (validate-enhanced-proposal-data (prop-data (tuple 
    (title (string-utf8 100))
    (description (string-utf8 280))
    (creator principal)
    (yes-votes uint) 
    (no-votes uint) 
    (total-voters uint) 
    (executed bool) 
    (created-at uint) 
    (voting-ends-at uint) 
    (execution-deadline uint)
    (proposal-type (string-ascii 20))
    (target-amount (optional uint))
    (target-recipient (optional principal)))))
  (and 
    (is-non-empty-string-100 (get title prop-data))
    (is-non-empty-string (get description prop-data))
    (is-valid-vote-count (get yes-votes prop-data))
    (is-valid-vote-count (get no-votes prop-data))
    (<= (get total-voters prop-data) MAX_MEMBERS)
    (is-valid-block-height (get created-at prop-data))
    (is-valid-block-height (get voting-ends-at prop-data))
    (is-valid-block-height (get execution-deadline prop-data))
    (> (get voting-ends-at prop-data) (get created-at prop-data))
    (> (get execution-deadline prop-data) (get voting-ends-at prop-data))
    (< (len (get proposal-type prop-data)) u21)
  )
)

(define-private (validate-treasury-config (config-data (tuple (required-signatures uint) (max-single-withdrawal uint) (daily-withdrawal-limit uint) (emergency-multisig-required uint))))
  (and
    (is-valid-signature-count (get required-signatures config-data))
    (is-valid-amount (get max-single-withdrawal config-data))
    (is-valid-amount (get daily-withdrawal-limit config-data))
    (is-valid-signature-count (get emergency-multisig-required config-data))
  )
)

(define-private (validate-transaction-data (tx-data (tuple 
    (amount uint)
    (recipient principal)
    (purpose (string-utf8 100))
    (created-by principal)
    (created-at uint)
    (required-sigs uint)
    (current-sigs uint)
    (executed bool)
    (expired bool)
    (tx-type (string-ascii 20)))))
  (and
    (is-valid-amount (get amount tx-data))
    (is-non-empty-string-100 (get purpose tx-data))
    (is-valid-signature-count (get required-sigs tx-data))
    (<= (get current-sigs tx-data) (get required-sigs tx-data))
    (< (len (get tx-type tx-data)) u21)
    (is-valid-block-height (get created-at tx-data))
  )
)

;; Safe arithmetic operations with enhanced validation
(define-private (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (and (>= result a) (>= result b)) ;; Enhanced overflow check
      (ok result)
      (err ERR_OVERFLOW)
    )
  )
)

(define-private (safe-subtract (a uint) (b uint))
  (if (>= a b)
    (ok (- a b))
    (err ERR_INSUFFICIENT_BALANCE)
  )
)

(define-private (safe-multiply (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (ok u0)
    (let ((result (* a b)))
      (if (is-eq (/ result a) b) ;; Check for overflow
        (ok result)
        (err ERR_OVERFLOW)
      )
    )
  )
)

;; Enhanced safe data access helpers with comprehensive validation
(define-private (safe-get-dao (dao-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
    (match (map-get? daos { dao-id: dao-id })
      dao-data (if (validate-dao-data dao-data)
                 (ok dao-data)
                 (err ERR_INVALID_DATA))
      (err ERR_NOT_FOUND)
    )
  )
)

(define-private (safe-get-proposal (dao-id uint) (proposal-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
    (asserts! (is-valid-proposal-id proposal-id) (err ERR_INVALID_PROPOSAL_ID))
    (match (map-get? proposals { dao-id: dao-id, proposal-id: proposal-id })
      prop-data (if (validate-proposal-data prop-data)
                  (ok prop-data)
                  (err ERR_INVALID_DATA))
      (err ERR_NOT_FOUND)
    )
  )
)

(define-private (safe-get-enhanced-proposal (dao-id uint) (proposal-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
    (asserts! (is-valid-proposal-id proposal-id) (err ERR_INVALID_PROPOSAL_ID))
    (match (map-get? enhanced-proposals { dao-id: dao-id, proposal-id: proposal-id })
      prop-data (if (validate-enhanced-proposal-data prop-data)
                  (ok prop-data)
                  (err ERR_INVALID_DATA))
      (err ERR_NOT_FOUND)
    )
  )
)

(define-private (safe-get-pending-transaction (dao-id uint) (tx-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
    (asserts! (is-valid-tx-id tx-id) (err ERR_INVALID_PROPOSAL_ID))
    (match (map-get? pending-transactions { dao-id: dao-id, tx-id: tx-id })
      tx-data (if (validate-transaction-data tx-data)
                (ok tx-data)
                (err ERR_INVALID_DATA))
      (err ERR_NOT_FOUND)
    )
  )
)

(define-private (safe-get-treasury-config (dao-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
    (match (map-get? treasury-config { dao-id: dao-id })
      config-data (if (validate-treasury-config config-data)
                    (ok config-data)
                    (err ERR_INVALID_DATA))
      (err ERR_NOT_FOUND)
    )
  )
)

;; Safe balance retrieval with validation
(define-private (safe-get-balance (dao-id uint) (user principal))
  (begin
    (asserts! (is-valid-dao-id dao-id) u0)
    (let ((balance (default-to u0 (get tokens (map-get? dao-members { dao-id: dao-id, member: user })))))
      (if (is-valid-token-amount balance)
        balance
        u0
      )
    )
  )
)

;; Safe treasury balance retrieval
(define-private (safe-get-treasury-balance (dao-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) u0)
    (let ((balance (default-to u0 (get balance (map-get? dao-treasury { dao-id: dao-id })))))
      (if (<= balance MAX_WITHDRAWAL_AMOUNT)
        balance
        u0
      )
    )
  )
)

;; Safe member role retrieval with validation
(define-private (safe-get-member-role (dao-id uint) (member principal))
  (begin
    (asserts! (is-valid-dao-id dao-id) ROLE_MEMBER)
    (let (
      (role-data (map-get? member-roles { dao-id: dao-id, member: member }))
    )
      (match role-data
        role-info (let (
          (role (get role role-info))
        )
          (if (is-valid-role role)
            role
            ROLE_MEMBER
          )
        )
        ROLE_MEMBER
      )
    )
  )
)

;; Safe daily withdrawal retrieval with validation
(define-private (safe-get-daily-withdrawn (dao-id uint) (date uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) u0)
    (let (
      (withdrawn (default-to u0 (get total-withdrawn (map-get? daily-withdrawals { dao-id: dao-id, date: date }))))
    )
      (if (<= withdrawn MAX_WITHDRAWAL_AMOUNT)
        withdrawn
        u0
      )
    )
  )
)

;; ===== DAO CREATION =====
(define-public (create-dao (name (string-utf8 50)) (initial-token-supply uint))
  (let (
    (id (var-get next-dao-id))
    (sender tx-sender)
  )
    (begin
      ;; Enhanced input validation
      (asserts! (is-non-empty-string-50 name) (err ERR_EMPTY_STRING))
      (asserts! (is-valid-token-amount initial-token-supply) (err ERR_INVALID_AMOUNT))
      (asserts! (< id MAX_MEMBERS) (err ERR_OVERFLOW)) ;; Prevent DAO ID overflow
      
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
      
      ;; Setup default treasury configuration with validation
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
  (safe-get-balance dao-id user)
)

(define-public (transfer-token (dao-id uint) (to principal) (amount uint))
  (let (
    (from-bal (safe-get-balance dao-id tx-sender))
    (to-bal (safe-get-balance dao-id to))
  )
    (begin
      ;; Enhanced input validation
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (is-valid-amount amount) (err ERR_INVALID_AMOUNT))
      (asserts! (<= amount MAX_TRANSFER_AMOUNT) (err ERR_INVALID_AMOUNT))
      (asserts! (>= from-bal amount) (err ERR_INSUFFICIENT_BALANCE))
      (asserts! (> from-bal u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (not (is-eq tx-sender to)) (err ERR_INVALID_AMOUNT))
      
      ;; Validate DAO exists
      (try! (safe-get-dao dao-id))
      
      ;; Safe arithmetic for balance updates
      (match (safe-subtract from-bal amount)
        new-from-bal (match (safe-add to-bal amount)
          new-to-bal (begin
            ;; Update sender's balance
            (map-set dao-members
              { dao-id: dao-id, member: tx-sender }
              { tokens: new-from-bal }
            )
            
            ;; Update recipient's balance
            (map-set dao-members
              { dao-id: dao-id, member: to }
              { tokens: new-to-bal }
            )
            
            ;; Update member count if new member
            (if (is-eq to-bal u0)
              (match (safe-get-dao dao-id)
                dao-info (begin
                  (let ((current-members (get total-members dao-info)))
                    (if (is-valid-member-count current-members)
                      (match (safe-add current-members u1)
                        new-member-count (begin
                          (asserts! (<= new-member-count MAX_MEMBERS) (err ERR_OVERFLOW))
                          (map-set daos
                            { dao-id: dao-id }
                            (merge dao-info { total-members: new-member-count })
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
                        error false
                      )
                      false
                    )
                  )
                )
                error false
              )
              true
            )
            
            (ok true)
          )
          error (err error)
        )
        error (err error)
      )
    )
  )
)

;; ===== ENHANCED GOVERNANCE FUNCTIONS =====

;; Get proposal state with safe data access
(define-read-only (get-proposal-state (dao-id uint) (proposal-id uint))
  (let (
    (current-block stacks-block-height)
  )
    (match (safe-get-enhanced-proposal dao-id proposal-id)
      prop (match (safe-get-dao dao-id)
        dao-info (let (
          (voting-ends-at (get voting-ends-at prop))
          (execution-deadline (get execution-deadline prop))
          (executed (get executed prop))
          (total-members (get total-members dao-info))
          (total-voters (get total-voters prop))
          (yes-votes (get yes-votes prop))
          (no-votes (get no-votes prop))
        )
          (if (and (is-valid-block-height voting-ends-at)
                   (is-valid-block-height execution-deadline)
                   (is-valid-member-count total-members)
                   (is-valid-vote-count yes-votes)
                   (is-valid-vote-count no-votes)
                   (<= total-voters MAX_MEMBERS))
            (let (
              (voting-ended (>= current-block voting-ends-at))
              (execution-expired (>= current-block execution-deadline))
            )
              (match (safe-multiply total-voters u100)
                voter-percentage (match (safe-multiply total-members MIN_QUORUM_PERCENTAGE)
                  quorum-threshold (let (
                    (quorum-met (>= voter-percentage quorum-threshold))
                  )
                    (if executed
                      "executed"
                      (if execution-expired
                        "expired"
                        (if voting-ended
                          (if (and (> yes-votes no-votes) quorum-met)
                            "passed"
                            "failed")
                          "active"))))
                  error-code "calculation-error")
                error-code "calculation-error"))
            "invalid-data"))
        error-code "dao-not-found")
      error-code "not-found")))

;; Enhanced proposal submission with comprehensive validation
(define-public (submit-enhanced-proposal 
  (dao-id uint) 
  (title (string-utf8 100)) 
  (description (string-utf8 280))
  (proposal-type (string-ascii 20))
  (target-amount (optional uint))
  (target-recipient (optional principal)))
  (let (
    (pid (var-get next-proposal-id))
    (member-bal (safe-get-balance dao-id tx-sender))
    (current-block stacks-block-height)
  )
    (begin
      ;; Enhanced input validation
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (> member-bal u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (is-non-empty-string-100 title) (err ERR_EMPTY_STRING))
      (asserts! (is-non-empty-string description) (err ERR_EMPTY_STRING))
      (asserts! (< (len proposal-type) u21) (err ERR_INVALID_DATA))
      (asserts! (< pid MAX_VOTES) (err ERR_OVERFLOW)) ;; Prevent proposal ID overflow
      
      ;; Validate DAO exists
      (try! (safe-get-dao dao-id))
      
      ;; Validate proposal type specific requirements
      (if (is-eq proposal-type "treasury")
        (begin
          (asserts! (is-some target-amount) (err ERR_INVALID_AMOUNT))
          (asserts! (is-some target-recipient) (err ERR_UNAUTHORIZED))
          (let ((amount (unwrap! target-amount (err ERR_INVALID_AMOUNT))))
            (begin
              (asserts! (is-valid-amount amount) (err ERR_INVALID_AMOUNT))
              (asserts! (<= amount (safe-get-treasury-balance dao-id)) (err ERR_INSUFFICIENT_BALANCE))
            )
          )
        )
        true
      )
      
      ;; Safe arithmetic for deadline calculation
      (match (safe-add current-block VOTING_PERIOD)
        voting-end (match (safe-add voting-end EXECUTION_WINDOW)
          execution-deadline (begin
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
                voting-ends-at: voting-end,
                execution-deadline: execution-deadline,
                proposal-type: proposal-type,
                target-amount: target-amount,
                target-recipient: target-recipient
              }
            )
            (var-set next-proposal-id (+ pid u1))
            (ok pid)
          )
          error (err error)
        )
        error (err error)
      )
    )
  )
)

;; Enhanced voting with comprehensive validation
(define-public (vote-enhanced-proposal (dao-id uint) (proposal-id uint) (support bool))
  (let (
    (voter tx-sender)
    (weight (safe-get-balance dao-id voter))
    (already-voted? (is-some (map-get? proposal-votes { dao-id: dao-id, proposal-id: proposal-id, voter: voter })))
    (current-block stacks-block-height)
  )
    (begin
      ;; Enhanced validation
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (is-valid-proposal-id proposal-id) (err ERR_INVALID_PROPOSAL_ID))
      (asserts! (> weight u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (not already-voted?) (err ERR_ALREADY_VOTED))
      
      (match (safe-get-enhanced-proposal dao-id proposal-id)
        prop (begin
          ;; Check voting period with validated data
          (let (
            (voting-ends-at (get voting-ends-at prop))
            (executed (get executed prop))
            (current-yes (get yes-votes prop))
            (current-no (get no-votes prop))
            (current-voters (get total-voters prop))
          )
            (begin
              ;; Validate all data before use
              (asserts! (is-valid-block-height voting-ends-at) (err ERR_INVALID_DATA))
              (asserts! (< current-block voting-ends-at) (err ERR_PROPOSAL_EXPIRED))
              (asserts! (not executed) (err ERR_ALREADY_EXECUTED))
              (asserts! (is-valid-vote-count current-yes) (err ERR_INVALID_DATA))
              (asserts! (is-valid-vote-count current-no) (err ERR_INVALID_DATA))
              (asserts! (<= current-voters MAX_MEMBERS) (err ERR_INVALID_DATA))
            )
          )
          
          ;; Record vote
          (map-set proposal-votes
            { dao-id: dao-id, proposal-id: proposal-id, voter: voter }
            { vote: support }
          )
          
          ;; Safe arithmetic for vote counting with validation
          (let (
            (current-yes (get yes-votes prop))
            (current-no (get no-votes prop))
            (current-voters (get total-voters prop))
          )
            (if support
              (match (safe-add current-yes weight)
                new-yes (match (safe-add current-voters u1)
                  new-voter-count (begin
                    (asserts! (<= new-yes MAX_VOTES) (err ERR_OVERFLOW))
                    (asserts! (<= new-voter-count MAX_MEMBERS) (err ERR_OVERFLOW))
                    (map-set enhanced-proposals 
                      { dao-id: dao-id, proposal-id: proposal-id }
                      (merge prop { 
                        yes-votes: new-yes,
                        total-voters: new-voter-count
                      })
                    )
                    (ok weight)
                  )
                  error (err error)
                )
                error (err error)
              )
              (match (safe-add current-no weight)
                new-no (match (safe-add current-voters u1)
                  new-voter-count (begin
                    (asserts! (<= new-no MAX_VOTES) (err ERR_OVERFLOW))
                    (asserts! (<= new-voter-count MAX_MEMBERS) (err ERR_OVERFLOW))
                    (map-set enhanced-proposals 
                      { dao-id: dao-id, proposal-id: proposal-id }
                      (merge prop { 
                        no-votes: new-no,
                        total-voters: new-voter-count
                      })
                    )
                    (ok weight)
                  )
                  error (err error)
                )
                error (err error)
              )
            )
          )
        )
        error (err error)
      )
    )
  )
)

;; Auto-execution function with enhanced validation
(define-public (execute-enhanced-proposal (dao-id uint) (proposal-id uint))
  (let (
    (state (get-proposal-state dao-id proposal-id))
  )
    (begin
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (is-valid-proposal-id proposal-id) (err ERR_INVALID_PROPOSAL_ID))
      (asserts! (is-eq state "passed") (err ERR_NOT_ENOUGH_VOTES))
      
      (match (safe-get-enhanced-proposal dao-id proposal-id)
        prop (begin
          ;; Mark as executed first
          (map-set enhanced-proposals 
            { dao-id: dao-id, proposal-id: proposal-id }
            (merge prop { executed: true })
          )
          
          ;; Execute based on proposal type with validation
          (let (
            (prop-type (get proposal-type prop))
          )
            (if (is-eq prop-type "treasury")
              ;; Treasury proposal - create multisig transaction
              (match (get target-amount prop)
                amount (match (get target-recipient prop)
                  recipient (begin
                    (asserts! (is-valid-amount amount) (err ERR_INVALID_AMOUNT))
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
        )
        error-code (err error-code)
      )
    )
  )
)

;; ===== MULTI-SIGNATURE TREASURY FUNCTIONS =====

;; Setup treasury configuration with enhanced validation
(define-public (setup-treasury-config 
  (dao-id uint)
  (required-sigs uint)
  (max-single uint)
  (daily-limit uint)
  (emergency-sigs uint))
  (begin
    ;; Enhanced input validation
    (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
    (asserts! (is-valid-signature-count required-sigs) (err ERR_INVALID_AMOUNT))
    (asserts! (is-valid-signature-count emergency-sigs) (err ERR_INVALID_AMOUNT))
    (asserts! (is-valid-amount max-single) (err ERR_INVALID_AMOUNT))
    (asserts! (is-valid-amount daily-limit) (err ERR_INVALID_AMOUNT))
    
    ;; Only admin can setup
    (match (safe-get-dao dao-id)
      dao (begin
        (let ((admin (get admin dao)))
          (asserts! (is-eq tx-sender admin) (err ERR_UNAUTHORIZED))
        )
        
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
      error (err error)
    )
  )
)

;; Assign roles with enhanced validation
(define-public (assign-role (dao-id uint) (member principal) (role uint))
  (let (
    (caller-role (safe-get-member-role dao-id tx-sender))
  )
    (begin
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (is-eq caller-role ROLE_ADMIN) (err ERR_UNAUTHORIZED))
      (asserts! (> (safe-get-balance dao-id member) u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (is-valid-role role) (err ERR_INVALID_AMOUNT))
      
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

;; Create withdrawal request with comprehensive validation
(define-public (request-withdrawal 
  (dao-id uint) 
  (amount uint) 
  (recipient principal) 
  (purpose (string-utf8 100)))
  (let (
    (tx-id (var-get next-tx-id))
    (caller-role (safe-get-member-role dao-id tx-sender))
    (current-balance (safe-get-treasury-balance dao-id))
    (today (/ stacks-block-height u144))
    (daily-withdrawn (safe-get-daily-withdrawn dao-id today))
  )
    (begin
      ;; Enhanced validation
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (or (is-eq caller-role ROLE_ADMIN) (is-eq caller-role ROLE_TREASURER)) (err ERR_UNAUTHORIZED))
      (asserts! (is-valid-amount amount) (err ERR_INVALID_AMOUNT))
      (asserts! (<= amount current-balance) (err ERR_INSUFFICIENT_BALANCE))
      (asserts! (is-non-empty-string-100 purpose) (err ERR_EMPTY_STRING))
      (asserts! (< tx-id MAX_VOTES) (err ERR_OVERFLOW)) ;; Prevent tx ID overflow
      
      (match (safe-get-treasury-config dao-id)
        cfg (let (
          (max-single (get max-single-withdrawal cfg))
          (daily-limit (get daily-withdrawal-limit cfg))
          (required-sigs-normal (get required-signatures cfg))
          (emergency-sigs (get emergency-multisig-required cfg))
        )
          (begin
            ;; Validate config data before use
            (asserts! (is-valid-amount max-single) (err ERR_INVALID_DATA))
            (asserts! (is-valid-amount daily-limit) (err ERR_INVALID_DATA))
            (asserts! (is-valid-signature-count required-sigs-normal) (err ERR_INVALID_DATA))
            (asserts! (is-valid-signature-count emergency-sigs) (err ERR_INVALID_DATA))
            (asserts! (<= daily-withdrawn MAX_WITHDRAWAL_AMOUNT) (err ERR_INVALID_DATA))
            
            (let (
              (is-large-withdrawal (> amount max-single))
            )
              (match (safe-add daily-withdrawn amount)
                new-daily-total (let (
                  (exceeds-daily-limit (> new-daily-total daily-limit))
                  (required-sigs (if (or is-large-withdrawal exceeds-daily-limit)
                                   emergency-sigs
                                   required-sigs-normal))
                )
                  (begin
                    ;; Validate recipient is not the contract itself
                    (asserts! (not (is-eq recipient (as-contract tx-sender))) (err ERR_INVALID_DATA))
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
                error (err error)
              )
            )
          )
        )
        error (err error)
      )
    )
  )
)

;; Sign transaction with enhanced validation
(define-public (sign-transaction (dao-id uint) (tx-id uint))
  (let (
    (caller-role (safe-get-member-role dao-id tx-sender))
    (already-signed (is-some (map-get? transaction-signatures { dao-id: dao-id, tx-id: tx-id, signer: tx-sender })))
  )
    (begin
      ;; Enhanced validation
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (is-valid-tx-id tx-id) (err ERR_INVALID_PROPOSAL_ID))
      (asserts! (or (is-eq caller-role ROLE_ADMIN) (is-eq caller-role ROLE_TREASURER)) (err ERR_UNAUTHORIZED))
      (asserts! (not already-signed) (err ERR_ALREADY_VOTED))
      
      (match (safe-get-pending-transaction dao-id tx-id)
        tx (begin
          (let (
            (executed (get executed tx))
            (expired (get expired tx))
            (current-sigs (get current-sigs tx))
            (required-sigs (get required-sigs tx))
          )
            (begin
              ;; Validate transaction data before use
              (asserts! (not executed) (err ERR_ALREADY_EXECUTED))
              (asserts! (not expired) (err ERR_ALREADY_EXECUTED))
              (asserts! (<= current-sigs MAX_SIGNATURES) (err ERR_INVALID_DATA))
              (asserts! (is-valid-signature-count required-sigs) (err ERR_INVALID_DATA))
            )
          )
          
          ;; Record signature
          (map-set transaction-signatures
            { dao-id: dao-id, tx-id: tx-id, signer: tx-sender }
            {
              signed-at: stacks-block-height
            }
          )
          
          ;; Safe arithmetic for signature count
          (let ((current-sigs (get current-sigs tx)))
            (match (safe-add current-sigs u1)
              new-sig-count (begin
                (asserts! (<= new-sig-count MAX_SIGNATURES) (err ERR_OVERFLOW))
                (map-set pending-transactions
                  { dao-id: dao-id, tx-id: tx-id }
                  (merge tx { current-sigs: new-sig-count })
                )
                
                ;; Auto-execute if enough signatures
                (let ((required-sigs (get required-sigs tx)))
                  (if (>= new-sig-count required-sigs)
                    (execute-multisig-transaction dao-id tx-id)
                    (ok true)
                  )
                )
              )
              error (err error)
            )
          )
        )
        error-code (err error-code)
      )
    )
  )
)

;; Execute multisig transaction with comprehensive validation
(define-private (execute-multisig-transaction (dao-id uint) (tx-id uint))
  (let (
    (today (/ stacks-block-height u144))
  )
    (match (safe-get-pending-transaction dao-id tx-id)
      tx-data (let (
        (amount (get amount tx-data))
        (recipient (get recipient tx-data))
        (current-bal (safe-get-treasury-balance dao-id))
      )
        (begin
          ;; Enhanced validation
          (asserts! (is-valid-amount amount) (err ERR_INVALID_DATA))
          (asserts! (>= current-bal amount) (err ERR_INSUFFICIENT_BALANCE))
          
          ;; Mark as executed
          (map-set pending-transactions
            { dao-id: dao-id, tx-id: tx-id }
            (merge tx-data { executed: true })
          )
          
          ;; Safe arithmetic for balance and daily tracking updates
          (match (safe-subtract current-bal amount)
            new-balance (let ((daily-withdrawn (safe-get-daily-withdrawn dao-id today)))
              (match (safe-add daily-withdrawn amount)
                new-daily-total (begin
                  (asserts! (<= new-balance MAX_WITHDRAWAL_AMOUNT) (err ERR_OVERFLOW))
                  (asserts! (<= new-daily-total MAX_WITHDRAWAL_AMOUNT) (err ERR_OVERFLOW))
                  
                  ;; Update treasury balance
                  (map-set dao-treasury 
                    { dao-id: dao-id }
                    { balance: new-balance }
                  )
                  
                  ;; Update daily withdrawal tracking
                  (map-set daily-withdrawals
                    { dao-id: dao-id, date: today }
                    { total-withdrawn: new-daily-total }
                  )
                  
                  ;; Execute the withdrawal
                  (as-contract (stx-transfer? amount tx-sender recipient))
                )
                error (err error)
              )
            )
            error (err error)
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
    (member-bal (safe-get-balance dao-id tx-sender))
  )
    (begin
      ;; Enhanced validation
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (is-non-empty-string-100 title) (err ERR_EMPTY_STRING))
      (asserts! (is-non-empty-string description) (err ERR_EMPTY_STRING))
      (asserts! (> member-bal u0) (err ERR_NOT_DAO_MEMBER))
      (asserts! (< pid MAX_VOTES) (err ERR_OVERFLOW))
      
      ;; Validate DAO exists
      (try! (safe-get-dao dao-id))
      
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
    (weight (safe-get-balance dao-id tx-sender))
  )
    (begin
      ;; Enhanced validation
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (is-valid-proposal-id proposal-id) (err ERR_INVALID_PROPOSAL_ID))
      (asserts! (not already-voted?) (err ERR_ALREADY_VOTED))
      (asserts! (> weight u0) (err ERR_NOT_DAO_MEMBER))
      
      (match (safe-get-proposal dao-id proposal-id)
        prop (begin
          ;; Record the vote
          (map-set proposal-votes
            { dao-id: dao-id, proposal-id: proposal-id, voter: tx-sender }
            { vote: support }
          )
          
          ;; Safe arithmetic for vote counting with validation
          (let (
            (current-yes (get yes-votes prop))
            (current-no (get no-votes prop))
          )
            (begin
              ;; Validate vote counts before use
              (asserts! (is-valid-vote-count current-yes) (err ERR_INVALID_DATA))
              (asserts! (is-valid-vote-count current-no) (err ERR_INVALID_DATA))
              
              (if support
                (match (safe-add current-yes weight)
                  new-yes (begin
                    (asserts! (<= new-yes MAX_VOTES) (err ERR_OVERFLOW))
                    (map-set proposals 
                      { dao-id: dao-id, proposal-id: proposal-id }
                      (merge prop { yes-votes: new-yes })
                    )
                    (ok true)
                  )
                  error (err error)
                )
                (match (safe-add current-no weight)
                  new-no (begin
                    (asserts! (<= new-no MAX_VOTES) (err ERR_OVERFLOW))
                    (map-set proposals 
                      { dao-id: dao-id, proposal-id: proposal-id }
                      (merge prop { no-votes: new-no })
                    )
                    (ok true)
                  )
                  error (err error)
                )
              )
            )
          )
        )
        error (err error)
      )
    )
  )
)

(define-public (execute-proposal (dao-id uint) (proposal-id uint))
  (begin
    ;; Enhanced validation
    (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
    (asserts! (is-valid-proposal-id proposal-id) (err ERR_INVALID_PROPOSAL_ID))
    
    (match (safe-get-proposal dao-id proposal-id)
      prop (begin
        (let (
          (executed (get executed prop))
          (yes-votes (get yes-votes prop))
          (no-votes (get no-votes prop))
        )
          (begin
            ;; Validate proposal data before use
            (asserts! (not executed) (err ERR_ALREADY_EXECUTED))
            (asserts! (is-valid-vote-count yes-votes) (err ERR_INVALID_DATA))
            (asserts! (is-valid-vote-count no-votes) (err ERR_INVALID_DATA))
            (asserts! (> yes-votes no-votes) (err ERR_NOT_ENOUGH_VOTES))
          )
        )

        ;; Mark proposal as executed
        (map-set proposals 
          { dao-id: dao-id, proposal-id: proposal-id }
          (merge prop { executed: true })
        )
        
        (ok true)
      )
      error (err error)
    )
  )
)

;; ===== DAO TREASURY =====
(define-public (deposit-treasury (dao-id uint) (amount uint))
  (begin
    ;; Enhanced validation
    (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
    (asserts! (is-valid-amount amount) (err ERR_INVALID_AMOUNT))
    (asserts! (<= amount MAX_DEPOSIT_AMOUNT) (err ERR_INVALID_AMOUNT))
    
    ;; Validate DAO exists
    (try! (safe-get-dao dao-id))
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Safe arithmetic for balance update
    (let (
      (current-balance (safe-get-treasury-balance dao-id))
    )
      (match (safe-add current-balance amount)
        new-balance (begin
          (asserts! (<= new-balance MAX_WITHDRAWAL_AMOUNT) (err ERR_OVERFLOW))
          (map-set dao-treasury 
            { dao-id: dao-id }
            { balance: new-balance }
          )
          (ok true)
        )
        error (err error)
      )
    )
  )
)

;; Legacy withdraw function (now creates multisig transaction)
(define-public (withdraw-treasury (dao-id uint) (amount uint) (to principal))
  (let (
    (caller tx-sender)
    (current-bal (safe-get-treasury-balance dao-id))
  )
    (begin
      ;; Enhanced validation
      (asserts! (is-valid-dao-id dao-id) (err ERR_INVALID_DAO_ID))
      (asserts! (is-valid-amount amount) (err ERR_INVALID_AMOUNT))
      (asserts! (>= current-bal amount) (err ERR_INSUFFICIENT_BALANCE))
      
      ;; Check if caller is admin using safe data access
      (match (safe-get-dao dao-id)
        dao (begin
          (let ((admin (get admin dao)))
            (asserts! (is-eq caller admin) (err ERR_UNAUTHORIZED))
          )
          ;; Create multisig transaction instead of direct withdrawal
          (request-withdrawal dao-id amount to u"Admin withdrawal")
        )
        error (err error)
      )
    )
  )
)

;; ===== HELPER FUNCTIONS =====
(define-read-only (get-member-role (dao-id uint) (member principal))
  (safe-get-member-role dao-id member)
)

(define-read-only (get-daily-withdrawn (dao-id uint) (date uint))
  (safe-get-daily-withdrawn dao-id date)
)

(define-read-only (get-pending-transaction (dao-id uint) (tx-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) none)
    (asserts! (is-valid-tx-id tx-id) none)
    (map-get? pending-transactions { dao-id: dao-id, tx-id: tx-id })
  )
)

(define-read-only (has-signed-transaction (dao-id uint) (tx-id uint) (signer principal))
  (begin
    (asserts! (is-valid-dao-id dao-id) false)
    (asserts! (is-valid-tx-id tx-id) false)
    (is-some (map-get? transaction-signatures { dao-id: dao-id, tx-id: tx-id, signer: signer }))
  )
)

(define-read-only (get-enhanced-proposal (dao-id uint) (proposal-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) none)
    (asserts! (is-valid-proposal-id proposal-id) none)
    (map-get? enhanced-proposals { dao-id: dao-id, proposal-id: proposal-id })
  )
)

(define-read-only (get-treasury-config (dao-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) none)
    (map-get? treasury-config { dao-id: dao-id })
  )
)

;; ===== READ-ONLY HELPERS =====
(define-read-only (get-dao (dao-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) none)
    (map-get? daos { dao-id: dao-id })
  )
)

(define-read-only (get-proposal (dao-id uint) (proposal-id uint))
  (begin
    (asserts! (is-valid-dao-id dao-id) none)
    (asserts! (is-valid-proposal-id proposal-id) none)
    (map-get? proposals { dao-id: dao-id, proposal-id: proposal-id })
  )
)

(define-read-only (get-treasury (dao-id uint))
  (safe-get-treasury-balance dao-id)
)

(define-read-only (get-vote (dao-id uint) (proposal-id uint) (voter principal))
  (begin
    (asserts! (is-valid-dao-id dao-id) none)
    (asserts! (is-valid-proposal-id proposal-id) none)
    (map-get? proposal-votes { dao-id: dao-id, proposal-id: proposal-id, voter: voter })
  )
)

(define-read-only (has-voted (dao-id uint) (proposal-id uint) (voter principal))
  (begin
    (asserts! (is-valid-dao-id dao-id) false)
    (asserts! (is-valid-proposal-id proposal-id) false)
    (is-some (get-vote dao-id proposal-id voter))
  )
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
