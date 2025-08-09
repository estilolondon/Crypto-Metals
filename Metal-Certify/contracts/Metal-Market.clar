;; Precious Metals Tokenization Smart Contract
;; This contract enables tokenization of precious metals with comprehensive features

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_INVALID_METAL_TYPE (err u105))
(define-constant ERR_VAULT_NOT_AUTHORIZED (err u106))
(define-constant ERR_CERTIFICATE_EXPIRED (err u107))
(define-constant ERR_INVALID_PURITY (err u108))
(define-constant ERR_TRANSFER_FAILED (err u109))
(define-constant ERR_INVALID_PRICE (err u110))
(define-constant ERR_INVALID_INPUT (err u111))

;; Metal types
(define-constant METAL_GOLD u1)
(define-constant METAL_SILVER u2)
(define-constant METAL_PLATINUM u3)
(define-constant METAL_PALLADIUM u4)

;; Data Variables
(define-data-var next-token-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var total-metals-tokenized uint u0)

;; Data Maps
(define-map tokens
  { token-id: uint }
  {
    owner: principal,
    metal-type: uint,
    weight-grams: uint,
    purity: uint, ;; purity in basis points (e.g., 9999 = 99.99%)
    certificate-hash: (buff 32),
    vault-location: (string-ascii 50),
    creation-block: uint,
    last-audit-block: uint,
    market-value-usd: uint ;; value in cents
  }
)

(define-map token-balances
  { owner: principal, token-id: uint }
  { balance: uint }
)

(define-map metal-prices
  { metal-type: uint }
  {
    price-per-gram-usd: uint, ;; price in cents
    last-updated-block: uint
  }
)

(define-map authorized-vaults
  { vault-address: principal }
  {
    name: (string-ascii 50),
    location: (string-ascii 100),
    authorized: bool,
    total-capacity-grams: uint,
    current-holdings-grams: uint
  }
)

(define-map authorized-auditors
  { auditor-address: principal }
  {
    name: (string-ascii 50),
    certification: (string-ascii 100),
    authorized: bool
  }
)

(define-map token-transfer-restrictions
  { token-id: uint }
  {
    restricted: bool,
    restriction-reason: (string-ascii 100)
  }
)

;; Input validation functions
(define-private (is-valid-principal (p principal))
  (not (is-eq p 'SP000000000000000000002Q6VF78))
)

(define-private (is-valid-string (s (string-ascii 50)))
  (> (len s) u0)
)

(define-private (is-valid-long-string (s (string-ascii 100)))
  (> (len s) u0)
)

(define-private (is-valid-reason-string (s (string-ascii 100)))
  (> (len s) u0)
)

(define-private (is-valid-certificate-hash (hash (buff 32)))
  (is-eq (len hash) u32)
)

(define-private (is-valid-token-id (token-id uint))
  (and (> token-id u0) (< token-id (var-get next-token-id)))
)

;; Read-only functions

(define-read-only (get-token-info (token-id uint))
  (map-get? tokens { token-id: token-id })
)

(define-read-only (get-token-balance (owner principal) (token-id uint))
  (default-to u0 (get balance (map-get? token-balances { owner: owner, token-id: token-id })))
)

(define-read-only (get-metal-price (metal-type uint))
  (map-get? metal-prices { metal-type: metal-type })
)

(define-read-only (get-vault-info (vault-address principal))
  (map-get? authorized-vaults { vault-address: vault-address })
)

(define-read-only (get-auditor-info (auditor-address principal))
  (map-get? authorized-auditors { auditor-address: auditor-address })
)

(define-read-only (is-token-restricted (token-id uint))
  (default-to false (get restricted (map-get? token-transfer-restrictions { token-id: token-id })))
)

(define-read-only (get-contract-stats)
  {
    total-tokens: (- (var-get next-token-id) u1),
    total-metals-tokenized: (var-get total-metals-tokenized),
    contract-paused: (var-get contract-paused)
  }
)

(define-read-only (calculate-token-value (token-id uint))
  (match (get-token-info token-id)
    token-info
    (match (get-metal-price (get metal-type token-info))
      price-info
      (let (
        (weight (get weight-grams token-info))
        (purity (get purity token-info))
        (price-per-gram (get price-per-gram-usd price-info))
      )
        (ok (/ (* (* weight price-per-gram) purity) u10000))
      )
      ERR_NOT_FOUND
    )
    ERR_NOT_FOUND
  )
)

(define-read-only (is-valid-metal-type (metal-type uint))
  (or 
    (is-eq metal-type METAL_GOLD)
    (or
      (is-eq metal-type METAL_SILVER)
      (or
        (is-eq metal-type METAL_PLATINUM)
        (is-eq metal-type METAL_PALLADIUM)
      )
    )
  )
)

;; Private functions

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized-vault (vault-address principal))
  (default-to false (get authorized (map-get? authorized-vaults { vault-address: vault-address })))
)

(define-private (is-authorized-auditor (auditor-address principal))
  (default-to false (get authorized (map-get? authorized-auditors { auditor-address: auditor-address })))
)

(define-private (update-vault-holdings (vault-address principal) (weight-change int))
  (match (map-get? authorized-vaults { vault-address: vault-address })
    vault-info
    (let (
      (current-holdings (get current-holdings-grams vault-info))
      (new-holdings (if (> weight-change 0)
                     (+ current-holdings (to-uint weight-change))
                     (- current-holdings (to-uint (- weight-change)))))
    )
      (map-set authorized-vaults
        { vault-address: vault-address }
        (merge vault-info { current-holdings-grams: new-holdings })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; Public functions

;; Administrative functions
(define-public (pause-contract)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (authorize-vault (vault-address principal) (name (string-ascii 50)) (location (string-ascii 100)) (capacity uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal vault-address) ERR_INVALID_INPUT)
    (asserts! (is-valid-string name) ERR_INVALID_INPUT)
    (asserts! (is-valid-long-string location) ERR_INVALID_INPUT)
    (asserts! (> capacity u0) ERR_INVALID_AMOUNT)
    (map-set authorized-vaults
      { vault-address: vault-address }
      {
        name: name,
        location: location,
        authorized: true,
        total-capacity-grams: capacity,
        current-holdings-grams: u0
      }
    )
    (ok true)
  )
)

(define-public (revoke-vault-authorization (vault-address principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal vault-address) ERR_INVALID_INPUT)
    (match (map-get? authorized-vaults { vault-address: vault-address })
      vault-info
      (begin
        (map-set authorized-vaults
          { vault-address: vault-address }
          (merge vault-info { authorized: false })
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (authorize-auditor (auditor-address principal) (name (string-ascii 50)) (certification (string-ascii 100)))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal auditor-address) ERR_INVALID_INPUT)
    (asserts! (is-valid-string name) ERR_INVALID_INPUT)
    (asserts! (is-valid-long-string certification) ERR_INVALID_INPUT)
    (map-set authorized-auditors
      { auditor-address: auditor-address }
      {
        name: name,
        certification: certification,
        authorized: true
      }
    )
    (ok true)
  )
)

(define-public (update-metal-price (metal-type uint) (price-per-gram-usd uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-metal-type metal-type) ERR_INVALID_METAL_TYPE)
    (asserts! (> price-per-gram-usd u0) ERR_INVALID_PRICE)
    (map-set metal-prices
      { metal-type: metal-type }
      {
        price-per-gram-usd: price-per-gram-usd,
        last-updated-block: block-height
      }
    )
    (ok true)
  )
)

;; Token management functions
(define-public (mint-token 
  (recipient principal)
  (metal-type uint)
  (weight-grams uint)
  (purity uint)
  (certificate-hash (buff 32))
  (vault-location (string-ascii 50))
)
  (let (
    (token-id (var-get next-token-id))
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (is-authorized-vault tx-sender) ERR_VAULT_NOT_AUTHORIZED)
    (asserts! (is-valid-principal recipient) ERR_INVALID_INPUT)
    (asserts! (is-valid-metal-type metal-type) ERR_INVALID_METAL_TYPE)
    (asserts! (> weight-grams u0) ERR_INVALID_AMOUNT)
    (asserts! (and (> purity u0) (<= purity u10000)) ERR_INVALID_PURITY)
    (asserts! (is-valid-certificate-hash certificate-hash) ERR_INVALID_INPUT)
    (asserts! (is-valid-string vault-location) ERR_INVALID_INPUT)
    
    ;; Calculate market value
    (match (get-metal-price metal-type)
      price-info
      (let (
        (market-value (/ (* (* weight-grams (get price-per-gram-usd price-info)) purity) u10000))
      )
        ;; Create token
        (map-set tokens
          { token-id: token-id }
          {
            owner: recipient,
            metal-type: metal-type,
            weight-grams: weight-grams,
            purity: purity,
            certificate-hash: certificate-hash,
            vault-location: vault-location,
            creation-block: block-height,
            last-audit-block: block-height,
            market-value-usd: market-value
          }
        )
        
        ;; Set token balance
        (map-set token-balances
          { owner: recipient, token-id: token-id }
          { balance: u1 }
        )
        
        ;; Update vault holdings
        (try! (update-vault-holdings tx-sender (to-int weight-grams)))
        
        ;; Update counters
        (var-set next-token-id (+ token-id u1))
        (var-set total-metals-tokenized (+ (var-get total-metals-tokenized) weight-grams))
        
        (print {
          event: "token-minted",
          token-id: token-id,
          recipient: recipient,
          metal-type: metal-type,
          weight-grams: weight-grams,
          vault: tx-sender
        })
        
        (ok token-id)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (transfer-token (token-id uint) (sender principal) (recipient principal))
  (let (
    (current-balance (get-token-balance sender token-id))
  )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal recipient) ERR_INVALID_INPUT)
    (asserts! (is-valid-token-id token-id) ERR_INVALID_INPUT)
    (asserts! (> current-balance u0) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (is-token-restricted token-id)) ERR_TRANSFER_FAILED)
    
    (match (get-token-info token-id)
      token-info
      (begin
        ;; Remove balance from sender
        (map-delete token-balances { owner: sender, token-id: token-id })
        
        ;; Add balance to recipient
        (map-set token-balances
          { owner: recipient, token-id: token-id }
          { balance: u1 }
        )
        
        ;; Update token owner
        (map-set tokens
          { token-id: token-id }
          (merge token-info { owner: recipient })
        )
        
        (print {
          event: "token-transferred",
          token-id: token-id,
          from: sender,
          to: recipient
        })
        
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (burn-token (token-id uint))
  (begin
    (asserts! (is-valid-token-id token-id) ERR_INVALID_INPUT)
    (match (get-token-info token-id)
      token-info
      (let (
        (token-owner (get owner token-info))
        (weight-grams (get weight-grams token-info))
      )
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (or (is-eq tx-sender token-owner) (is-authorized-vault tx-sender)) ERR_UNAUTHORIZED)
        
        ;; Remove token balance
        (map-delete token-balances { owner: token-owner, token-id: token-id })
        
        ;; Remove token
        (map-delete tokens { token-id: token-id })
        
        ;; Update total metals tokenized
        (var-set total-metals-tokenized (- (var-get total-metals-tokenized) weight-grams))
        
        (print {
          event: "token-burned",
          token-id: token-id,
          owner: token-owner,
          weight-grams: weight-grams
        })
        
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (audit-token (token-id uint) (new-certificate-hash (buff 32)))
  (begin
    (asserts! (is-authorized-auditor tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-valid-token-id token-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-certificate-hash new-certificate-hash) ERR_INVALID_INPUT)
    (match (get-token-info token-id)
      token-info
      (begin
        (map-set tokens
          { token-id: token-id }
          (merge token-info {
            certificate-hash: new-certificate-hash,
            last-audit-block: block-height
          })
        )
        
        (print {
          event: "token-audited",
          token-id: token-id,
          auditor: tx-sender,
          block-height: block-height
        })
        
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (restrict-token (token-id uint) (reason (string-ascii 100)))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-token-id token-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-reason-string reason) ERR_INVALID_INPUT)
    (asserts! (is-some (get-token-info token-id)) ERR_NOT_FOUND)
    
    (map-set token-transfer-restrictions
      { token-id: token-id }
      {
        restricted: true,
        restriction-reason: reason
      }
    )
    
    (print {
      event: "token-restricted",
      token-id: token-id,
      reason: reason
    })
    
    (ok true)
  )
)

(define-public (unrestrict-token (token-id uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-token-id token-id) ERR_INVALID_INPUT)
    (asserts! (is-some (get-token-info token-id)) ERR_NOT_FOUND)
    
    (map-delete token-transfer-restrictions { token-id: token-id })
    
    (print {
      event: "token-unrestricted",
      token-id: token-id
    })
    
    (ok true)
  )
)

;; Batch operations for efficiency
(define-public (batch-mint-tokens 
  (recipients (list 10 principal))
  (metal-types (list 10 uint))
  (weights (list 10 uint))
  (purities (list 10 uint))
  (certificate-hashes (list 10 (buff 32)))
  (vault-locations (list 10 (string-ascii 50)))
)
  (let (
    (results (map mint-single-token-batch
                 recipients
                 metal-types
                 weights
                 purities
                 certificate-hashes
                 vault-locations))
  )
    (ok results)
  )
)

(define-private (mint-single-token-batch
  (recipient principal)
  (metal-type uint)
  (weight-grams uint)
  (purity uint)
  (certificate-hash (buff 32))
  (vault-location (string-ascii 50))
)
  (mint-token recipient metal-type weight-grams purity certificate-hash vault-location)
)

;; Emergency functions
(define-public (emergency-pause)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-paused true)
    (print { event: "emergency-pause", block-height: block-height })
    (ok true)
  )
)

(define-public (update-token-value (token-id uint))
  (begin
    (asserts! (is-valid-token-id token-id) ERR_INVALID_INPUT)
    (match (get-token-info token-id)
      token-info
      (match (get-metal-price (get metal-type token-info))
        price-info
        (let (
          (weight (get weight-grams token-info))
          (purity (get purity token-info))
          (price-per-gram (get price-per-gram-usd price-info))
          (new-market-value (/ (* (* weight price-per-gram) purity) u10000))
        )
          (map-set tokens
            { token-id: token-id }
            (merge token-info { market-value-usd: new-market-value })
          )
          (ok new-market-value)
        )
        ERR_NOT_FOUND
      )
      ERR_NOT_FOUND
    )
  )
)