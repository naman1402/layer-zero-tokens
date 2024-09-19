import { expect } from "chai";
import { AddressLike, ChainstackProvider, parseEther, parseUnits, solidityPacked } from "ethers";
import { ethers } from "hardhat";

describe("LZERC20", () => {
    
    const SrcChainId = 1;
    const DstChainId = 2;
    const globalSupply = parseEther("1000000");
    const name = "OmniChainFungibleTokens"
    const symbol = "OFT"

    let owner: any, lzEndpointSrcMock, lzEndpointDstMock: any, OFTSrc: any, OFTDst: any, LZEndpointMock: any, OFTMock: any, OFT: any, dstPath, srcPath: any

    before(async function () {
        owner = (await ethers.getSigners())[0]

        LZEndpointMock = await ethers.getContractFactory("LZEndpointMock");
        OFTMock = await ethers.getContractFactory("LZERC20Mock");
        OFT = await ethers.getContractFactory("LZERC20"); 
    });

    beforeEach(async function () {

        lzEndpointSrcMock = await LZEndpointMock.deploy(SrcChainId)
        lzEndpointDstMock = await LZEndpointMock.deploy(DstChainId)
        OFTSrc = await OFTMock.deploy(lzEndpointSrcMock.address)
        OFTDst = await OFT.deploy(name, symbol, lzEndpointDstMock.address)

        lzEndpointSrcMock.setDestLzEndpoint(OFTDst.address, lzEndpointDstMock.address)
        lzEndpointDstMock.setDestLzEndpoint(OFTSrc.address, lzEndpointSrcMock.address)

        dstPath = solidityPacked(["address", "address"], [OFTDst.address, OFTSrc.address])
        srcPath = solidityPacked(["address", "address"], [OFTSrc.address, OFTDst.address])
        await OFTSrc.setTrustedRemote(DstChainId, dstPath)
        await OFTDst.setTrustedRemote(SrcChainId, srcPath)

        await OFTSrc.setMinDstGas(DstChainId, parseInt(await OFTSrc.PT_SEND()), 220000)
        await OFTSrc.setUseCustomAdapterParams(true)
        await OFTSrc.mitnTokens(owner.address, globalSupply)
    })

    describe("setting up the payload", async function () {

        const adapterParams = solidityPacked(["uint16", "uint256"], [1, 225000])
        const sendQty = parseUnits("1", 18)

        beforeEach(async function () {

            expect(await OFTSrc.balanceOf(owner.address)).to.be.equal(globalSupply)
            expect(await OFTDst.balanceOf(owner.address)).to.be.equal("0")
            await lzEndpointDstMock.blockNextMsg()

            let nativeFee = (await OFTSrc.estimateSendFees(DstChainId, owner.address, sendQty, false, adapterParams)).nativeFee

            await expect(OFTSrc.sendFrom(
                owner.address,
                DstChainId,
                solidityPacked(["address"], [owner.address]),
                sendQty,
                owner.address,
                ethers.ZeroAddress,
                adapterParams,
                { value: nativeFee }
            )).to.emit(LZEndpointMock, "PayloadStored")
            // expect(await OFTSrc.balanceOf(owner.address)).to.be.equal(globalSupply.sub(sendQty))
            expect(await OFTDst.balanceOf(owner.address)).to.be.equal(0)
        })

        it("hasStoredPayload() - stores the payload", async function () {
            expect(await lzEndpointDstMock.hasStoredPayload(SrcChainId, srcPath)).to.equal(true)
        })

        it("getLengthofQueue() - can't send another msg if payload is blocked", async function () {
            expect(await lzEndpointDstMock.getLengthofQueue(SrcChainId, srcPath)).to.equal(0)
            let nativeFee = (await OFTSrc.estimateSendFees(DstChainId, owner.address, sendQty, false, adapterParams)).nativeFee
            
            await expect(OFTSrc.sendFrom(
                owner.address,
                DstChainId,
                solidityPacked(["address"], [owner.address]),
                sendQty,
                owner.address,
                ethers.ZeroAddress,
                adapterParams,
                { value: nativeFee }
            )).to.not.reverted

            expect(await lzEndpointDstMock.getLengthofQueue(SrcChainId, srcPath)).to.equal(1)
        })

        // it("retryPayload() - delivers a stuck msg", async function () {

        //     expect(await OFTDst.balanceOf(owner.address)).to.be.equal(0)
        //     const payload = ethers.AbiCoder(["uint16", "bytes", "uint256"], [0, owner.address, sendQty])
        //     await expect(lzEndpointDstMock.retryPayload(SrcChainId, srcPath, payload)).to.emit(lzEndpointDstMock, "PayloadCleared")
        //     expect(await OFTDst.balanceOf(owner.address)).to.be.equal(sendQty)
        // })

        it("forceResumeReceive() - removes msg", async function () {
            // balance before is 0
            expect(await OFTDst.balanceOf(owner.address)).to.be.equal(0)

            // forceResumeReceive deletes the stuck msg
            await expect(OFTDst.forceResumeReceive(SrcChainId, srcPath)).to.emit(lzEndpointDstMock, "UaForceResumeReceive")

            // stored payload gone
            expect(await lzEndpointDstMock.hasStoredPayload(SrcChainId, srcPath)).to.equal(false)

            // balance after transfer is 0
            expect(await OFTDst.balanceOf(owner.address)).to.be.equal(0)
        })

        it("forceResumeReceive() - remove msg, delivers all msgs in the queue", async function () {})
        it("forceResumeReceive() - emptied queue is actually emptied and doesn't get double counted", async function() {})
    })
});