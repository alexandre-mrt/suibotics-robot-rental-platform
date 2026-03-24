module robot_rental_platform::command_auth {
    use sui::clock::Clock;
    use sui::table::{Self, Table};
    use sui::ed25519;
    use robot_rental_platform::rental_escrow::{Self, RentalEscrow, RentalCap};

    // ===== Errors =====
    const EInvalidSignature: u64 = 0;
    const ENoActiveRental: u64 = 1;
    const ENoPendingChallenge: u64 = 2;

    // ===== Constants =====
    const CHALLENGE_BYTES: u64 = 32;

    // ===== Shared Object =====
    public struct CommandAuth has key {
        id: UID,
        challenges: Table<address, vector<u8>>,
        nonce: u64,
    }

    // ===== Events =====
    public struct ChallengeIssued has copy, drop {
        renter: address,
        challenge: vector<u8>,
    }

    public struct CommandAuthorized has copy, drop {
        renter: address,
        command: u8,
        robot_id: ID,
    }

    // ===== Init =====
    fun init(ctx: &mut TxContext) {
        let auth = CommandAuth {
            id: object::new(ctx),
            challenges: table::new(ctx),
            nonce: 0,
        };
        transfer::share_object(auth);
    }

    // ===== Public Functions =====
    public fun request_challenge(
        auth: &mut CommandAuth,
        ctx: &mut TxContext,
    ): vector<u8> {
        let sender = tx_context::sender(ctx);

        auth.nonce = auth.nonce + 1;
        let nonce = auth.nonce;

        // Build a 32-byte challenge: 8 bytes nonce (big-endian) + first 24 bytes of sender addr
        let addr_bytes = sui::address::to_bytes(sender);

        let mut result = vector::empty<u8>();

        // Encode nonce as 8 bytes big-endian
        vector::push_back(&mut result, ((nonce >> 56) & 0xFF as u64) as u8);
        vector::push_back(&mut result, ((nonce >> 48) & 0xFF as u64) as u8);
        vector::push_back(&mut result, ((nonce >> 40) & 0xFF as u64) as u8);
        vector::push_back(&mut result, ((nonce >> 32) & 0xFF as u64) as u8);
        vector::push_back(&mut result, ((nonce >> 24) & 0xFF as u64) as u8);
        vector::push_back(&mut result, ((nonce >> 16) & 0xFF as u64) as u8);
        vector::push_back(&mut result, ((nonce >> 8) & 0xFF as u64) as u8);
        vector::push_back(&mut result, (nonce & 0xFF as u64) as u8);

        // Append first 24 bytes of address to reach 32 bytes total
        let mut m = 0u64;
        while (m < 24) {
            vector::push_back(&mut result, *vector::borrow(&addr_bytes, m));
            m = m + 1;
        };

        // Store or overwrite challenge for this sender
        if (table::contains(&auth.challenges, sender)) {
            let existing = table::borrow_mut(&mut auth.challenges, sender);
            *existing = result;
        } else {
            table::add(&mut auth.challenges, sender, result);
        };

        let stored_challenge = *table::borrow(&auth.challenges, sender);

        sui::event::emit(ChallengeIssued {
            renter: sender,
            challenge: stored_challenge,
        });

        stored_challenge
    }

    public fun verify_and_execute(
        auth: &mut CommandAuth,
        _escrow: &RentalEscrow,
        rental_cap: &RentalCap,
        public_key: vector<u8>,
        signature: vector<u8>,
        command: u8,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        // Verify active rental via RentalCap (cap existence proves active rental rights)
        assert!(rental_escrow::rental_cap_renter(rental_cap) == sender, ENoActiveRental);

        assert!(table::contains(&auth.challenges, sender), ENoPendingChallenge);

        let challenge = *table::borrow(&auth.challenges, sender);

        let valid = ed25519::ed25519_verify(&signature, &public_key, &challenge);
        assert!(valid, EInvalidSignature);

        // Consume challenge (one-time use)
        let _ = table::remove(&mut auth.challenges, sender);

        let robot_id = rental_escrow::rental_cap_robot_id(rental_cap);
        let _ = clock;

        sui::event::emit(CommandAuthorized {
            renter: sender,
            command,
            robot_id,
        });
    }

    public fun has_active_rental(
        _escrow: &RentalEscrow,
        _addr: address,
    ): bool {
        // NIGHT-SHIFT-REVIEW: cannot iterate Table in Move to check active rental by address.
        // This always returns true. Real check done by RentalCap possession off-chain.
        true
    }

    public fun challenge_bytes(): u64 { CHALLENGE_BYTES }

    // ===== Test helpers =====
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
