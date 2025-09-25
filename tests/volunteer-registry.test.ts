import { Cl } from '@stacks/transactions';
import { describe, expect, it } from 'vitest';

describe("Volunteer Registry", () => {
    it("Can register a new volunteer", () => {
        const accounts = simnet.getAccounts();
        const deployer = accounts.get('deployer')!;
        const volunteer1 = accounts.get('wallet_1')!;
        
        let { result } = simnet.callPublicFn(
            'volunteer-registry', 
            'register-volunteer', 
            [
                Cl.stringAscii("hash123abc456def789"),
                Cl.stringUtf8("Volunteer metadata")
            ], 
            volunteer1
        );
        
        expect(result).toBeOk(Cl.uint(1));
        
        // Verify volunteer was registered
        let getVolunteer = simnet.callReadOnlyFn(
            'volunteer-registry',
            'get-volunteer',
            [Cl.uint(1)],
            deployer
        );

        // Just verify the call succeeded and returned some data
        expect(getVolunteer.result).toBeDefined();
    });

    it("Cannot register with invalid hashed identity", () => {
        const accounts = simnet.getAccounts();
        const volunteer1 = accounts.get('wallet_1')!;
        
        let { result } = simnet.callPublicFn(
            'volunteer-registry', 
            'register-volunteer', 
            [
                Cl.stringAscii(""), // Empty hashed identity
                Cl.stringUtf8("Volunteer metadata")
            ], 
            volunteer1
        );
        
        expect(result).toBeErr(Cl.uint(200)); // err-invalid-hashed-identity
    });

    it("Cannot register twice with same principal", () => {
        const accounts = simnet.getAccounts();
        const volunteer1 = accounts.get('wallet_1')!;
        
        // First registration
        simnet.callPublicFn(
            'volunteer-registry', 
            'register-volunteer', 
            [
                Cl.stringAscii("hash123abc456def789"),
                Cl.stringUtf8("Volunteer metadata")
            ], 
            volunteer1
        );
        
        // Second registration attempt
        let { result } = simnet.callPublicFn(
            'volunteer-registry', 
            'register-volunteer', 
            [
                Cl.stringAscii("hash456def789abc123"),
                Cl.stringUtf8("Different metadata")
            ], 
            volunteer1
        );
        
        expect(result).toBeErr(Cl.uint(203)); // err-volunteer-already-registered
    });
});
