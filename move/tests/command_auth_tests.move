module robot_rental_platform::command_auth_tests {
    use sui::test_scenario::{Self as ts};
    use robot_rental_platform::command_auth::{Self, CommandAuth};

    const ALICE: address = @0xA11CE;

    #[test]
    fun test_request_challenge() {
        let mut scenario = ts::begin(ALICE);
        {
            let ctx = ts::ctx(&mut scenario);
            command_auth::init_for_testing(ctx);
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut auth = ts::take_shared<CommandAuth>(&scenario);

            let challenge = command_auth::request_challenge(
                &mut auth,
                ts::ctx(&mut scenario),
            );

            // Challenge should be 32 bytes
            assert!(vector::length(&challenge) == 32, 0);

            ts::return_shared(auth);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_challenge_unique_per_call() {
        let mut scenario = ts::begin(ALICE);
        {
            let ctx = ts::ctx(&mut scenario);
            command_auth::init_for_testing(ctx);
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut auth = ts::take_shared<CommandAuth>(&scenario);

            let c1 = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));
            let c2 = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));

            // Two challenges should differ (different nonces)
            assert!(c1 != c2, 0);

            ts::return_shared(auth);
        };

        ts::end(scenario);
    }
}
