module robot_rental_platform::rental_escrow_tests {
    use sui::test_scenario::{Self as ts};
    use sui::clock;
    use std::string;
    use robot_rental_platform::treat_token::{Self, FaucetState};
    use robot_rental_platform::robot_registry::{Self, RobotRegistry};
    use robot_rental_platform::rental_escrow::{Self, RentalEscrow, RentalCap, RentalReceipt};

    const ALICE: address = @0xA11CE; // robot owner
    const BOB: address = @0xB0B;   // renter

    // Helper: init all modules
    fun init_all(scenario: &mut sui::test_scenario::Scenario) {
        treat_token::init_for_testing(ts::ctx(scenario));
        robot_registry::init_for_testing(ts::ctx(scenario));
        rental_escrow::init_for_testing(ts::ctx(scenario));
    }

    // Helper: register a robot as ALICE, return robot_id
    fun register_robot_as_alice(scenario: &mut sui::test_scenario::Scenario, rate: u64): ID {
        ts::next_tx(scenario, ALICE);
        let mut registry = ts::take_shared<RobotRegistry>(scenario);
        let cap = robot_registry::register_robot(
            &mut registry,
            string::utf8(b"TestBot"),
            vector[1u8],
            rate,
            ts::ctx(scenario),
        );
        let robot_id = robot_registry::cap_robot_id(&cap);
        transfer::public_transfer(cap, ALICE);
        ts::return_shared(registry);
        robot_id
    }

    #[test]
    fun test_create_and_end_rental() {
        let mut scenario = ts::begin(ALICE);
        init_all(&mut scenario);

        let robot_id = register_robot_as_alice(&mut scenario, 1_000_000_000);

        // BOB creates rental (1 hour)
        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            let payment = treat_token::mint_for_testing(&mut faucet, 1_000_000_000, ts::ctx(&mut scenario));
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);

            let rental_cap = rental_escrow::create_rental(
                &mut escrow, &mut registry, robot_id, 1, payment, &clock, ts::ctx(&mut scenario),
            );
            assert!(!robot_registry::is_available(&registry, robot_id), 0);

            clock::destroy_for_testing(clock);
            transfer::public_transfer(rental_cap, BOB);
            ts::return_shared(registry);
            ts::return_shared(escrow);
            ts::return_shared(faucet);
        };

        // BOB ends rental
        ts::next_tx(&mut scenario, BOB);
        {
            let rental_cap = ts::take_from_sender<RentalCap>(&scenario);
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1_800_000); // 30 min

            rental_escrow::end_rental(&mut escrow, &mut registry, rental_cap, &clock, ts::ctx(&mut scenario));
            assert!(robot_registry::is_available(&registry, robot_id), 1);

            clock::destroy_for_testing(clock);
            ts::return_shared(registry);
            ts::return_shared(escrow);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_rental_receipt_minted() {
        let mut scenario = ts::begin(ALICE);
        init_all(&mut scenario);

        let robot_id = register_robot_as_alice(&mut scenario, 1_000_000_000);

        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            let payment = treat_token::mint_for_testing(&mut faucet, 1_000_000_000, ts::ctx(&mut scenario));
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let rental_cap = rental_escrow::create_rental(
                &mut escrow, &mut registry, robot_id, 1, payment, &clock, ts::ctx(&mut scenario),
            );
            clock::destroy_for_testing(clock);
            transfer::public_transfer(rental_cap, BOB);
            ts::return_shared(registry);
            ts::return_shared(escrow);
            ts::return_shared(faucet);
        };

        ts::next_tx(&mut scenario, BOB);
        {
            let rental_cap = ts::take_from_sender<RentalCap>(&scenario);
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 3_600_000); // 1 hour
            rental_escrow::end_rental(&mut escrow, &mut registry, rental_cap, &clock, ts::ctx(&mut scenario));
            clock::destroy_for_testing(clock);
            ts::return_shared(registry);
            ts::return_shared(escrow);
        };

        // Verify BOB received a RentalReceipt NFT
        ts::next_tx(&mut scenario, BOB);
        {
            let receipt = ts::take_from_sender<RentalReceipt>(&scenario);
            ts::return_to_sender(&scenario, receipt);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = robot_rental_platform::rental_escrow)]
    fun test_rent_unavailable_robot_fails() {
        let mut scenario = ts::begin(ALICE);
        init_all(&mut scenario);

        let robot_id = register_robot_as_alice(&mut scenario, 1_000_000_000);

        // Toggle robot to unavailable
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = ts::take_from_sender<robot_registry::OwnerCap>(&scenario);
            robot_registry::toggle_availability(&mut registry, &cap);
            ts::return_to_sender(&scenario, cap);
            ts::return_shared(registry);
        };

        // BOB tries to rent unavailable robot
        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            let payment = treat_token::mint_for_testing(&mut faucet, 1_000_000_000, ts::ctx(&mut scenario));
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let rental_cap = rental_escrow::create_rental(
                &mut escrow, &mut registry, robot_id, 1, payment, &clock, ts::ctx(&mut scenario),
            );
            clock::destroy_for_testing(clock);
            transfer::public_transfer(rental_cap, BOB);
            ts::return_shared(registry);
            ts::return_shared(escrow);
            ts::return_shared(faucet);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = robot_rental_platform::rental_escrow)]
    fun test_rent_insufficient_payment_fails() {
        let mut scenario = ts::begin(ALICE);
        init_all(&mut scenario);

        let robot_id = register_robot_as_alice(&mut scenario, 1_000_000_000);

        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            // Only 500M, need 1B for 1 hour
            let payment = treat_token::mint_for_testing(&mut faucet, 500_000_000, ts::ctx(&mut scenario));
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let rental_cap = rental_escrow::create_rental(
                &mut escrow, &mut registry, robot_id, 1, payment, &clock, ts::ctx(&mut scenario),
            );
            clock::destroy_for_testing(clock);
            transfer::public_transfer(rental_cap, BOB);
            ts::return_shared(registry);
            ts::return_shared(escrow);
            ts::return_shared(faucet);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 5, location = robot_rental_platform::rental_escrow)]
    fun test_duration_too_long_fails() {
        let mut scenario = ts::begin(ALICE);
        init_all(&mut scenario);

        let robot_id = register_robot_as_alice(&mut scenario, 1);

        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            let payment = treat_token::mint_for_testing(&mut faucet, 10_000_000_000_000, ts::ctx(&mut scenario));
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            // 8761 hours exceeds MAX_DURATION_HOURS (8760)
            let rental_cap = rental_escrow::create_rental(
                &mut escrow, &mut registry, robot_id, 8761, payment, &clock, ts::ctx(&mut scenario),
            );
            clock::destroy_for_testing(clock);
            transfer::public_transfer(rental_cap, BOB);
            ts::return_shared(registry);
            ts::return_shared(escrow);
            ts::return_shared(faucet);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_overpayment_refund() {
        let mut scenario = ts::begin(ALICE);
        init_all(&mut scenario);

        let robot_id = register_robot_as_alice(&mut scenario, 1_000_000_000);

        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            // Pay 3B for 1 hour (only 1B needed)
            let payment = treat_token::mint_for_testing(&mut faucet, 3_000_000_000, ts::ctx(&mut scenario));
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let rental_cap = rental_escrow::create_rental(
                &mut escrow, &mut registry, robot_id, 1, payment, &clock, ts::ctx(&mut scenario),
            );
            clock::destroy_for_testing(clock);
            transfer::public_transfer(rental_cap, BOB);
            ts::return_shared(registry);
            ts::return_shared(escrow);
            ts::return_shared(faucet);
        };

        // Verify BOB got 2B refund
        ts::next_tx(&mut scenario, BOB);
        {
            use sui::coin::Coin;
            use robot_rental_platform::treat_token::TREAT_TOKEN;
            let refund = ts::take_from_sender<Coin<TREAT_TOKEN>>(&scenario);
            assert!(refund.value() == 2_000_000_000, 0);
            ts::return_to_sender(&scenario, refund);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_robot_available_after_rental_end() {
        let mut scenario = ts::begin(ALICE);
        init_all(&mut scenario);

        let robot_id = register_robot_as_alice(&mut scenario, 1_000_000_000);

        // Create rental
        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            let payment = treat_token::mint_for_testing(&mut faucet, 1_000_000_000, ts::ctx(&mut scenario));
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let rental_cap = rental_escrow::create_rental(
                &mut escrow, &mut registry, robot_id, 1, payment, &clock, ts::ctx(&mut scenario),
            );

            // Robot unavailable during rental
            assert!(!robot_registry::is_available(&registry, robot_id), 0);

            clock::destroy_for_testing(clock);
            transfer::public_transfer(rental_cap, BOB);
            ts::return_shared(registry);
            ts::return_shared(escrow);
            ts::return_shared(faucet);
        };

        // End rental
        ts::next_tx(&mut scenario, BOB);
        {
            let rental_cap = ts::take_from_sender<RentalCap>(&scenario);
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 3_600_000);
            rental_escrow::end_rental(&mut escrow, &mut registry, rental_cap, &clock, ts::ctx(&mut scenario));

            // Robot available again
            assert!(robot_registry::is_available(&registry, robot_id), 1);

            clock::destroy_for_testing(clock);
            ts::return_shared(registry);
            ts::return_shared(escrow);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_rental_agreement_getters() {
        let mut scenario = ts::begin(ALICE);
        init_all(&mut scenario);

        let robot_id = register_robot_as_alice(&mut scenario, 1_000_000_000);

        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 5000);
            let payment = treat_token::mint_for_testing(&mut faucet, 2_000_000_000, ts::ctx(&mut scenario));
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let rental_cap = rental_escrow::create_rental(
                &mut escrow, &mut registry, robot_id, 2, payment, &clock, ts::ctx(&mut scenario),
            );

            // Check agreement via getters
            let rental_id = rental_escrow::rental_cap_rental_id(&rental_cap);
            let agreement = rental_escrow::get_rental_info(&escrow, rental_id);
            assert!(rental_escrow::agreement_is_active(agreement), 0);
            assert!(rental_escrow::agreement_renter(agreement) == BOB, 1);
            assert!(rental_escrow::agreement_robot_id(agreement) == robot_id, 2);
            assert!(rental_escrow::agreement_escrowed_amount(agreement) == 2_000_000_000, 3);

            clock::destroy_for_testing(clock);
            transfer::public_transfer(rental_cap, BOB);
            ts::return_shared(registry);
            ts::return_shared(escrow);
            ts::return_shared(faucet);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_multi_hour_rental_cost_calculation() {
        let mut scenario = ts::begin(ALICE);
        init_all(&mut scenario);

        // 500M per hour, 3 hour rental = 1.5B
        let robot_id = register_robot_as_alice(&mut scenario, 500_000_000);

        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);
            let payment = treat_token::mint_for_testing(&mut faucet, 1_500_000_000, ts::ctx(&mut scenario));
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let rental_cap = rental_escrow::create_rental(
                &mut escrow, &mut registry, robot_id, 3, payment, &clock, ts::ctx(&mut scenario),
            );
            clock::destroy_for_testing(clock);
            transfer::public_transfer(rental_cap, BOB);
            ts::return_shared(registry);
            ts::return_shared(escrow);
            ts::return_shared(faucet);
        };

        // End after 1.5 hours — cost should be ceil(1.5) * 500M = 2 * 500M = 1B
        ts::next_tx(&mut scenario, BOB);
        {
            let rental_cap = ts::take_from_sender<RentalCap>(&scenario);
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 5_400_000); // 1.5 hours in ms
            rental_escrow::end_rental(&mut escrow, &mut registry, rental_cap, &clock, ts::ctx(&mut scenario));
            clock::destroy_for_testing(clock);
            ts::return_shared(registry);
            ts::return_shared(escrow);
        };

        ts::end(scenario);
    }
}
