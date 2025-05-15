// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Marketplace} from "src/Marketplace.sol";

contract MarketplaceTest is Test {
    Marketplace marketplace;
    address public OWNER = makeAddr("owner");
    address public BUYER = makeAddr("buyer");

    function setUp() public {
        vm.startPrank(OWNER);
        marketplace = new Marketplace();
        vm.stopPrank();
    }

    // ---------------------
    // Test listItem Success
    // ---------------------

    function test_ListingOneItem() public {
        vm.prank(OWNER);
        marketplace.listItem("Apple", 1e18, 10);
        (string memory itemName, uint256 itemCost, uint256 itemQuantity) = marketplace.items(0);
        assertEq(itemName, "Apple");
        assertEq(itemCost, 1e18);
        assertEq(itemQuantity, 10);
    }

    function test_ListMultipleItems() public {
        vm.startPrank(OWNER);
        marketplace.listItem("Cherry", 2e18, 5);
        marketplace.listItem("Apple", 3e18, 10);
        marketplace.listItem("Pear", 4e18, 15);
        vm.stopPrank();
        uint256 count = marketplace.itemCount();
        assertEq(count, 3);
    }

    function test_ListItem_EmitsEvent() public {
        vm.startPrank(OWNER);
        vm.expectEmit(false, false, false, true);
        emit Marketplace.ItemListed("Cherry", 2e18, 5);
        marketplace.listItem("Cherry", 2e18, 5);
    }

    // ---------------------
    // Test listItem Failure
    // ---------------------

    function test_Revert_NoOwnerListing() public {
        vm.prank(BUYER);
        vm.expectRevert(Marketplace.NotTheOwner.selector);
        marketplace.listItem("Apple", 1e18, 5);
    }

    // ---------------------
    // Test buyItem Success
    // ---------------------

    function test_buyItem_EmitsEvent() public {
        vm.prank(OWNER);
        marketplace.listItem("Apple", 1e18, 10);
        vm.prank(BUYER);
        vm.deal(BUYER, 2e18);
        vm.expectEmit(true, true, false, true);
        emit Marketplace.ItemSold(BUYER, 0, 2e18);

        // Buy item
        uint256 itemCost = 2e18;
        uint256 itemQty = 2;
        marketplace.buyItem{value: itemCost}(0, itemQty);

        // Item quantity decreased
        (,, uint256 remainingQty) = marketplace.items(0);
        assertEq(remainingQty, 8);

        // Buyer's balance increased
        uint256 buyerBalance = marketplace.balances(BUYER);
        assertEq(buyerBalance, itemCost);
    }

    // ---------------------
    // Test buyItem Failure
    // ---------------------

    function test_Revert_InavidId() public {
        vm.prank(OWNER);
        marketplace.listItem("Apple", 1e18, 10);
        vm.prank(BUYER);
        vm.deal(BUYER, 2e18);
        vm.expectRevert(Marketplace.InvalidId.selector);
        marketplace.buyItem{value: 2e18}(2, 2);
    }

    function test_Revert_InvalidCost() public {
        vm.prank(OWNER);
        marketplace.listItem("Apple", 1e18, 10);
        vm.prank(BUYER);
        vm.deal(BUYER, 0);
        vm.expectRevert(Marketplace.NotEnoughEth.selector);
        marketplace.buyItem{value: 0}(0, 1);
    }
}
