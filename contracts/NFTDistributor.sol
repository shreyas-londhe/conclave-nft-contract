// SPDX-License-Identifier: Unlicense OR MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Buildspace is ERC721URIStorage, Ownable {
    mapping(address => mapping(string => uint256)) public claimed;
    mapping(address => bool) private admins;
    mapping(string => Cohort) public cohorts;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    string private contractBaseURI;
    bool public allowsTransfers = false;

    struct Cohort {
        uint128 limit;
        uint128 tokenMinted;
        bytes32 merkleRoot;
    }

    event Claim(
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
        uint128[] memory _tokenMints,
        bytes32[] memory _merkleRoots
    ) ERC721("ConclaveX", "CONX") {
        admins[msg.sender] = true;
        contractBaseURI = _contractBaseURI;

        // Initialize cohorts
        for (uint256 i = 0; i < _limits.length; i++) {
            cohorts[_cohortIds[i]] = (
                Cohort({
                    limit: _limits[i],
                    tokenMinted: _tokenMints[i],
                    merkleRoot: _merkleRoots[i]
                })
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

    modifier merkleCheck(
        string memory _cohortId,
        bytes32[] memory _proof,
        address to
    ) {
        bytes32 leaf = keccak256(abi.encodePacked(to));
        require(
            MerkleProof.verify(_proof, cohorts[_cohortId].merkleRoot, leaf),
            "ConclaveX: address not eligible for claim"
        );
        _;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return contractBaseURI;
    }

    function issueToken(
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

        uint256 newTokenId = _tokenIdTracker.current();
        claimed[to][_cohortId] = newTokenId;

        _safeMint(to, newTokenId);
        emit Claim(to, _cohortId, nextCohortTokenIndex, newTokenId, _isAdmin);

        _setTokenURI(newTokenId, _uri);

        cohorts[_cohortId].tokenMinted = nextCohortTokenIndex + 1;
        _tokenIdTracker.increment();

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

    function adminClaimToken(
        string memory _cohortId,
        bytes32[] memory _proof,
        address to
    ) external onlyAdmin merkleCheck(_cohortId, _proof, to) returns (uint256) {
        return issueToken(_cohortId, to, true);
    }

    // To be used by users to claim token on their own behalf.
    function claimToken(string memory _cohortId, bytes32[] memory _proof)
        external
        merkleCheck(_cohortId, _proof, msg.sender)
        returns (uint256)
    {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_proof, cohorts[_cohortId].merkleRoot, leaf),
            "ConclaveX: address not eligible for claim"
        );

        return issueToken(_cohortId, msg.sender, false);
    }

    function setAllowsTransfers(bool _allowsTransfers) external onlyAdmin {
        allowsTransfers = _allowsTransfers;
    }

    function createCohort(
        string memory _cohortId,
        uint128 _limit,
        bytes32 _merkleRoot
    ) external onlyAdmin {
        require(
            cohorts[_cohortId].limit == 0,
            "ConclaveX: Cohort already exists"
        );
        require(_limit > 0, "ConclaveX: Limit must be greater than 0");
        Cohort memory cohort = Cohort({
            limit: _limit,
            tokenMinted: 0,
            merkleRoot: _merkleRoot
        });
        cohorts[_cohortId] = cohort;
    }

    function setMerkleRoot(string memory _cohortId, bytes32 _merkleRoot)
        external
        onlyAdmin
    {
        require(cohorts[_cohortId].limit > 0, "ConclaveX: No cohort limit set");
        cohorts[_cohortId].merkleRoot = _merkleRoot;
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
