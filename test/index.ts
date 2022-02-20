import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFT Distributor", function () {
    let NFTDistributor: any;

    let owner: any;
    let user1: any;

    const baseUri = "ipfs://";

    const winner1 = "0x0000000000000000000000000000000000000001";
    const winner2 = "0x0000000000000000000000000000000000000002";

    const loser1 = "0x0000000000000000000000000000000000000003";

    // Cohort Parameters
    const cohortIds = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"];
    const limits = [2, 2, 2, 2, 2, 2, 2, 2, 2, 2];
    const tokenMints = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    before(async () => {
        [owner, user1] = await ethers.getSigners();

        const shreyasSigner = await ethers.getSigner(
            "0xdf5948455621722ee5EF86e79a1e1283635194b3"
        );

        const NFTDistributorFactory = await ethers.getContractFactory(
            "NFTDistributor"
        );
        NFTDistributor = await NFTDistributorFactory.deploy(
            baseUri,
            cohortIds,
            limits,
            tokenMints
        );
        await NFTDistributor.deployed();
        console.log(`NFTDistributor deployed at ${NFTDistributor.address}`);
    });

    it("Admin should claim tokens for winners", async () => {
        const tokenId1 = await NFTDistributor.adminClaimToken("1", winner1);
        const tokenId2 = await NFTDistributor.adminClaimToken("1", winner2);
    });

    it("Admin should try to mint token for loser", async () => {
        await expect(
            NFTDistributor.adminClaimToken("1", loser1)
        ).to.be.revertedWith("ConclaveX: max tokens issued for cohort");
    });
});
