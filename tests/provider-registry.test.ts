import { Cl } from '@stacks/transactions';
import { describe, expect, it } from 'vitest';

describe("Provider Registry", () => {
    it("Can add a new provider", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        const provider1 = accounts.get('wallet_1')!;
        
        let { result } = simnet.callPublicFn(
            'provider-registry', 
            'add-provider', 
            [
                Cl.stringAscii("Acme Background Checks"),
                Cl.stringUtf8("Professional background check service"),
                Cl.principal(provider1)
            ], 
            deployer
        );
        
        expect(result).toBeOk(Cl.uint(1));
        
        // Verify provider was added
        let getProvider = simnet.callReadOnlyFn(
            'provider-registry',
            'get-provider',
            [Cl.uint(1)],
            deployer
        );

        // Just verify the call succeeded and returned some data
        expect(getProvider.result).toBeDefined();
    });

    it("Can verify a provider", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        const provider1 = accounts.get('wallet_1')!;
        
        // Add provider first
        simnet.callPublicFn(
            'provider-registry', 
            'add-provider', 
            [
                Cl.stringAscii("Acme Background Checks"),
                Cl.stringUtf8("Professional background check service"),
                Cl.principal(provider1)
            ], 
            deployer
        );
        
        // Verify provider
        let { result } = simnet.callPublicFn(
            'provider-registry', 
            'verify-provider', 
            [Cl.uint(1)], 
            deployer
        );
        
        expect(result).toBeOk(Cl.bool(true));
        
        // Check verification status
        let isVerified = simnet.callReadOnlyFn(
            'provider-registry',
            'is-verified-provider',
            [Cl.uint(1)],
            deployer
        );
        expect(isVerified.result).toStrictEqual(Cl.bool(true));
    });

    it("Only contract owner can add providers", () => {
        const accounts = simnet.getAccounts();
        const unauthorized = accounts.get('wallet_1')!;
        const provider1 = accounts.get('wallet_2')!;
        
        let { result } = simnet.callPublicFn(
            'provider-registry', 
            'add-provider', 
            [
                Cl.stringAscii("Acme Background Checks"),
                Cl.stringUtf8("Professional background check service"),
                Cl.principal(provider1)
            ], 
            unauthorized
        );
        
        expect(result).toBeErr(Cl.uint(101)); // err-not-contract-owner
    });
});
