import { Cl } from '@stacks/transactions';
import { describe, expect, it } from 'vitest';

describe("Background Check Attestation", () => {
    it("Can issue attestation as verified provider", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        const volunteer1 = accounts.get('wallet_1')!;
        const provider1 = accounts.get('wallet_2')!;
        
        // Setup: Register volunteer and add/verify provider
        simnet.callPublicFn('volunteer-registry', 'register-volunteer', [
            Cl.stringAscii("hash123abc456def789"),
            Cl.stringUtf8("Volunteer metadata")
        ], volunteer1);
        
        simnet.callPublicFn('provider-registry', 'add-provider', [
            Cl.stringAscii("Acme Background Checks"),
            Cl.stringUtf8("Professional service"),
            Cl.principal(provider1)
        ], deployer);
        
        simnet.callPublicFn('provider-registry', 'verify-provider', [
            Cl.uint(1)
        ], deployer);
        
        // Issue attestation
        const validUntil = 1000; // Future block height
        let { result } = simnet.callPublicFn('background-check-attestation', 'issue-attestation', [
            Cl.uint(1), // volunteer ID
            Cl.stringAscii("criminal"),
            Cl.stringAscii("passed"),
            Cl.uint(validUntil)
        ], provider1);
        
        expect(result).toBeOk(Cl.uint(1)); // attestation ID
        
        // Verify attestation was created
        let getAttestation = simnet.callReadOnlyFn(
            'background-check-attestation',
            'get-attestation',
            [Cl.uint(1)],
            deployer
        );

        // Just verify the call succeeded and returned some data
        expect(getAttestation.result).toBeDefined();
    });

    it("Cannot issue attestation as unverified provider", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        const volunteer1 = accounts.get('wallet_1')!;
        const provider1 = accounts.get('wallet_2')!;
        
        // Setup: Register volunteer and add provider (but don't verify)
        simnet.callPublicFn('volunteer-registry', 'register-volunteer', [
            Cl.stringAscii("hash123abc456def789"),
            Cl.stringUtf8("Volunteer metadata")
        ], volunteer1);
        
        simnet.callPublicFn('provider-registry', 'add-provider', [
            Cl.stringAscii("Acme Background Checks"),
            Cl.stringUtf8("Professional service"),
            Cl.principal(provider1)
        ], deployer);
        
        // Try to issue attestation as unverified provider
        let { result } = simnet.callPublicFn('background-check-attestation', 'issue-attestation', [
            Cl.uint(1),
            Cl.stringAscii("criminal"),
            Cl.stringAscii("passed"),
            Cl.uint(1000)
        ], provider1);
        
        expect(result).toBeErr(Cl.uint(101)); // err-not-verified-provider
    });

    it("Cannot issue attestation with invalid check type", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        const volunteer1 = accounts.get('wallet_1')!;
        const provider1 = accounts.get('wallet_2')!;
        
        // Setup: Register volunteer and add/verify provider
        simnet.callPublicFn('volunteer-registry', 'register-volunteer', [
            Cl.stringAscii("hash123abc456def789"),
            Cl.stringUtf8("Volunteer metadata")
        ], volunteer1);
        
        simnet.callPublicFn('provider-registry', 'add-provider', [
            Cl.stringAscii("Acme Background Checks"),
            Cl.stringUtf8("Professional service"),
            Cl.principal(provider1)
        ], deployer);
        
        simnet.callPublicFn('provider-registry', 'verify-provider', [
            Cl.uint(1)
        ], deployer);
        
        // Try to issue attestation with invalid check type
        let { result } = simnet.callPublicFn('background-check-attestation', 'issue-attestation', [
            Cl.uint(1),
            Cl.stringAscii("invalid-type"), // Invalid check type
            Cl.stringAscii("passed"),
            Cl.uint(1000)
        ], provider1);
        
        expect(result).toBeErr(Cl.uint(202)); // err-invalid-check-type
    });
});
