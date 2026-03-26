module robot_rental_platform::robot_registry_tests {
    use sui::test_scenario::{Self as ts};
    use std::string;
    use robot_rental_platform::robot_registry::{Self, RobotRegistry};

    const ALICE: address = @0xA11CE;

    #[test]
    fun test_register_robot() {
        let mut scenario = ts::begin(ALICE);
        { robot_registry::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = robot_registry::register_robot(
                &mut registry,
                string::utf8(b"Robot Alpha"),
                vector[1u8, 2u8, 3u8],
                1_000_000_000,
                ts::ctx(&mut scenario),
            );
            assert!(robot_registry::registry_count(&registry) == 1, 0);
            let robot_id = robot_registry::cap_robot_id(&cap);
            let info = robot_registry::get_robot_info(&registry, robot_id);
            assert!(robot_registry::info_is_available(info), 1);
            assert!(robot_registry::info_hourly_rate(info) == 1_000_000_000, 2);
            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_update_rate() {
        let mut scenario = ts::begin(ALICE);
        { robot_registry::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = robot_registry::register_robot(
                &mut registry,
                string::utf8(b"Robot Beta"),
                vector[1u8],
                500_000_000,
                ts::ctx(&mut scenario),
            );
            robot_registry::update_rate(&mut registry, &cap, 999_000_000);
            let robot_id = robot_registry::cap_robot_id(&cap);
            let info = robot_registry::get_robot_info(&registry, robot_id);
            assert!(robot_registry::info_hourly_rate(info) == 999_000_000, 0);
            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_toggle_availability() {
        let mut scenario = ts::begin(ALICE);
        { robot_registry::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = robot_registry::register_robot(
                &mut registry,
                string::utf8(b"Robot Gamma"),
                vector[2u8],
                100_000_000,
                ts::ctx(&mut scenario),
            );
            let robot_id = robot_registry::cap_robot_id(&cap);

            assert!(robot_registry::is_available(&registry, robot_id), 0);
            robot_registry::toggle_availability(&mut registry, &cap);
            assert!(!robot_registry::is_available(&registry, robot_id), 1);
            robot_registry::toggle_availability(&mut registry, &cap);
            assert!(robot_registry::is_available(&registry, robot_id), 2);

            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    // === NEW TESTS ===

    #[test]
    fun test_register_multiple_robots() {
        let mut scenario = ts::begin(ALICE);
        { robot_registry::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);

            let cap1 = robot_registry::register_robot(
                &mut registry, string::utf8(b"Robot 1"), vector[1u8], 100, ts::ctx(&mut scenario),
            );
            let cap2 = robot_registry::register_robot(
                &mut registry, string::utf8(b"Robot 2"), vector[2u8], 200, ts::ctx(&mut scenario),
            );
            let cap3 = robot_registry::register_robot(
                &mut registry, string::utf8(b"Robot 3"), vector[3u8], 300, ts::ctx(&mut scenario),
            );

            assert!(robot_registry::registry_count(&registry) == 3, 0);

            transfer::public_transfer(cap1, ALICE);
            transfer::public_transfer(cap2, ALICE);
            transfer::public_transfer(cap3, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = robot_rental_platform::robot_registry)]
    fun test_register_robot_zero_rate_fails() {
        let mut scenario = ts::begin(ALICE);
        { robot_registry::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = robot_registry::register_robot(
                &mut registry, string::utf8(b"Zero Rate"), vector[1u8], 0, ts::ctx(&mut scenario),
            );
            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = robot_rental_platform::robot_registry)]
    fun test_update_rate_zero_fails() {
        let mut scenario = ts::begin(ALICE);
        { robot_registry::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = robot_registry::register_robot(
                &mut registry, string::utf8(b"Robot"), vector[1u8], 100, ts::ctx(&mut scenario),
            );
            robot_registry::update_rate(&mut registry, &cap, 0);
            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_robot_info_getters() {
        let mut scenario = ts::begin(ALICE);
        { robot_registry::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = robot_registry::register_robot(
                &mut registry,
                string::utf8(b"InfoBot"),
                vector[10u8, 20u8],
                555_000_000,
                ts::ctx(&mut scenario),
            );
            let robot_id = robot_registry::cap_robot_id(&cap);
            let info = robot_registry::get_robot_info(&registry, robot_id);

            assert!(robot_registry::info_name(info) == string::utf8(b"InfoBot"), 0);
            assert!(robot_registry::info_capabilities(info) == vector[10u8, 20u8], 1);
            assert!(robot_registry::info_hourly_rate(info) == 555_000_000, 2);
            assert!(robot_registry::info_owner(info) == ALICE, 3);
            assert!(robot_registry::info_is_available(info) == true, 4);
            assert!(robot_registry::info_total_rentals(info) == 0, 5);
            assert!(robot_registry::info_total_earned(info) == 0, 6);

            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_robot_exists() {
        let mut scenario = ts::begin(ALICE);
        { robot_registry::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = robot_registry::register_robot(
                &mut registry, string::utf8(b"Exists"), vector[1u8], 100, ts::ctx(&mut scenario),
            );
            let robot_id = robot_registry::cap_robot_id(&cap);
            assert!(robot_registry::robot_exists(&registry, robot_id), 0);

            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_get_available_robots_returns_empty() {
        let mut scenario = ts::begin(ALICE);
        { robot_registry::init_for_testing(ts::ctx(&mut scenario)); };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<RobotRegistry>(&scenario);
            let cap = robot_registry::register_robot(
                &mut registry, string::utf8(b"Bot"), vector[1u8], 100, ts::ctx(&mut scenario),
            );
            // Always returns empty (design limitation)
            let available = robot_registry::get_available_robots(&registry);
            assert!(available.length() == 0, 0);
            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }
}
