module robot_rental_platform::rental_escrow_tests {
    use sui::test_scenario::{Self as ts};
    use sui::clock;
    use std::string;
    use robot_rental_platform::treat_token::{Self, FaucetState, TREAT_TOKEN};
    use robot_rental_platform::robot_registry::{Self, RobotRegistry};
    use robot_rental_platform::rental_escrow::{Self, RentalEscrow, RentalCap};

    const ALICE: address = @0xA11CE; // robot owner
    const BOB: address = @0xB0B;   // renter

    #[test]
    fun test_create_and_end_rental() {
        let mut scenario = ts::begin(ALICE);
        {
            let ctx = ts::ctx(&mut scenario);
            treat_token::init_for_testing(ctx);
            robot_registry::init_for_testing(ctx);
            rental_escrow::init_for_testing(ctx);
        };

        // Register robot as ALICE
        let robot_id;
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = robot_registry::register_robot(
                &mut registry,
                string::utf8(b"Robot Delta"),
                vector[1u8],
                1_000_000_000, // 1 TREAT/hr
                ts::ctx(&mut scenario),
            );
            robot_id = robot_registry::cap_robot_id(&cap);
            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        // BOB creates rental (1 hour)
        ts::next_tx(&mut scenario, BOB);
        {
            let mut faucet = ts::take_shared<FaucetState>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 0);

            // Mint payment for BOB
            let payment = treat_token::mint_for_testing(
                &mut faucet,
                1_000_000_000, // exactly 1 TREAT
                ts::ctx(&mut scenario),
            );

            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let mut escrow = ts::take_shared<RentalEscrow>(&scenario);

            let rental_cap = rental_escrow::create_rental(
                &mut escrow,
                &mut registry,
                robot_id,
                1, // 1 hour
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Robot should now be unavailable
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
            clock::set_for_testing(&mut clock, 1_800_000); // 30 minutes elapsed

            rental_escrow::end_rental(
                &mut escrow,
                &mut registry,
                rental_cap,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Robot should be available again
            assert!(robot_registry::is_available(&registry, robot_id), 1);

            clock::destroy_for_testing(clock);
            ts::return_shared(registry);
            ts::return_shared(escrow);
        };

        ts::end(scenario);
    }
}
