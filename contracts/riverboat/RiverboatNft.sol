pragma solidity 0.6.7;

import "./../openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./../openzeppelin/contracts/math/SafeMath.sol";
import "./../openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./../openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./../openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./../openzeppelin/contracts/access/Ownable.sol";
import "./../seascape_nft/SeascapeNft.sol";
import "./../openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NftSwapParamsInterface.sol";

/// @title RiverboatNft is a nft service platform
/// User can buy nft at a slots 1-5
/// In intervals of time slots are replenished and nft prices increase
/// @author Nejc Schneider
contract RiverboatNft is IERC721Receiver, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Session(
        uint256 startPrice;	         // nft price in the initial interval
        uint256 priceIncrease;		   // how much nftPrice increase every interval
        uint32 startTime;			       // session start timestamp (max 2106)
        uint32 intervalDuration;		 // duration of single interval – in seconds
        uint32 intervalsAmount;	     // total of intervals
        uint32 slotsAmount;          // total of slots
        address supportedCurrency;   // nft Token address
        // instead of intervalsAmount we coule use endTime
        // uint32 endTime			     // session end timestamp
        // slotIndex -> soldTokens
        mapping(uint256 => SoldToken) soldTokens;
    );

    struct SoldToken(
        uint256 intervalNumber;
        uint256 slotNumber;
        uint256 buyTime;
        uint256 buyPrice;
        address buyer;
    );

    uint256 public currentPrice;       // price of nfts in current interval
    uint256 public currentInterval;    // number of current interval
    uint256 public tradeEnabled;       // enable/disable buy function
    uint256 public sessionId;          // current sessionId
    address public priceReceiver;      // this address receives the money from bought tokens

    /// @dev session id => Session struct
    mapping(uint256 => Session) public sessions;
    // ERC721 => true/false
    mapping(address=>bool) public supportedNfts;
    // ERC20 => true/false
    mapping(address=>bool) public supportedCurrencies;
    // sessionId => intervalId => slotId => buyersAddress
    mapping(uint256 => mapping(uint256 => mapping(uint256 => address))) public mintedNfts;

    event Buy(
        uint256 indexed sessionId,
        uint256 slotId
        uint256 price,
        address feeReceiver,
        address indexed sender,
    );

    event startSession(
        uint256 indexed sessionId;
        uint256 indexed priceIncrease;
        uint32 startTime;
        uint32 interval
    );

    event updateSession(
        uint256 indexed sessionId;
        uint256 priceIncrease;
        uint256 intervalDuration;
        uint256 intervalsAmount;
    );

    // @dev initialize the contract
    // @param _priceReceiver
    // @param _nftAddress initial supported nft series
    // @param _set receiver
    constructor(address _priceReceiver, address _nftAddress, address _currencyAddress) public {
          require(_nftAddress != address(0), "Invalid nft address");
          require(_priceReceiver != address(0), "Invalid money receiver address");

          priceReceiver = _priceReceiver;
          supportedNfts[_nftAddress] = true;
          supportedCurrencies[_currencyAddress] = true;

          // sessionId.increment(); 	// starts at value 1
          // nftFactory = NftFactory(_nftFactory);
    }

    //--------------------------------------------------------------------
    // Beta functions that modifiy state variables or session data
    //--------------------------------------------------------------------

    /// CAUTION this function is highly experimental and dangerous to use.
    /// Should be avoided until extensive tests are complete.
    /// @notice update current price during the session
    /// @dev the consecutive intervals price will also be different
    /// @param _newPrice new price to be set
    function updateCurrentPrice(uint256 _newPrice) external onlyOwner returns (currentPrice){
        require(_newPrice > 0, "price should be higher than 0");

        currentPrice = _newPrice;
        return currentPrice;
    }

    /// CAUTION this function is highly experimental and dangerous to use.
    /// Should be avoided until extensive tests are complete.
    /// @dev Update existing/running session data
    function updateSessionData(
        uint256 priceIncrease,
        uint256 intervalDuration,
        uint256 intervalsAmount
    )
        external
        onlyOwner
    {

        // TODO require statements
        // session can either be starting in the future or currently running
        // cant be finished

        // priceIncrease will apply during next interval
        // intervalDuration can either apply immediately or in next interval
        // intervalsAmount will be applied immediately

        // update session data

        // emit event
    }

    //--------------------------------------------------------------------
    // onlyOwner functions
    //--------------------------------------------------------------------

    /// @notice enable/disable buy function
    /// @param _tradeEnabled set tradeEnabled to true/false
    function enableTrade(bool _tradeEnabled) external onlyOwner { tradeEnabled = _tradeEnabled; }

    /// @notice add supported nft token
    /// @param _nftAddress ERC721 contract address
    function addSupportedNft(address _address) external onlyOwner{
        require(_address != 0x0, "address can't be 0x0")
        require(!supportedNfts[_address], "address already supported");
        supportedNfts[_address] = true;
    }

    /// @notice disable supported nft token
    /// @param _nftAddress ERC721 contract address
    function removeSupportedNft(address _address) external onlyOwner{
        require(_address != 0x0, "invalid address")
        require(supportedNfts[_address], "address already unsupported");
        supportedNfts[_address] = false;
    }

    /// @notice add supported currency address for bounty
    /// @param _currencyAddress ERC20 contract address
    function addSupportedCurrency(address _currencyAddress) external onlyOwner {
        require(_currencyAddress != address(0x0), "invalid address");
        require(!supportedCurrencies[_currencyAddress], "currency already supported");
        supportedCurrencies[_currencyAddress] = true;
    }

    /// @notice disable supported currency address for bounty
    /// @param _currencyAddress ERC20 contract address
    function removeSupportedCurrency(address _currencyAddress) external onlyOwner {
        require(_currencyAddress != address(0x0), "invalid address");
        require(supportedCurrencies[_currencyAddress], "currency already removed");
        supportedCurrencies[_currencyAddress] = false;
    }

    // authorize address to mint unsold nfts
    function withdrawUnsoldNfts(uint _sessionId, address _authorizedAddress) external onlyOwner {
        if(_authorizedAddress ! Authorized){
            // give factory permission for _authorizedAddress to mint all remaining nfts in _sessionId
        }
        // address already have permission to factory, so just give him permission to mint the remaining
        // nfts in _sessionId. Actual minting will be done through calling *another function*
    }

    /// @dev start a new session, during which players are allowed to buy nfts
    /// @parm **NEED TO INPUT ALL SESSION PARAMS
    function startSession(struct session) onlyOwner external {
        require(!isActive(session), "another session already active)
    }

    //--------------------------------------------------------------------
    // Public Pure/View functions for fetching data
    //--------------------------------------------------------------------

    // @notice calculate sum of unsold nfts per slot (or total)
    // @dev if _slotId input is 5, sum of all unsold nfts per session will be returned
    // @param _sessionId id of session to querry
    // @param _slotId id of the slot to querry (0-4)
    function getUnsoldNftsPerSlot(uint256 _sessionId, uint256 _slotId) public view {
        Session memory session = sessions[_sessionId];
        // require session is finished
        uint256 memory unsoldNfts;
        for(uint256 memory i = 0; i < session.intervalsAmount; i++){
          if(se)
          unsold
        }
    }

    function getCurrentInterval() public view returns(uint) {
        return currentInterval;
    }

    function getSessionData(uint256 _sessionId) public returns(struct) {
        // TODO return struct session
    }

    //--------------------------------------------------------------------
    // External functions
    //--------------------------------------------------------------------

    /// @notice
    function Buy(uint256 _sessionId, uint256 _slotIndex) external returns (currentPrice) {
      //require stamements
      // session must be running
      // nftAtSlot must be available
      // user must have enough balance

      // save user address to mapping (and maybe to soldTokens struct ?)

      // transfer currentPrice from buyer to priceReceiver
      // transfer nft from factory to buyer

      // emit Buy
    }

    /// @notice check that nft at slot is available for sell
    /// @param _seesionId session unique identifier
    /// @param _intervalNumber number of the interval
    /// @param _slotIndex slot number
    /// @return true if nft at slot is unsold
    function isNftAtSlotAvailable(uint _sessionId, uint _intervalNumber, uint _slotIndex)
        internal
        view
        returns (bool)
    {
      	if(mintedNfts[_sessionId][_intervalNumber][_slotIndex] == address(0))
            return true;
        return false;
    }

    /// @dev returns true if session is active
    /// @param _sessionId id to verify
    /// @return true/false depending on timestamp period of the sesson
    function isActive(uint256 _sessionId) internal view returns (bool){
        Session memory session = sessions[_sessionId];
        //reformat following require inside if
        if(now > session.startTime && now < session
            .startTime + session.intervalsAmount * session.intervalsDuration){
            return true;
        }
        return false;
    }

    /// @dev returns true if session is about to start
    /// @param _sessionId id to verify
    /// @return true/false depending on start time of the sesson
    function isAboutToStart(uint256 _sessionId) internal view returns (bool){
        Session memory session = sessions[_sessionId];
        //reformat following require inside if
        if(now < session.startTime)
            return true;
        return false;
    }
}
