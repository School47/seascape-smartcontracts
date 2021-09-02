pragma solidity ^0.6.7;

import "./../openzeppelin/contracts/access/Ownable.sol";
import "./../openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SeapadAuction.sol";
import "./SeapadPrefund.sol";
import "./SeapadNft.sol";
import "./../crowns/erc-20/contracts/CrownsToken/CrownsToken.sol";

/**
 * @title Seapad
 * @notice The Seapad Manager of tokens by Seascape Network team, investors.
 * It distributes the tokens to the game devs.
 * 
 * This smartcontract gets active for a project, only after its prefunding is finished.
 *
 * This smartcontract determines how much PCC (Player created coin) the investor would get, 
 * and an amount of compensation in case PCC failure.
 * The determination is described as a Seapad NFT.
 */
contract SeapadManagement is Ownable {
    SeapadAuction   private seapadAuction;
    SeapadPrefund   private seapadPrefund;
    SeapadTier      private seapadTier;
    CrownsToken     private crowns;

    uint256 private constant SCALER = 10 ** 18;

    struct Project {
        uint256 prefundPool;            // The PCC pool for prefund investors
        uint256 auctionPool;            // The PCC pool for auction participants
        uint256 prefundCompensation;    // The Crowns that prefunders could get
        uint256 auctionCompensation;    // The Crowns that auction participants could get

        uint256 pool;                   // The total pool of tokens that users could get
        uint256 compensation;           // The total compensation of tokens that users could get
        address pcc;                    // The Game token that users are invested for
        address lighthouse;             // The nft dedicated for the project.

        uint256 startTime;              // The time when Token management starts. Its the endTime of SeapadAuction
    }

    mapping(uint256 => Project) public projects;

    /// @notice Check whether the user minted nft for the project or not
    mapping(uint256 => mapping(address => uint256)) public mintedNfts;

    event AddProject(uint256 indexed projectId, uint256 prefundPool, uint256 auctionPool, uint256 prefundCompensation, uint256 auctionCompensation, address indexed lighthouse, uint256 startTime);
    event AddPCC(uint256 indexed projectId, address indexed pcc);
    event ClaiNft(uint256 indexed projectId, uint256 allocation, address nft, uint256 nftId);

    constructor(address _seapadAuction, address _seapadPrefund, address _seapadTier, address _crowns) public {
        require(_seapadAuction != address(0) && _crowns != address(0) && _seapadPrefund != address(0) && _seapadTier != address(0), "Seapad: ZERO_ADDRESS");

        seapadAuction   = SeapadAuction(_seapadAuction);
        seapadPrefund   = SeapadPrefund(_seapadPrefund);
        SeapadTier      = SeapadTier(_seapadTier);
        crowns          = CrownsToken(_crowns);
    }

    /// @notice add a new project to the IDO project.
    function addProject(uint256 projectId, uint256 prefundPool, uint256 auctionPool, uint256 prefundCompensation, uint256 auctionCompensation, uint256 startTime, address lighthouse) external onlyOwner {
        require(projectId > 0 && prefundPool > 0 && auctionPool > 0 && prefundCompensation > 0 && auctionCompensation > 0, "Seapad: ZERO_PARAMETER");
        require(lighthouse != address(0), "Seapad: ZERO_ADDRESS");
        require(projects[projectId].startTime == 0, "Seapad: ALREADY_STARTED");
        require(startTime > 0, "Seapad: ZERO_PARAMETER");

        uint256 auctionEndTime = seapadAuction.getEndTime(projectId);
        require(auctionEndTime > 0, "Seapad: NO_AUCTION_END_TIME");
        require(startTime >= auctionEndTime, "Seapad: START_TIME_BEFORE_AUCTION_END");

        Project storage project = projects[projectId];
        
        uint256 totalPool;
        uint256 totalInvested;
        
        (totalPool, totalInvested) = seapadPrefund.getTotalPool(projectId);
        
        // Remained part of tokens that are not staked are going to auction pool
        if (totalInvested < totalPool) {
            uint256 percent = (totalPool - totalInvested) / (totalPool / 100);

            auctionPool = auctionPool + (prefundPool / 100 * percent);
            prefundPool = prefundPool - (prefundPool / 100 * percent);

            auctionCompensation = auctionCompensation + (prefundCompensation / 100 * percent);
            prefundCompensation = prefundCompensation - (prefundCompensation / 100 * percent);
        }

        project.prefundPool             = prefundPool;
        project.auctionPool             = auctionPool;
        project.prefundCompensation     = prefundCompensation;   
        project.auctionCompensation     = auctionCompensation;
        project.pool                    = prefundPool + auctionPool;
        project.compensation            = prefundPool + auctionCompensation;
        project.lighthouse              = lighthouse;                    
        project.startTime               = startTime;

        emit AddProject(projectId, prefundPool, auctionPool, prefundCompensation, auctionCompensation, lighthouse, startTime);
    }

    function addProjectPcc(uint256 projectId, address pcc) external onlyOwner {
        require(projectId > 0, "Seapad: PROJECT_NOT_EXIST");
        require(pcc != address(0), "Seapad: ZERO_ADDRESS");
        
        Project storage project = projects[projectId];
        require(project.pcc == address(0), "Seapad: ALREADY_ADDED");

        project.pcc = pcc;

        emit AddPCC(projectId, pcc);
    }

    //////////////////////////////////////////////////////////////////////
    //
    // The investor functions
    //
    //////////////////////////////////////////////////////////////////////

    /// @notice After the prefund phase, investors can get a NFT with the weight proportion to their investment.
    /// @dev Seapad should be added into SeapadTier.badgeUser();
    function claimNft(uint256 projectId) external {
        Project storage project = projects[projectId];
        require(project.startTime > 0, "Seapad: PROJECT_NOT_EXIST");
        require(block.timestamp >= project.startTime, "Seapad: NO_LAUNCH");
        require(mintedNfts[projectId][msg.sender] == , "Seapad: ALREADY_MINTED");

        bool prefunded = seapadPrefund.isPrefunded(projectId, msg.sender);
        uint256 totalInvested;
        uint256 spent;
        (spent, totalInvested) = seapadAuction.getSpent(projectId, msg.sender);

        uint8 mintType;
        require(prefunded || spent > 0, "Seapad: NOT_INVESTED");

        int8 tierLevel = seapadTier.getTierLevel(msg.sender);
        require(tierLevel > 0, "Seapad: INVALID_TIER");

        uint256 perPcc;
        uint256 allocation;        // Portion of Pool that user will get
        uint256 totalLimit;

        if (prefunded) {
            mintType = 1;
            (totalLimit, totalInvested) = seapadPrefunded.getTotalPool(projectId);

            perPcc = project.prefundPool.mul(SCALER).div(totalInvested);
            allocation = perPcc.mul(seapadPrefund.getFixedPrice(projectId, tierLevel));
        } else {
            mintType = 2;
            perPcc = project.auctionPool.mul(SCALER).div(totalInvested);
            allocation = perPcc.mul(spent);
        }

        SeapadNft seapadNft = SeapadNft(project.lighthouse);
        uint256 nftId = seapadNft.mint(msg.sender, allocation, tierLevel, mintType, projectId);
        require(nftId > 0, "Seapad: NO_NFT_MINTED");

        mintedNfts[projectId][msg.sender] = nftId;

        emit ClaiNft(projectId, allocation, project.lighthouse, nftId);
    }

    /// 100k, 10k cws, 10:1
    // @todo match to cws, to spend it.
    function burnForPcc(uint256 projectId, uint256 nftId) external {

    }

    // @todo transfer to staking pool PCC in ratio to CWS.                                                                             
    function burnForCws(uint256 projectId, uint256 nftId) external {

    }

    // @todo stake
    // @todo separated contract
    function stake(uint256 projectId, uint256 nftId) external {

    }

    // @todo separated contract
    /// need to ask: could it be any project. or user has to choose a certain project for burning this nft.
    // @todo any nft.
    function burnForProject(uint256 projectId, uint256 nftId, uint256 anotherProjectId) external {

    }
}