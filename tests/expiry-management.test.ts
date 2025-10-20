import { Cl } from '@stacks/transactions';
import { describe, expect, it } from 'vitest';

describe("Expiry Management", () => {
    it("Can register an attestation for expiry tracking", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        const itemType = "attestation";
        const itemId = 1;
        const expiryHeight = 1000;
        
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(expiryHeight)
            ],
            deployer
        );
        
        expect(result).toBeOk(Cl.bool(true));
        
        // Verify the item was registered
        let getExpiry = simnet.callReadOnlyFn(
            'expiry-management',
            'get-item-expiry',
            [Cl.stringAscii(itemType), Cl.uint(itemId)],
            deployer
        );
        
        expect(getExpiry.result).toBeDefined();
    });

    it("Can register a grant for expiry tracking", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        const itemType = "grant";
        const itemId = 1;
        const expiryHeight = 500;
        
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(expiryHeight)
            ],
            deployer
        );
        
        expect(result).toBeOk(Cl.bool(true));
    });

    it("Cannot register expiry with invalid item type", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii("invalid-type"),
                Cl.uint(1),
                Cl.uint(1000)
            ],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(202)); // err-invalid-item-type
    });

    it("Cannot register expiry with past expiry time", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        // Try to register with expiry in the past (block 0)
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii("attestation"),
                Cl.uint(1),
                Cl.uint(0)
            ],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(200)); // err-invalid-expiry-time
    });

    it("Cannot register expiry with zero item ID", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii("attestation"),
                Cl.uint(0), // Invalid ID
                Cl.uint(1000)
            ],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(201)); // err-invalid-item-id
    });

    it("Can check if item is expired", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        // Register an item that will expire soon
        const itemType = "attestation";
        const itemId = 2;
        const expiryHeight = 10; // Will expire at block 10
        
        simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(expiryHeight)
            ],
            deployer
        );
        
        // Check if item is valid (should be valid initially)
        let isValid = simnet.callReadOnlyFn(
            'expiry-management',
            'is-item-valid',
            [Cl.stringAscii(itemType), Cl.uint(itemId)],
            deployer
        );
        
        expect(isValid.result).toStrictEqual(Cl.bool(true));
        
        // Mine blocks to pass expiry time
        simnet.mineEmptyBlocks(15);
        
        // Check if item is expired now
        let isExpired = simnet.callReadOnlyFn(
            'expiry-management',
            'is-item-expired',
            [Cl.stringAscii(itemType), Cl.uint(itemId)],
            deployer
        );
        
        expect(isExpired.result).toStrictEqual(Cl.bool(true));
    });

    it("Can mark item as expired after expiry time", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        const itemType = "grant";
        const itemId = 3;
        const expiryHeight = 10;
        
        // Register item
        simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(expiryHeight)
            ],
            deployer
        );
        
        // Mine blocks to pass expiry
        simnet.mineEmptyBlocks(15);
        
        // Anyone can mark as expired once time has passed
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'mark-as-expired',
            [Cl.stringAscii(itemType), Cl.uint(itemId)],
            user1
        );
        
        expect(result).toBeOk(Cl.bool(true));
    });

    it("Cannot mark item as expired before expiry time", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        const itemType = "attestation";
        const itemId = 4;
        const expiryHeight = 1000;
        
        // Register item
        simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(expiryHeight)
            ],
            deployer
        );
        
        // Try to mark as expired before time
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'mark-as-expired',
            [Cl.stringAscii(itemType), Cl.uint(itemId)],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(301)); // err-not-expired
    });

    it("Cannot mark already expired item again", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        const itemType = "grant";
        const itemId = 5;
        const expiryHeight = 10;
        
        // Register and expire item
        simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(expiryHeight)
            ],
            deployer
        );
        
        simnet.mineEmptyBlocks(15);
        
        // Mark as expired first time
        simnet.callPublicFn(
            'expiry-management',
            'mark-as-expired',
            [Cl.stringAscii(itemType), Cl.uint(itemId)],
            deployer
        );
        
        // Try to mark again
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'mark-as-expired',
            [Cl.stringAscii(itemType), Cl.uint(itemId)],
            deployer
        );
        
        expect(result).toBeErr(Cl.uint(300)); // err-already-expired
    });

    it("Can get time until expiry", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        const itemType = "attestation";
        const itemId = 6;
        const expiryHeight = 100;
        
        simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(expiryHeight)
            ],
            deployer
        );
        
        let timeUntilExpiry = simnet.callReadOnlyFn(
            'expiry-management',
            'get-time-until-expiry',
            [Cl.stringAscii(itemType), Cl.uint(itemId)],
            deployer
        );
        
        expect(timeUntilExpiry.result).toBeDefined();
    });

    it("Can check if item will expire within timeframe", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        
        const itemType = "grant";
        const itemId = 7;
        const expiryHeight = 50;
        
        simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(expiryHeight)
            ],
            deployer
        );
        
        // Check if will expire within 100 blocks (should be true)
        let willExpire = simnet.callReadOnlyFn(
            'expiry-management',
            'will-expire-within',
            [Cl.stringAscii(itemType), Cl.uint(itemId), Cl.uint(100)],
            deployer
        );
        
        expect(willExpire.result).toStrictEqual(Cl.bool(true));
    });

    it("Contract owner can update expiry time", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;

        const itemType = "attestation";
        const itemId = 8;
        const initialExpiry = 100;
        const newExpiry = 200;

        // Register item
        simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(initialExpiry)
            ],
            deployer
        );

        // Update expiry as contract owner
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'update-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(newExpiry)
            ],
            deployer
        );

        expect(result).toBeOk(Cl.bool(true));
    });

    it("Non-owner cannot update expiry time", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;

        const itemType = "grant";
        const itemId = 9;
        const initialExpiry = 100;
        const newExpiry = 200;

        // Register item as deployer
        simnet.callPublicFn(
            'expiry-management',
            'register-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(initialExpiry)
            ],
            deployer
        );

        // Try to update as non-owner
        let { result } = simnet.callPublicFn(
            'expiry-management',
            'update-expiry',
            [
                Cl.stringAscii(itemType),
                Cl.uint(itemId),
                Cl.uint(newExpiry)
            ],
            user1
        );

        expect(result).toBeErr(Cl.uint(101)); // err-not-contract-owner
    });

    it("Can batch check attestations validity", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;

        // Register multiple attestations
        for (let i = 10; i <= 12; i++) {
            simnet.callPublicFn(
                'expiry-management',
                'register-expiry',
                [
                    Cl.stringAscii("attestation"),
                    Cl.uint(i),
                    Cl.uint(1000)
                ],
                deployer
            );
        }

        // Batch check validity
        let batchCheck = simnet.callReadOnlyFn(
            'expiry-management',
            'batch-check-attestations-valid',
            [Cl.list([Cl.uint(10), Cl.uint(11), Cl.uint(12)])],
            deployer
        );

        expect(batchCheck.result).toBeDefined();
    });

    it("Can batch check grants validity", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;

        // Register multiple grants
        for (let i = 20; i <= 22; i++) {
            simnet.callPublicFn(
                'expiry-management',
                'register-expiry',
                [
                    Cl.stringAscii("grant"),
                    Cl.uint(i),
                    Cl.uint(500)
                ],
                deployer
            );
        }

        // Batch check validity
        let batchCheck = simnet.callReadOnlyFn(
            'expiry-management',
            'batch-check-grants-valid',
            [Cl.list([Cl.uint(20), Cl.uint(21), Cl.uint(22)])],
            deployer
        );

        expect(batchCheck.result).toBeDefined();
    });

    it("Can calculate expiry from current time", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;

        const durationBlocks = 100;

        let calculatedExpiry = simnet.callReadOnlyFn(
            'expiry-management',
            'calculate-expiry-from-now',
            [Cl.uint(durationBlocks)],
            deployer
        );

        expect(calculatedExpiry.result).toBeDefined();
    });

    it("Can get contract info", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;

        let contractInfo = simnet.callReadOnlyFn(
            'expiry-management',
            'get-contract-info',
            [],
            deployer
        );

        expect(contractInfo.result).toBeDefined();
    });

    it("Can get total tracked items", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;

        let totalItems = simnet.callReadOnlyFn(
            'expiry-management',
            'get-total-tracked-items',
            [],
            deployer
        );

        expect(totalItems.result).toBeDefined();
    });

    it("Returns none for non-existent item expiry", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;

        let getExpiry = simnet.callReadOnlyFn(
            'expiry-management',
            'get-item-expiry',
            [Cl.stringAscii("attestation"), Cl.uint(9999)],
            deployer
        );

        expect(getExpiry.result).toStrictEqual(Cl.none());
    });

    it("Returns false for expired check on non-existent item", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;

        let isExpired = simnet.callReadOnlyFn(
            'expiry-management',
            'is-item-expired',
            [Cl.stringAscii("grant"), Cl.uint(9999)],
            deployer
        );

        expect(isExpired.result).toStrictEqual(Cl.bool(false));
    });
});
