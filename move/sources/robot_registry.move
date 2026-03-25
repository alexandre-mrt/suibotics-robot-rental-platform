module robot_rental_platform::robot_registry {
    use sui::table::{Self, Table};
    use std::string::String;

    // ===== Errors =====
    const ENotOwner: u64 = 0;
    const ERobotNotFound: u64 = 1;
    const EInvalidRate: u64 = 3;

    // ===== Shared Objects =====
    public struct RobotRegistry has key {
        id: UID,
        robots: Table<ID, RobotInfo>,
        robot_count: u64,
    }

    public struct RobotInfo has store {
        name: String,
        capabilities: vector<u8>,
        hourly_rate: u64,
        owner: address,
        is_available: bool,
        total_rentals: u64,
        total_earned: u64,
    }

    // ===== Capabilities =====
    public struct OwnerCap has key, store {
        id: UID,
        robot_id: ID,
        owner: address,
    }

    // ===== Events =====
    public struct RobotRegistered has copy, drop {
        robot_id: ID,
        owner: address,
        name: String,
        hourly_rate: u64,
    }

    public struct RobotUpdated has copy, drop {
        robot_id: ID,
        new_rate: u64,
    }

    public struct AvailabilityToggled has copy, drop {
        robot_id: ID,
        is_available: bool,
    }

    // ===== Init =====
    fun init(ctx: &mut TxContext) {
        let registry = RobotRegistry {
            id: object::new(ctx),
            robots: table::new(ctx),
            robot_count: 0,
        };
        transfer::share_object(registry);
    }

    // ===== Public Functions =====
    public fun register_robot(
        registry: &mut RobotRegistry,
        name: String,
        capabilities: vector<u8>,
        hourly_rate: u64,
        ctx: &mut TxContext,
    ): OwnerCap {
        assert!(hourly_rate > 0, EInvalidRate);
        let owner = ctx.sender();
        let cap_uid = object::new(ctx);
        let robot_id = object::uid_to_inner(&cap_uid);

        let info = RobotInfo {
            name,
            capabilities,
            hourly_rate,
            owner,
            is_available: true,
            total_rentals: 0,
            total_earned: 0,
        };

        registry.robots.add(robot_id, info);
        registry.robot_count = registry.robot_count + 1;

        let registered_info = registry.robots.borrow(robot_id);

        sui::event::emit(RobotRegistered {
            robot_id,
            owner,
            name: registered_info.name,
            hourly_rate: registered_info.hourly_rate,
        });

        OwnerCap { id: cap_uid, robot_id, owner }
    }

    public fun update_rate(
        registry: &mut RobotRegistry,
        cap: &OwnerCap,
        new_rate: u64,
    ) {
        assert!(new_rate > 0, EInvalidRate);
        let robot_id = cap.robot_id;
        assert!(registry.robots.contains(robot_id), ERobotNotFound);

        let info = registry.robots.borrow_mut(robot_id);
        assert!(info.owner == cap.owner, ENotOwner);
        info.hourly_rate = new_rate;

        sui::event::emit(RobotUpdated { robot_id, new_rate });
    }

    public fun toggle_availability(
        registry: &mut RobotRegistry,
        cap: &OwnerCap,
    ) {
        let robot_id = cap.robot_id;
        assert!(registry.robots.contains(robot_id), ERobotNotFound);

        let info = registry.robots.borrow_mut(robot_id);
        assert!(info.owner == cap.owner, ENotOwner);
        info.is_available = !info.is_available;

        sui::event::emit(AvailabilityToggled {
            robot_id,
            is_available: info.is_available,
        });
    }

    public fun get_robot_info(registry: &RobotRegistry, robot_id: ID): &RobotInfo {
        assert!(registry.robots.contains(robot_id), ERobotNotFound);
        registry.robots.borrow(robot_id)
    }

    /// Returns empty vector — full iteration requires off-chain indexing in Sui.
    /// Use events or indexer to build available robot list.
    public fun get_available_robots(_registry: &RobotRegistry): vector<ID> {
        vector::empty<ID>()
    }

    // ===== Internal (package-visible, used by escrow) =====
    public(package) fun set_availability(
        registry: &mut RobotRegistry,
        robot_id: ID,
        available: bool,
    ) {
        assert!(registry.robots.contains(robot_id), ERobotNotFound);
        let info = registry.robots.borrow_mut(robot_id);
        info.is_available = available;
    }

    public(package) fun record_rental_complete(
        registry: &mut RobotRegistry,
        robot_id: ID,
        earned: u64,
    ) {
        assert!(registry.robots.contains(robot_id), ERobotNotFound);
        let info = registry.robots.borrow_mut(robot_id);
        info.total_rentals = info.total_rentals + 1;
        info.total_earned = info.total_earned + earned;
    }

    public(package) fun robot_owner(registry: &RobotRegistry, robot_id: ID): address {
        assert!(registry.robots.contains(robot_id), ERobotNotFound);
        registry.robots.borrow(robot_id).owner
    }

    // ===== Accessors for RobotInfo =====
    public fun info_name(info: &RobotInfo): String { info.name }
    public fun info_capabilities(info: &RobotInfo): vector<u8> { info.capabilities }
    public fun info_hourly_rate(info: &RobotInfo): u64 { info.hourly_rate }
    public fun info_owner(info: &RobotInfo): address { info.owner }
    public fun info_is_available(info: &RobotInfo): bool { info.is_available }
    public fun info_total_rentals(info: &RobotInfo): u64 { info.total_rentals }
    public fun info_total_earned(info: &RobotInfo): u64 { info.total_earned }

    public fun cap_robot_id(cap: &OwnerCap): ID { cap.robot_id }
    public fun registry_count(registry: &RobotRegistry): u64 { registry.robot_count }

    public fun robot_exists(registry: &RobotRegistry, robot_id: ID): bool {
        registry.robots.contains(robot_id)
    }

    public fun is_available(registry: &RobotRegistry, robot_id: ID): bool {
        assert!(registry.robots.contains(robot_id), ERobotNotFound);
        registry.robots.borrow(robot_id).is_available
    }

    // ===== Test helpers =====
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
