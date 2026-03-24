module robot_rental_platform::robot_registry_tests {
    use sui::test_scenario::{Self as ts};
    use std::string;
    use robot_rental_platform::robot_registry::{Self, RobotRegistry, OwnerCap};

    const ALICE: address = @0xA11CE;
    const BOB: address = @0xB0B;

    #[test]
    fun test_register_robot() {
        let mut scenario = ts::begin(ALICE);
        {
            let ctx = ts::ctx(&mut scenario);
            robot_registry::init_for_testing(ctx);
        };

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
        {
            let ctx = ts::ctx(&mut scenario);
            robot_registry::init_for_testing(ctx);
        };

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
        {
            let ctx = ts::ctx(&mut scenario);
            robot_registry::init_for_testing(ctx);
        };

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

            // Initially available
            assert!(robot_registry::is_available(&registry, robot_id), 0);

            // Toggle off
            robot_registry::toggle_availability(&mut registry, &cap);
            assert!(!robot_registry::is_available(&registry, robot_id), 1);

            // Toggle back on
            robot_registry::toggle_availability(&mut registry, &cap);
            assert!(robot_registry::is_available(&registry, robot_id), 2);

            transfer::public_transfer(cap, ALICE);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }
}
