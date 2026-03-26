module robot_rental_platform::reputation_tests {
    use sui::test_scenario::{Self as ts};
    use sui::clock;
    use robot_rental_platform::reputation::{Self, ReputationRegistry, ReviewReceipt};

    const ALICE: address = @0xA11CE;
    const BOB: address = @0xB0B;
    const CHARLIE: address = @0xC4A1;

    fun dummy_rental_id(scenario: &mut ts::Scenario): ID {
        let uid = object::new(ts::ctx(scenario));
        let id = object::uid_to_inner(&uid);
        object::delete(uid);
        id
    }

    #[test]
    fun test_submit_review_success() {
        let mut scenario = ts::begin(ALICE);
        { reputation::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ReputationRegistry>(&scenario);
            let clk = clock::create_for_testing(ts::ctx(&mut scenario));
            let rental_id = dummy_rental_id(&mut scenario);

            reputation::submit_review(&mut registry, BOB, 4, rental_id, &clk, ts::ctx(&mut scenario));

            let (total_score, review_count, avg) = reputation::get_rating(&registry, BOB);
            assert!(total_score == 4, 0);
            assert!(review_count == 1, 1);
            assert!(avg == 400, 2);

            clock::destroy_for_testing(clk);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = robot_rental_platform::reputation)]
    fun test_invalid_score_too_low() {
        let mut scenario = ts::begin(ALICE);
        { reputation::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ReputationRegistry>(&scenario);
            let clk = clock::create_for_testing(ts::ctx(&mut scenario));
            let rental_id = dummy_rental_id(&mut scenario);

            reputation::submit_review(&mut registry, BOB, 0, rental_id, &clk, ts::ctx(&mut scenario));

            clock::destroy_for_testing(clk);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = robot_rental_platform::reputation)]
    fun test_invalid_score_too_high() {
        let mut scenario = ts::begin(ALICE);
        { reputation::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ReputationRegistry>(&scenario);
            let clk = clock::create_for_testing(ts::ctx(&mut scenario));
            let rental_id = dummy_rental_id(&mut scenario);

            reputation::submit_review(&mut registry, BOB, 6, rental_id, &clk, ts::ctx(&mut scenario));

            clock::destroy_for_testing(clk);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = reputation::ESelfReview)]
    fun test_self_review_fails() {
        let mut scenario = ts::begin(ALICE);
        { reputation::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ReputationRegistry>(&scenario);
            let clk = clock::create_for_testing(ts::ctx(&mut scenario));
            let rental_id = dummy_rental_id(&mut scenario);

            reputation::submit_review(&mut registry, ALICE, 5, rental_id, &clk, ts::ctx(&mut scenario));

            clock::destroy_for_testing(clk);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_get_rating() {
        let mut scenario = ts::begin(ALICE);
        { reputation::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let registry = ts::take_shared<ReputationRegistry>(&scenario);

            // No reviews yet — should return (0, 0, 0)
            let (total_score, review_count, avg) = reputation::get_rating(&registry, BOB);
            assert!(total_score == 0, 0);
            assert!(review_count == 0, 1);
            assert!(avg == 0, 2);

            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_multiple_reviews_average() {
        let mut scenario = ts::begin(ALICE);
        { reputation::init_for_testing(ts::ctx(&mut scenario)); };

        // Alice reviews Bob with score 4
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ReputationRegistry>(&scenario);
            let clk = clock::create_for_testing(ts::ctx(&mut scenario));
            let rental_id = dummy_rental_id(&mut scenario);

            reputation::submit_review(&mut registry, BOB, 4, rental_id, &clk, ts::ctx(&mut scenario));

            clock::destroy_for_testing(clk);
            ts::return_shared(registry);
        };

        // Charlie reviews Bob with score 2
        ts::next_tx(&mut scenario, CHARLIE);
        {
            let mut registry = ts::take_shared<ReputationRegistry>(&scenario);
            let clk = clock::create_for_testing(ts::ctx(&mut scenario));
            let rental_id = dummy_rental_id(&mut scenario);

            reputation::submit_review(&mut registry, BOB, 2, rental_id, &clk, ts::ctx(&mut scenario));

            // total_score = 6, review_count = 2, average_x100 = 300
            let (total_score, review_count, avg) = reputation::get_rating(&registry, BOB);
            assert!(total_score == 6, 0);
            assert!(review_count == 2, 1);
            assert!(avg == 300, 2);

            clock::destroy_for_testing(clk);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_get_total_reviews() {
        let mut scenario = ts::begin(ALICE);
        { reputation::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ReputationRegistry>(&scenario);
            let clk = clock::create_for_testing(ts::ctx(&mut scenario));

            assert!(reputation::get_total_reviews(&registry) == 0, 0);

            let rental_id = dummy_rental_id(&mut scenario);
            reputation::submit_review(&mut registry, BOB, 3, rental_id, &clk, ts::ctx(&mut scenario));

            assert!(reputation::get_total_reviews(&registry) == 1, 1);

            clock::destroy_for_testing(clk);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_has_reviews() {
        let mut scenario = ts::begin(ALICE);
        { reputation::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ReputationRegistry>(&scenario);
            let clk = clock::create_for_testing(ts::ctx(&mut scenario));

            assert!(!reputation::has_reviews(&registry, BOB), 0);

            let rental_id = dummy_rental_id(&mut scenario);
            reputation::submit_review(&mut registry, BOB, 5, rental_id, &clk, ts::ctx(&mut scenario));

            assert!(reputation::has_reviews(&registry, BOB), 1);

            clock::destroy_for_testing(clk);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_review_receipt_minted() {
        let mut scenario = ts::begin(ALICE);
        { reputation::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ReputationRegistry>(&scenario);
            let clk = clock::create_for_testing(ts::ctx(&mut scenario));
            let rental_id = dummy_rental_id(&mut scenario);

            reputation::submit_review(&mut registry, BOB, 5, rental_id, &clk, ts::ctx(&mut scenario));

            clock::destroy_for_testing(clk);
            ts::return_shared(registry);
        };

        // Verify the ReviewReceipt NFT was transferred to ALICE
        ts::next_tx(&mut scenario, ALICE);
        {
            let receipt = ts::take_from_sender<ReviewReceipt>(&scenario);
            ts::return_to_sender(&scenario, receipt);
        };

        ts::end(scenario);
    }
}
