import { parseEther } from "ethers";
import { ethers } from "hardhat";

describe("LZERC20", () => {
    
    const SrcChainId = 1;
    const DstChainId = 2;
    const globalSupply = parseEther("1000000");

    let owner, lzEndpointSrcMock, lzEndpointDstMock, OFTSrc, OFTDst, LZEndpointMock, OFTMock, OFT, dstPath, srcPath

    before(async function () {
        owner = (await ethers.getSigners())[0]

        LZEndpointMock = await ethers.getContractFactory("LZEndpointMock");
        OFTMock = await ethers.getContractFactory("OFTMock");
        OFT = await ethers.getContractFactory("OFT");
        
    });
});