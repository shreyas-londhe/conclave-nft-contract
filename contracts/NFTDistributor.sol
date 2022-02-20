// SPDX-License-Identifier: Unlicense OR MIT

pragma solidity ^0.8.10;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTDistributor is ERC721URIStorage, Ownable {
    mapping(address => mapping(string => uint256)) public claimed; // personAddr => cohortId => numberOfNFTs
    mapping(address => bool) private admins; // personAddr => isAdmin
    mapping(string => Cohort) public cohorts; // cohortId => Cohort

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    string private contractBaseURI;
    bool public allowsTransfers = false;

    struct Cohort {
        uint128 limit;
        uint128 tokenMinted;
    }

    event NFTClaimed(
        address indexed _receiver,
        string indexed _cohortId,
        uint128 _cohortIndex,
        uint256 _contractIndex,
        bool _isAdmin
    );

    constructor(
        string memory _contractBaseURI,
        string[] memory _cohortIds,
        uint128[] memory _limits,
        uint128[] memory _tokenMints
    ) ERC721("ConclaveX", "CONX") {
        admins[msg.sender] = true;
        contractBaseURI = _contractBaseURI;

        // Initialize cohorts
        for (uint256 i = 0; i < _limits.length; i++) {
            cohorts[_cohortIds[i]] = (
                Cohort({ limit: _limits[i], tokenMinted: _tokenMints[i] })
            );
        }
    }

    modifier onlyAdmin() {
        require(
            admins[msg.sender] == true,
            "Only admins can call this function"
        );
        _;
    }

    modifier limitCheck(string memory _cohortId, address to) {
        require(
            cohorts[_cohortId].tokenMinted < cohorts[_cohortId].limit,
            "ConclaveX: max tokens issued for cohort"
        );
        require(
            claimed[to][_cohortId] == 0,
            "ConclaveX: address has already claimed token."
        );
        _;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return contractBaseURI;
    }

    function _issueToken(
        string memory _cohortId,
        address to,
        bool _isAdmin
    ) internal limitCheck(_cohortId, to) returns (uint256) {
        uint128 nextCohortTokenIndex = cohorts[_cohortId].tokenMinted;
        string memory _uri = string(
            abi.encodePacked(
                _cohortId,
                "-",
                uint2str(nextCohortTokenIndex),
                "/metadata.json"
            )
        );

        _tokenIdTracker.increment();
        uint256 newTokenId = _tokenIdTracker.current();
        claimed[to][_cohortId] = newTokenId;

        _safeMint(to, newTokenId);

        _setTokenURI(newTokenId, _uri);

        cohorts[_cohortId].tokenMinted = nextCohortTokenIndex + 1;

        emit NFTClaimed(
            to,
            _cohortId,
            nextCohortTokenIndex,
            newTokenId,
            _isAdmin
        );

        return newTokenId;
    }

    function uint2str(uint128 _i) internal pure returns (string memory str) {
        if (_i == 0) return "0";

        uint128 j = _i;
        uint128 length;
        while (j != 0) {
            length++;
            j /= 10;
        }

        bytes memory bstr = new bytes(length);
        uint128 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        str = string(bstr);
        return str;
    }

    function adminClaimToken(string memory _cohortId, address to)
        external
        onlyAdmin
        returns (uint256)
    {
        return _issueToken(_cohortId, to, true);
    }

    function setAllowsTransfers(bool _allowsTransfers) external onlyAdmin {
        allowsTransfers = _allowsTransfers;
    }

    function createCohort(string memory _cohortId, uint128 _limit)
        external
        onlyAdmin
    {
        require(
            cohorts[_cohortId].limit == 0,
            "ConclaveX: Cohort already exists"
        );
        require(_limit > 0, "ConclaveX: Limit must be greater than 0");
        Cohort memory cohort = Cohort({ limit: _limit, tokenMinted: 0 });
        cohorts[_cohortId] = cohort;
    }

    function updateAdmin(address _admin, bool isAdmin) external onlyOwner {
        admins[_admin] = isAdmin;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(
            from == address(0) || to == address(0) || allowsTransfers,
            "Not allowed to transfer"
        );
        return super._beforeTokenTransfer(from, to, tokenId);
    }
}
