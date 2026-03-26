module robot_rental_platform::command_auth_tests {
    use sui::test_scenario::{Self as ts};
    use robot_rental_platform::command_auth::{Self, CommandAuth};

    const ALICE: address = @0xA11CE;
    const BOB: address = @0xB0B;

    #[test]
    fun test_request_challenge() {
        let mut scenario = ts::begin(ALICE);
        { command_auth::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut auth = ts::take_shared<CommandAuth>(&scenario);
            let challenge = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));
            assert!(vector::length(&challenge) == 32, 0);
            ts::return_shared(auth);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_challenge_unique_per_call() {
        let mut scenario = ts::begin(ALICE);
        { command_auth::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut auth = ts::take_shared<CommandAuth>(&scenario);
            let c1 = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));
            let c2 = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));
            assert!(c1 != c2, 0);
            ts::return_shared(auth);
        };

        ts::end(scenario);
    }

    // === NEW TESTS ===

    #[test]
    fun test_challenge_bytes_constant() {
        assert!(command_auth::challenge_bytes() == 32, 0);
    }

    #[test]
    fun test_different_users_get_different_challenges() {
        let mut scenario = ts::begin(ALICE);
        { command_auth::init_for_testing(ts::ctx(&mut scenario)); };

        // ALICE gets a challenge
        ts::next_tx(&mut scenario, ALICE);
        let alice_challenge;
        {
            let mut auth = ts::take_shared<CommandAuth>(&scenario);
            alice_challenge = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));
            ts::return_shared(auth);
        };

        // BOB gets a challenge — should differ (different address bytes in challenge)
        ts::next_tx(&mut scenario, BOB);
        {
            let mut auth = ts::take_shared<CommandAuth>(&scenario);
            let bob_challenge = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));
            assert!(alice_challenge != bob_challenge, 0);
            ts::return_shared(auth);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_multiple_challenges_sequential() {
        let mut scenario = ts::begin(ALICE);
        { command_auth::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut auth = ts::take_shared<CommandAuth>(&scenario);
            let c1 = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));
            let c2 = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));
            let c3 = command_auth::request_challenge(&mut auth, ts::ctx(&mut scenario));
            // All different due to nonce increment
            assert!(c1 != c2, 0);
            assert!(c2 != c3, 1);
            assert!(c1 != c3, 2);
            // All 32 bytes
            assert!(vector::length(&c1) == 32, 3);
            assert!(vector::length(&c2) == 32, 4);
            assert!(vector::length(&c3) == 32, 5);
            ts::return_shared(auth);
        };

        ts::end(scenario);
    }
}
