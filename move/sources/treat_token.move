module robot_rental_platform::treat_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::clock::Clock;
    use sui::table::{Self, Table};

    // ===== Errors =====
    const EFaucetRateLimitExceeded: u64 = 0;

    // ===== Constants =====
    const CLAIMS_PER_EPOCH: u64 = 5;
    const TREAT_PER_CLAIM: u64 = 100_000_000_000; // 100 TREAT with 9 decimals

    // ===== OTW =====
    public struct TREAT_TOKEN has drop {}

    // ===== Shared Objects =====
    public struct FaucetState has key {
        id: UID,
        treasury_cap: TreasuryCap<TREAT_TOKEN>,
        claims: Table<address, EpochClaims>,
    }

    public struct EpochClaims has store {
        epoch: u64,
        count: u64,
    }

    // ===== Events =====
    public struct FaucetClaimed has copy, drop {
        recipient: address,
        amount: u64,
        epoch: u64,
    }

    public struct TreatMinted has copy, drop {
        recipient: address,
        amount: u64,
    }

    // ===== Init =====
    fun init(otw: TREAT_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            otw,
            9,
            b"TREAT",
            b"TREAT",
            b"Robot rental platform token",
            option::none(),
            ctx,
        );

        transfer::public_freeze_object(metadata);

        let faucet = FaucetState {
            id: object::new(ctx),
            treasury_cap,
            claims: table::new(ctx),
        };

        transfer::share_object(faucet);
    }

    // ===== Public Functions =====
    public fun claim_faucet(
        faucet: &mut FaucetState,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let current_epoch = tx_context::epoch(ctx);
        let _ = clock;

        if (table::contains(&faucet.claims, sender)) {
            let entry = table::borrow_mut(&mut faucet.claims, sender);
            if (entry.epoch == current_epoch) {
                assert!(entry.count < CLAIMS_PER_EPOCH, EFaucetRateLimitExceeded);
                entry.count = entry.count + 1;
            } else {
                entry.epoch = current_epoch;
                entry.count = 1;
            }
        } else {
            table::add(&mut faucet.claims, sender, EpochClaims {
                epoch: current_epoch,
                count: 1,
            });
        };

        let minted = coin::mint(&mut faucet.treasury_cap, TREAT_PER_CLAIM, ctx);

        sui::event::emit(FaucetClaimed {
            recipient: sender,
            amount: TREAT_PER_CLAIM,
            epoch: current_epoch,
        });

        sui::event::emit(TreatMinted {
            recipient: sender,
            amount: TREAT_PER_CLAIM,
        });

        transfer::public_transfer(minted, sender);
    }

    public fun mint_for_testing(
        faucet: &mut FaucetState,
        amount: u64,
        ctx: &mut TxContext,
    ): Coin<TREAT_TOKEN> {
        coin::mint(&mut faucet.treasury_cap, amount, ctx)
    }

    // ===== Accessors =====
    public fun treat_per_claim(): u64 { TREAT_PER_CLAIM }
    public fun claims_per_epoch(): u64 { CLAIMS_PER_EPOCH }
    public fun e_faucet_rate_limit(): u64 { EFaucetRateLimitExceeded }

    // ===== Test helpers =====
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TREAT_TOKEN {}, ctx);
    }
}
