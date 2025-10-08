(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-insufficient-offset (err u104))
(define-constant err-invalid-price (err u105))
(define-constant err-self-transfer (err u106))
(define-constant err-insufficient-funds (err u107))
(define-constant min-stake-amount u100)
(define-constant stake-lock-period u144)
(define-constant base-reward-rate u5)

(define-constant err-invalid-position (err u202))
(define-constant reward-pool-percentage u10)
(define-constant max-leaderboard-size u50)

(define-constant err-batch-limit (err u400))
(define-constant err-batch-empty (err u401))
(define-constant max-batch-size u10)

(define-data-var leaderboard-season uint u1)
(define-data-var season-reward-pool uint u0)
(define-data-var total-participants uint u0)

(define-data-var total-staked-credits uint u0)
(define-data-var reward-pool uint u0)
(define-data-var next-stake-id uint u1)

(define-data-var next-nft-id uint u1)
(define-data-var carbon-offset-rate uint u10)
(define-data-var total-carbon-offset uint u0)
(define-data-var marketplace-fee uint u250)

(define-constant err-invalid-verification (err u301))
(define-constant err-verification-exists (err u302))
(define-constant err-audit-unauthorized (err u303))
(define-constant min-reputation-score u50)

(define-data-var next-verification-id uint u1)
(define-data-var verification-fee uint u100000)

(define-map nfts
  uint
  {
    owner: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    image-url: (string-ascii 256),
    carbon-footprint: uint,
    created-at: uint
  }
)

(define-map listings
  uint
  {
    seller: principal,
    price: uint,
    carbon-offset-required: uint,
    active: bool
  }
)

(define-map user-carbon-credits
  principal
  uint
)

(define-map carbon-offset-providers
  principal
  {
    name: (string-ascii 64),
    rate-per-credit: uint,
    verified: bool
  }
)

(define-public (mint-nft (title (string-ascii 64)) (description (string-ascii 256)) (image-url (string-ascii 256)) (carbon-footprint uint))
  (let
    (
      (nft-id (var-get next-nft-id))
      (required-offset (* carbon-footprint (var-get carbon-offset-rate)))
    )
    (asserts! (> carbon-footprint u0) err-invalid-price)
    (try! (purchase-carbon-credits tx-sender required-offset))
    (map-set nfts nft-id
      {
        owner: tx-sender,
        title: title,
        description: description,
        image-url: image-url,
        carbon-footprint: carbon-footprint,
        created-at: stacks-block-height
      }
    )
    (var-set next-nft-id (+ nft-id u1))
    (var-set total-carbon-offset (+ (var-get total-carbon-offset) required-offset))
    (ok nft-id)
  )
)

(define-public (list-nft (nft-id uint) (price uint))
  (let
    (
      (nft (unwrap! (map-get? nfts nft-id) err-not-found))
      (carbon-offset-required (* (get carbon-footprint nft) (var-get carbon-offset-rate)))
    )
    (asserts! (is-eq (get owner nft) tx-sender) err-unauthorized)
    (asserts! (> price u0) err-invalid-price)
    (map-set listings nft-id
      {
        seller: tx-sender,
        price: price,
        carbon-offset-required: carbon-offset-required,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (buy-nft (nft-id uint))
  (let
    (
      (nft (unwrap! (map-get? nfts nft-id) err-not-found))
      (listing (unwrap! (map-get? listings nft-id) err-not-found))
      (seller (get seller listing))
      (price (get price listing))
      (carbon-offset-required (get carbon-offset-required listing))
      (marketplace-fee-amount (/ (* price (var-get marketplace-fee)) u10000))
      (seller-amount (- price marketplace-fee-amount))
    )
    (asserts! (get active listing) err-not-found)
    (asserts! (not (is-eq tx-sender seller)) err-self-transfer)
    (try! (stx-transfer? price tx-sender seller))
    (try! (purchase-carbon-credits tx-sender carbon-offset-required))
    (map-set nfts nft-id
      (merge nft { owner: tx-sender })
    )
    (map-set listings nft-id
      (merge listing { active: false })
    )
    (var-set total-carbon-offset (+ (var-get total-carbon-offset) carbon-offset-required))
    (ok true)
  )
)

(define-public (purchase-carbon-credits (buyer principal) (amount uint))
  (let
    (
      (current-credits (default-to u0 (map-get? user-carbon-credits buyer)))
      (credit-cost (* amount u1000000))
    )
    (asserts! (>= (stx-get-balance buyer) credit-cost) err-insufficient-funds)
    (try! (stx-transfer? credit-cost buyer contract-owner))
    (map-set user-carbon-credits buyer (+ current-credits amount))
    (ok true)
  )
)

(define-public (register-offset-provider (name (string-ascii 64)) (rate-per-credit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set carbon-offset-providers tx-sender
      {
        name: name,
        rate-per-credit: rate-per-credit,
        verified: true
      }
    )
    (ok true)
  )
)

(define-public (update-carbon-offset-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set carbon-offset-rate new-rate)
    (ok true)
  )
)

(define-public (update-marketplace-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-price)
    (var-set marketplace-fee new-fee)
    (ok true)
  )
)

(define-public (cancel-listing (nft-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings nft-id) err-not-found))
    )
    (asserts! (is-eq (get seller listing) tx-sender) err-unauthorized)
    (map-set listings nft-id
      (merge listing { active: false })
    )
    (ok true)
  )
)

(define-public (transfer-nft (nft-id uint) (recipient principal))
  (let
    (
      (nft (unwrap! (map-get? nfts nft-id) err-not-found))
      (carbon-offset-required (* (get carbon-footprint nft) (var-get carbon-offset-rate)))
    )
    (asserts! (is-eq (get owner nft) tx-sender) err-unauthorized)
    (asserts! (not (is-eq tx-sender recipient)) err-self-transfer)
    (try! (purchase-carbon-credits tx-sender carbon-offset-required))
    (map-set nfts nft-id
      (merge nft { owner: recipient })
    )
    (var-set total-carbon-offset (+ (var-get total-carbon-offset) carbon-offset-required))
    (ok true)
  )
)

(define-read-only (get-nft (nft-id uint))
  (map-get? nfts nft-id)
)

(define-read-only (get-listing (nft-id uint))
  (map-get? listings nft-id)
)

(define-read-only (get-user-carbon-credits (user principal))
  (default-to u0 (map-get? user-carbon-credits user))
)

(define-read-only (get-carbon-offset-rate)
  (var-get carbon-offset-rate)
)

(define-read-only (get-total-carbon-offset)
  (var-get total-carbon-offset)
)

(define-read-only (get-marketplace-fee)
  (var-get marketplace-fee)
)

(define-read-only (get-next-nft-id)
  (var-get next-nft-id)
)

(define-read-only (get-offset-provider (provider principal))
  (map-get? carbon-offset-providers provider)
)

(define-read-only (calculate-carbon-offset (carbon-footprint uint))
  (* carbon-footprint (var-get carbon-offset-rate))
)

(define-read-only (calculate-credit-cost (amount uint))
  (* amount u1000000)
)

(define-read-only (is-nft-owner (nft-id uint) (user principal))
  (match (map-get? nfts nft-id)
    nft (is-eq (get owner nft) user)
    false
  )
)

(define-read-only (get-nft-carbon-footprint (nft-id uint))
  (match (map-get? nfts nft-id)
    nft (some (get carbon-footprint nft))
    none
  )
)



(define-map stakes
  uint
  {
    staker: principal,
    amount: uint,
    start-block: uint,
    reward-rate: uint,
    active: bool
  }
)

(define-map user-stakes
  principal
  (list 10 uint)
)

(define-public (stake-carbon-credits (amount uint))
  (let
    (
      (stake-id (var-get next-stake-id))
      (user-credits (get-user-carbon-credits tx-sender))
      (current-stakes (default-to (list) (map-get? user-stakes tx-sender)))
    )
    (asserts! (>= amount min-stake-amount) err-invalid-price)
    (asserts! (>= user-credits amount) err-insufficient-offset)
    (map-set user-carbon-credits tx-sender (- user-credits amount))
    (map-set stakes stake-id
      {
        staker: tx-sender,
        amount: amount,
        start-block: stacks-block-height,
        reward-rate: base-reward-rate,
        active: true
      }
    )
    (map-set user-stakes tx-sender (unwrap! (as-max-len? (append current-stakes stake-id) u10) err-already-exists))
    (var-set next-stake-id (+ stake-id u1))
    (var-set total-staked-credits (+ (var-get total-staked-credits) amount))
    (ok stake-id)
  )
)

(define-public (unstake-carbon-credits (stake-id uint))
  (let
    (
      (stake-info (unwrap! (map-get? stakes stake-id) err-not-found))
      (blocks-staked (- stacks-block-height (get start-block stake-info)))
      (rewards (calculate-staking-rewards stake-id))
    )
    (asserts! (is-eq (get staker stake-info) tx-sender) err-unauthorized)
    (asserts! (get active stake-info) err-not-found)
    (asserts! (>= blocks-staked stake-lock-period) err-unauthorized)
    (let
      (
        (total-return (+ (get amount stake-info) rewards))
        (current-credits (get-user-carbon-credits tx-sender))
      )
      (map-set user-carbon-credits tx-sender (+ current-credits total-return))
      (map-set stakes stake-id (merge stake-info { active: false }))
      (var-set total-staked-credits (- (var-get total-staked-credits) (get amount stake-info)))
      (ok total-return)
    )
  )
)

(define-read-only (calculate-staking-rewards (stake-id uint))
  (match (map-get? stakes stake-id)
    stake-info
      (let
        (
          (blocks-staked (- stacks-block-height (get start-block stake-info)))
          (reward-multiplier (/ (* blocks-staked (get reward-rate stake-info)) u10000))
        )
        (/ (* (get amount stake-info) reward-multiplier) u100)
      )
    u0
  )
)

(define-read-only (get-stake-info (stake-id uint))
  (map-get? stakes stake-id)
)

(define-read-only (get-user-stakes (user principal))
  (default-to (list) (map-get? user-stakes user))
)

(define-read-only (get-total-staked-credits)
  (var-get total-staked-credits)
)

(define-map user-carbon-stats
  { user: principal, season: uint }
  {
    total-offset: uint,
    rank: uint,
    last-updated: uint,
    reward-earned: uint
  }
)

(define-map leaderboard-rankings
  { season: uint, rank: uint }
  {
    user: principal,
    carbon-offset: uint,
    percentage-share: uint
  }
)

(define-map season-rewards
  uint
  {
    total-pool: uint,
    distributed: uint,
    active: bool
  }
)

(define-public (record-carbon-offset (user principal) (offset-amount uint))
  (let
    (
      (current-season (var-get leaderboard-season))
      (current-stats (default-to 
        { total-offset: u0, rank: u0, last-updated: u0, reward-earned: u0 }
        (map-get? user-carbon-stats { user: user, season: current-season })
      ))
      (new-total (+ (get total-offset current-stats) offset-amount))
    )
    (map-set user-carbon-stats { user: user, season: current-season }
      (merge current-stats 
        { 
          total-offset: new-total,
          last-updated: stacks-block-height
        }
      )
    )
    (try! (update-user-rank user current-season new-total))
    (ok true)
  )
)

(define-public (update-user-rank (user principal) (season uint) (carbon-offset uint))
  (let
    (
      (new-rank (calculate-user-rank user season carbon-offset))
    )
    (map-set user-carbon-stats { user: user, season: season }
      (merge 
        (unwrap! (map-get? user-carbon-stats { user: user, season: season }) err-not-found)
        { rank: new-rank }
      )
    )
    (map-set leaderboard-rankings { season: season, rank: new-rank }
      {
        user: user,
        carbon-offset: carbon-offset,
        percentage-share: (calculate-reward-percentage new-rank)
      }
    )
    (ok new-rank)
  )
)

(define-private (calculate-user-rank (user principal) (season uint) (carbon-offset uint))
  (fold count-higher-performers (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u1)
)

(define-private (count-higher-performers (rank uint) (current-count uint))
  current-count
)

(define-private (calculate-reward-percentage (rank uint))
  (if (<= rank u3)
    (if (is-eq rank u1) u30 (if (is-eq rank u2) u20 u15))
    (if (<= rank u10) u5 u1)
  )
)

(define-read-only (get-user-stats (user principal) (season uint))
  (map-get? user-carbon-stats { user: user, season: season })
)

(define-read-only (get-leaderboard-position (season uint) (rank uint))
  (map-get? leaderboard-rankings { season: season, rank: rank })
)

(define-read-only (get-current-season)
  (var-get leaderboard-season)
)

(define-read-only (get-season-info (season uint))
  (map-get? season-rewards season)
)


(define-map verification-requests
  uint
  {
    provider: principal,
    offset-amount: uint,
    proof-hash: (string-ascii 64),
    status: (string-ascii 16),
    submitted-at: uint,
    verified-at: uint,
    verifier: (optional principal)
  }
)

(define-map provider-reputation
  principal
  {
    total-verified: uint,
    total-rejected: uint,
    reputation-score: uint,
    last-audit: uint
  }
)

(define-map audit-trail
  { provider: principal, verification-id: uint }
  {
    offset-claimed: uint,
    verified-amount: uint,
    verification-date: uint,
    auditor-notes: (string-ascii 128)
  }
)

(define-public (submit-verification (offset-amount uint) (proof-hash (string-ascii 64)))
  (let
    (
      (verification-id (var-get next-verification-id))
      (fee (var-get verification-fee))
    )
    (try! (stx-transfer? fee tx-sender contract-owner))
    (map-set verification-requests verification-id
      {
        provider: tx-sender,
        offset-amount: offset-amount,
        proof-hash: proof-hash,
        status: "pending",
        submitted-at: stacks-block-height,
        verified-at: u0,
        verifier: none
      }
    )
    (var-set next-verification-id (+ verification-id u1))
    (ok verification-id)
  )
)

(define-public (approve-verification (verification-id uint) (verified-amount uint))
  (let
    (
      (request (unwrap! (map-get? verification-requests verification-id) err-not-found))
      (provider (get provider request))
      (current-rep (default-to 
        { total-verified: u0, total-rejected: u0, reputation-score: u100, last-audit: u0 }
        (map-get? provider-reputation provider)
      ))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status request) "pending") err-invalid-verification)
    (map-set verification-requests verification-id
      (merge request 
        { status: "approved", verified-at: stacks-block-height, verifier: (some tx-sender) }
      )
    )
    (map-set provider-reputation provider
      (merge current-rep
        {
          total-verified: (+ (get total-verified current-rep) u1),
          reputation-score: (calculate-reputation-score provider u1 u0),
          last-audit: stacks-block-height
        }
      )
    )
    (map-set audit-trail { provider: provider, verification-id: verification-id }
      {
        offset-claimed: (get offset-amount request),
        verified-amount: verified-amount,
        verification-date: stacks-block-height,
        auditor-notes: "approved-verification"
      }
    )
    (ok true)
  )
)

(define-private (calculate-reputation-score (provider principal) (approved uint) (rejected uint))
  (let
    (
      (current-rep (default-to 
        { total-verified: u0, total-rejected: u0, reputation-score: u100, last-audit: u0 }
        (map-get? provider-reputation provider)
      ))
      (total-verified (+ (get total-verified current-rep) approved))
      (total-rejected (+ (get total-rejected current-rep) rejected))
      (total-requests (+ total-verified total-rejected))
    )
    (if (> total-requests u0)
      (/ (* total-verified u100) total-requests)
      u100
    )
  )
)

(define-read-only (get-verification-request (verification-id uint))
  (map-get? verification-requests verification-id)
)

(define-read-only (get-provider-reputation (provider principal))
  (map-get? provider-reputation provider)
)

(define-read-only (is-provider-verified (provider principal))
  (match (map-get? provider-reputation provider)
    rep (>= (get reputation-score rep) min-reputation-score)
    false
  )
)


(define-map batch-operations
  uint
  {
    initiator: principal,
    operation-type: (string-ascii 16),
    nft-count: uint,
    total-carbon-offset: uint,
    executed-at: uint
  }
)

(define-data-var next-batch-id uint u1)

(define-public (batch-mint-nfts (nft-data (list 10 {title: (string-ascii 64), description: (string-ascii 256), image-url: (string-ascii 256), carbon-footprint: uint})))
  (let
    (
      (batch-id (var-get next-batch-id))
      (nft-count (len nft-data))
      (total-offset (fold sum-carbon-footprints nft-data u0))
    )
    (asserts! (> nft-count u0) err-batch-empty)
    (asserts! (<= nft-count max-batch-size) err-batch-limit)
    (try! (purchase-carbon-credits tx-sender total-offset))
    (map-set batch-operations batch-id
      {
        initiator: tx-sender,
        operation-type: "batch-mint",
        nft-count: nft-count,
        total-carbon-offset: total-offset,
        executed-at: stacks-block-height
      }
    )
    (var-set next-batch-id (+ batch-id u1))
    (ok (map mint-single-nft nft-data))
  )
)

(define-public (batch-list-nfts (nft-listings (list 10 {nft-id: uint, price: uint})))
  (let
    (
      (listing-count (len nft-listings))
    )
    (asserts! (> listing-count u0) err-batch-empty)
    (asserts! (<= listing-count max-batch-size) err-batch-limit)
    (ok (map list-single-nft nft-listings))
  )
)

(define-private (mint-single-nft (nft-info {title: (string-ascii 64), description: (string-ascii 256), image-url: (string-ascii 256), carbon-footprint: uint}))
  (let
    (
      (nft-id (var-get next-nft-id))
    )
    (map-set nfts nft-id
      {
        owner: tx-sender,
        title: (get title nft-info),
        description: (get description nft-info),
        image-url: (get image-url nft-info),
        carbon-footprint: (get carbon-footprint nft-info),
        created-at: stacks-block-height
      }
    )
    (var-set next-nft-id (+ nft-id u1))
    nft-id
  )
)

(define-private (list-single-nft (listing-info {nft-id: uint, price: uint}))
  (match (map-get? nfts (get nft-id listing-info))
    nft
      (if (is-eq (get owner nft) tx-sender)
        (begin
          (map-set listings (get nft-id listing-info)
            {
              seller: tx-sender,
              price: (get price listing-info),
              carbon-offset-required: (* (get carbon-footprint nft) (var-get carbon-offset-rate)),
              active: true
            }
          )
          true
        )
        false
      )
    false
  )
)

(define-private (sum-carbon-footprints (nft-info {title: (string-ascii 64), description: (string-ascii 256), image-url: (string-ascii 256), carbon-footprint: uint}) (accumulator uint))
  (+ accumulator (* (get carbon-footprint nft-info) (var-get carbon-offset-rate)))
)

(define-read-only (get-batch-operation (batch-id uint))
  (map-get? batch-operations batch-id)
)

(define-read-only (calculate-batch-carbon-cost (carbon-footprints (list 10 uint)))
  (fold add-footprint carbon-footprints u0)
)

(define-private (add-footprint (footprint uint) (total uint))
  (+ total (* footprint (var-get carbon-offset-rate)))
)