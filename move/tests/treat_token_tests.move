module robot_rental_platform::treat_token_tests {
    use sui::test_scenario::{Self as ts};
    use sui::clock;
    use sui::coin::Coin;
    use robot_rental_platform::treat_token::{Self, FaucetState, TREAT_TOKEN};

    const ALICE: address = @0xA11CE;
    const BOB: address = @0xB0B;

    #[test]
    fun test_claim_faucet() {
        let mut scenario = ts::begin(ALICE);
        { treat_token::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            clock::destroy_for_testing(clock);
            ts::return_shared(faucet);
        };

        // Verify tokens received
        ts::next_tx(&mut scenario, ALICE);
        {
            let coin = ts::take_from_sender<Coin<TREAT_TOKEN>>(&scenario);
            assert!(coin.value() == 100_000_000_000, 0); // 100 TREAT
            ts::return_to_sender(&scenario, coin);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = robot_rental_platform::treat_token)]
    fun test_claim_faucet_rate_limit() {
        let mut scenario = ts::begin(ALICE);
        { treat_token::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);

            // Claim 5 times (max per epoch)
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            // 6th claim should fail
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));

            clock::destroy_for_testing(clock);
            ts::return_shared(faucet);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_claim_five_times_success() {
        let mut scenario = ts::begin(ALICE);
        { treat_token::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);

            // All 5 claims should succeed
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));

            clock::destroy_for_testing(clock);
            ts::return_shared(faucet);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_two_users_independent_limits() {
        let mut scenario = ts::begin(ALICE);
        { treat_token::init_for_testing(ts::ctx(&mut scenario)); };

        // ALICE claims 5 times
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            let mut i = 0u64;
            while (i < 5) {
                treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
                i = i + 1;
            };
            clock::destroy_for_testing(clock);
            ts::return_shared(faucet);
        };

        // BOB can still claim (independent)
        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));
            clock::destroy_for_testing(clock);
            ts::return_shared(faucet);
        };

        ts::next_tx(&mut scenario, BOB);
        {
            let coin = ts::take_from_sender<Coin<TREAT_TOKEN>>(&scenario);
            assert!(coin.value() == 100_000_000_000, 0);
            ts::return_to_sender(&scenario, coin);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_accessors() {
        assert!(treat_token::treat_per_claim() == 100_000_000_000, 0);
        assert!(treat_token::claims_per_epoch() == 5, 1);
        assert!(treat_token::e_faucet_rate_limit() == 0, 2);
    }

    #[test]
    fun test_mint_for_testing() {
        let mut scenario = ts::begin(ALICE);
        { treat_token::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let coin = treat_token::mint_for_testing(&mut faucet, 42_000_000_000, ts::ctx(&mut scenario));
            assert!(coin.value() == 42_000_000_000, 0);
            transfer::public_transfer(coin, ALICE);
            ts::return_shared(faucet);
        };

        ts::end(scenario);
    }
}
