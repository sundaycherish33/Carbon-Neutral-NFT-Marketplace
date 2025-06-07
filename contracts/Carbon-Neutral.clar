(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-insufficient-offset (err u104))
(define-constant err-invalid-price (err u105))
(define-constant err-self-transfer (err u106))
(define-constant err-insufficient-funds (err u107))

(define-data-var next-nft-id uint u1)
(define-data-var carbon-offset-rate uint u10)
(define-data-var total-carbon-offset uint u0)
(define-data-var marketplace-fee uint u250)

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
