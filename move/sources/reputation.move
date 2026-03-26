module robot_rental_platform::reputation {
    use sui::table::{Self, Table};
    use sui::clock::Clock;

    // ===== Errors =====
    const EInvalidScore: u64 = 0;
    const ESelfReview: u64 = 1;
    const EAlreadyReviewed: u64 = 2;

    // ===== Constants =====
    const MIN_SCORE: u8 = 1;
    const MAX_SCORE: u8 = 5;

    // ===== Shared Objects =====
    public struct ReputationRegistry has key {
        id: UID,
        ratings: Table<address, UserRating>,
        reviewed_rentals: Table<ID, bool>,
        total_reviews: u64,
    }

    public struct UserRating has store {
        total_score: u64,
        review_count: u64,
        average_x100: u64,
    }

    // ===== NFTs =====
    public struct ReviewReceipt has key, store {
        id: UID,
        reviewer: address,
        reviewed: address,
        score: u8,
        rental_id: ID,
        timestamp: u64,
    }

    // ===== Events =====
    public struct ReviewSubmitted has copy, drop {
        reviewer: address,
        reviewed: address,
        score: u8,
        rental_id: ID,
    }

    // ===== Init =====
    fun init(ctx: &mut TxContext) {
        let registry = ReputationRegistry {
            id: object::new(ctx),
            ratings: table::new(ctx),
            reviewed_rentals: table::new(ctx),
            total_reviews: 0,
        };
        transfer::share_object(registry);
    }

    // ===== Public Functions =====
    #[allow(lint(self_transfer))]
    public fun submit_review(
        registry: &mut ReputationRegistry,
        reviewed: address,
        score: u8,
        rental_id: ID,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let reviewer = ctx.sender();
        assert!(reviewer != reviewed, ESelfReview);
        assert!(score >= MIN_SCORE && score <= MAX_SCORE, EInvalidScore);
        assert!(!registry.reviewed_rentals.contains(rental_id), EAlreadyReviewed);

        let score_u64 = (score as u64);

        if (!registry.ratings.contains(reviewed)) {
            registry.ratings.add(reviewed, UserRating {
                total_score: score_u64,
                review_count: 1,
                average_x100: score_u64 * 100,
            });
        } else {
            let rating = registry.ratings.borrow_mut(reviewed);
            rating.total_score = rating.total_score + score_u64;
            rating.review_count = rating.review_count + 1;
            rating.average_x100 = (rating.total_score * 100) / rating.review_count;
        };

        registry.total_reviews = registry.total_reviews + 1;
        registry.reviewed_rentals.add(rental_id, true);

        sui::event::emit(ReviewSubmitted {
            reviewer,
            reviewed,
            score,
            rental_id,
        });

        let receipt = ReviewReceipt {
            id: object::new(ctx),
            reviewer,
            reviewed,
            score,
            rental_id,
            timestamp: clock.timestamp_ms(),
        };
        transfer::transfer(receipt, reviewer);
    }

    // ===== Accessors =====
    public fun get_rating(registry: &ReputationRegistry, addr: address): (u64, u64, u64) {
        if (!registry.ratings.contains(addr)) {
            return (0, 0, 0)
        };
        let rating = registry.ratings.borrow(addr);
        (rating.total_score, rating.review_count, rating.average_x100)
    }

    public fun get_total_reviews(registry: &ReputationRegistry): u64 {
        registry.total_reviews
    }

    public fun has_reviews(registry: &ReputationRegistry, addr: address): bool {
        registry.ratings.contains(addr)
    }

    // ===== Test helpers =====
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
