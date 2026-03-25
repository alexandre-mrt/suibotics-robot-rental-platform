module robot_rental_platform::treat_token_tests {
    use sui::test_scenario::{Self as ts};
    use sui::clock;
    use robot_rental_platform::treat_token::{Self, FaucetState};

    const ALICE: address = @0xA11CE;

    #[test]
    fun test_claim_faucet() {
        let mut scenario = ts::begin(ALICE);
        {
            let ctx = ts::ctx(&mut scenario);
            treat_token::init_for_testing(ctx);
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);

            treat_token::claim_faucet(&mut faucet, &clock, ts::ctx(&mut scenario));

            clock::destroy_for_testing(clock);
            ts::return_shared(faucet);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = robot_rental_platform::treat_token)]
    fun test_claim_faucet_rate_limit() {
        let mut scenario = ts::begin(ALICE);
        {
            let ctx = ts::ctx(&mut scenario);
            treat_token::init_for_testing(ctx);
        };

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
}
