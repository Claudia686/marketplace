// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Marketplace
 * @author Claudia
 * @notice A marketplace contract for listing and buying items
 * @dev This contract allows the owner to list items for sale and users to buy them
 */
contract Marketplace {
    /**
     * @notice Struct to list items on the marketplace
     */
    struct Item {
        string name;
        uint256 cost;
        uint256 quantity;
    }

    /**
     * @notice address of the owner
     * @notice itemCount to keep track of the number of items
     */
    address public owner;
    uint256 public itemCount;

    /**
     * @notice mapping to store items from Struct
     * @notice mapping of user address to their balance
     */
    mapping(uint256 => Item) public items;
    mapping(address => uint256) public balances;

    /**
     * @notice Emits when an item is sold
     * @notice Emits when an item is listed
     * @notice Emits when refunded
     * @notice Emits when the owner withdraws funds
     */
    event itemSold(address indexed buyer, uint256 indexed id, uint256 amount);
    event itemListed(string name, uint256 cost, uint256 quantity);
    event Refunded(address indexed buyer, uint256 indexed id, uint256 qty, uint256 amount);
    event withdrawn(address indexed owner, uint256 amount);

    /**
     * @dev Throws when the caller is not the owner
     * @dev Throws when the address is invalid
     * @dev Throws when the ETH sent is not enough
     * @dev Throws when the item id is invalid
     * @dev Throws when the item is sold out
     * @dev Throws when buyer has nothing to refund
     * @dev Throws when the item is not in stock
     * @dev Throws when the refund fails
     * @dev Throws when there is nothing to withdraw
     * @dev Throws when the withdraw fails
     * @dev Throws when the balance is not enough to refund
     * @dev Throws when balance is not enough to buy one or more items
     */
    error NotTheOwner();
    error InvalidAddress();
    error NotEnoughEth();
    error InvalidId();
    error ItemsoldOut();
    error NothingToRefund();
    error NotEnoughItemInStock();
    error RefundFailed();
    error NothingToWithdraw();
    error WithdrawFailed();
    error NotEnoughBalance();

    /**
     * @dev Only owner can list and withdraw
     */
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotTheOwner();
        }
        _;
    }

    /**
     * @dev Constructor to set the owner of the contract
     */
    constructor() {
        owner = msg.sender;
        if (owner == address(0)) {
            revert InvalidAddress();
        }
    }

    /**
     * @param _name The name of the item
     * @param _cost The cost of the item
     * @param _quantity The quantity of the item
     * @dev Only the owner can call this function
     * @notice This function allows the owner to list one or more items for sale
     * @notice Emits an event when item is listed
     */
    function listItem(string memory _name, uint256 _cost, uint256 _quantity) public onlyOwner {
        items[itemCount] = Item(_name, _cost, _quantity);
        itemCount++;
        emit itemListed(_name, _cost, _quantity);
    }

    /**
     * @param _id The id of the item to buy
     * @param qty The quantity of the item to buy
     * @dev This function allows a buyer to buy one or more items by sending ETH
     * @notice Reverts if the item id is invalid
     * @notice The qty multiply with item cost
     * @notice Reverts if the ETH sent is not enough
     * @notice Reverts if there is not enough items in stock
     * @notice Reverts if items are sold
     * @notice Reduces the number of items available in stock
     * @notice Updates user balance
     * @notice Emits an event when item was bought
     */
    function buyItem(uint256 _id, uint256 qty) public payable {
        if (_id >= itemCount) {
            revert InvalidId();
        }

        Item storage item = items[_id];
        uint256 totalCost = item.cost * qty;

        if (msg.value < totalCost) {
            revert NotEnoughEth();
        }

        if (item.quantity < qty) {
            revert NotEnoughItemInStock();
        }

        if (item.quantity == 0) {
            revert ItemsoldOut();
        }

        item.quantity -= qty;
        balances[msg.sender] += msg.value;
        emit itemSold(msg.sender, _id, totalCost);
    }

    /**
     * @param _id The id of the item to refund
     * @param _qty The quantity of the item to refund
     * @dev Allows buyer to refund one or more items
     * @notice Reverts when nothing to refund or already refunded
     * @notice Updates qty after a refund
     * @notice Reverts if buyer balance is less than refund amount
     * @notice Updates refund amount
     * @dev Refund to the buyer
     * @notice Emits an event if refunded
     */
    function refund(uint256 _id, uint256 _qty) public {
        if (balances[msg.sender] == 0) {
            revert NothingToRefund();
        }

        Item storage item = items[_id];

        uint256 refundAmount = item.cost * _qty;
        item.quantity += _qty;

        if (balances[msg.sender] < refundAmount) {
            revert NotEnoughBalance();
        }

        balances[msg.sender] -= refundAmount;

        (bool success,) = msg.sender.call{value: refundAmount}("");
        if (!success) {
            revert RefundFailed();
        }

        emit Refunded(msg.sender, _id, _qty, refundAmount);
    }

    /**
     * @dev Owner can withdraw funds
     * @notice Reverts if no funds to withdraw
     * @notice Emits an event if withdrawn
     */
    function withdraw() public onlyOwner {
        uint256 withdrawBalance = address(this).balance;

        // check if there is any balance
        if (withdrawBalance == 0) {
            revert NothingToWithdraw();
        }

        (bool success,) = owner.call{value: withdrawBalance}("");
        if (!success) {
            revert WithdrawFailed();
        }

        emit withdrawn(msg.sender, withdrawBalance);
    }
}
