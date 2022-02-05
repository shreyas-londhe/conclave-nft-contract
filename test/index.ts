import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFT Distributor", function () {
    let NFTDistributor: any;

    // Cohort Parameters
    const cohortIds = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"];
    const limits = [10, 10, 10, 10, 10, 10, 10, 10, 10, 10];
    const tokenMints = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    before(async () => {
        const NFTDistributorFactory = await ethers.getContractFactory(
            "NFTDistributor"
        );
        NFTDistributor = await NFTDistributorFactory.deploy();
    });
});
