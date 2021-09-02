// Seascape NFT
// SPDX-License-Identifier: MIT
pragma solidity 0.6.7;

import "./../openzeppelin/contracts/access/Ownable.sol";
import "./../openzeppelin/contracts/utils/Counters.sol";
import "./../openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./../openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";

/// @title Seapad NFT
/// @notice SeapadNFT is the NFT used in Seapad platform.
/// @author Medet Ahmetson
contract SeapadNft is ERC721, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private tokenId;

    uint256 public projectId;  // project to which it's used	

    struct Params {
	    uint256 allocation; // allocation among total pool of investors.
	    uint8 tier;         // tier level
        uint8 mintType;     // mint type: 1 = prefund pool, 2 = auction pool, 3 = private investor
    }

    mapping(address => bool) public minters;

    /// @dev returns parameters of Seascape NFT by token id.
    mapping(uint256 => Params) public paramsOf;

    event Minted(address indexed owner, uint256 indexed id, uint256 allocation, uint8 tier, uint8 mintType, uint256 projectId);
    
    /**
     * @dev Sets the {name} and {symbol} of token.
     * Mints all tokens.
     */
    constructor() public ERC721("Lighthouse", "LIGHTHOUSE") {
	    tokenId.increment(); // set to 1 the incrementor, so first token will be with id 1.
    }

    modifier onlyMinter() {
        require(minters[_msgSender()], "Seascape NFT: Only NFT Factory can call the method");
        _;
    }

    /// @dev ensure that all parameters are checked on factory smartcontract
    function mint(address _to, uint256 _allocation, uint8 _tier, uint8 _type, uint256 _projectId) public onlyMinter returns(uint256) {
	    require(_projectId == projectId, "Seapad: PROJECT_ID_MISMATCH");
        uint256 _tokenId = tokenId.current();

        _safeMint(_to, _tokenId);

        paramsOf[_tokenId] = Params(_allocation, _tier, _type);

        tokenId.increment();

        emit Minted(_to, _tokenId, _allocation, tier, _type, projectId);
        
        return _tokenId;
    }

    function setOwner(address _owner) public onlyOwner {
	    transferOwnership(_owner);
    }

    function setMinter(address _minter) public onlyOwner {
	    minters[_minter] = true;
    }

    function setMinter(address _minter) public onlyOwner {
	    minters[_minter] = false;
    }

    function setBaseUri(string memory _uri) public onlyOwner {
	    _setBaseURI(_uri);
    }
}
