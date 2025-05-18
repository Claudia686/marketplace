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
    // list modifier
    // ---------------------
    modifier list() {
        vm.prank(OWNER);
        marketplace.listItem("Apple", 2e18, 1);
        _;
    }

    // ---------------------
    // buy modifier
    // ---------------------
    modifier buy() {
        vm.prank(BUYER);
        vm.deal(BUYER, 10e18);
        marketplace.buyItem{value: 2e18}(0, 1);
        _;
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
    function test_Revert_InavidId() public list {
        vm.prank(BUYER);
        vm.deal(BUYER, 2e18);
        vm.expectRevert(Marketplace.InvalidId.selector);
        marketplace.buyItem{value: 2e18}(2, 2);
    }

    function test_Revert_InvalidCost() public list {
        vm.prank(BUYER);
        vm.deal(BUYER, 0);
        vm.expectRevert(Marketplace.NotEnoughEth.selector);
        marketplace.buyItem{value: 0}(0, 1);
    }

    function test_Revert_NotEnoughItemInStock() public list {
        vm.prank(BUYER);
        vm.deal(BUYER, 4e18);
        vm.expectRevert(Marketplace.NotEnoughItemInStock.selector);
        marketplace.buyItem{value: 4e18}(0, 2);
    }

    function test_Revert_ItemsoldOut() public list {
        vm.deal(BUYER, 15e18);
        vm.startPrank(BUYER);
        marketplace.buyItem{value: 2e18}(0, 1);

        // Try buying again, now it's sold out
        vm.expectRevert(Marketplace.ItemsoldOut.selector);
        marketplace.buyItem{value: 2e18}(0, 1);
        vm.stopPrank();
    }

    // ---------------------
    // Test refund Success
    // ---------------------
    function test_GetRefund_And_EmitEvent() public list buy {
        vm.startPrank(BUYER);
        assertEq(marketplace.balances(BUYER), 2e18);
        vm.expectEmit(true, false, false, true);
        emit Marketplace.Refunded(BUYER, 0, 1, 2e18);
        marketplace.refund(0, 1);
        vm.stopPrank();
    }

    function test_ContractBalance() public list buy {
        vm.startPrank(BUYER);
        uint256 balanceBefore = address(marketplace).balance;
        marketplace.refund(0, 1);
        uint256 balanceAfter = address(marketplace).balance;
        assertEq(balanceBefore - balanceAfter, 2e18);
        vm.stopPrank();
    }

    function test_refund_And_RestoresItemQuantity() public list buy {
        vm.startPrank(BUYER);
        marketplace.refund(0, 1);
        (,, uint256 quantityAfter) = marketplace.items(0);
        assertEq(quantityAfter, 1);
        vm.stopPrank();
    }

    // ---------------------
    // Test refund Failure
    // ---------------------
    function test_Revert_ZeroBalance() public list {
        vm.startPrank(BUYER);
        vm.expectRevert(Marketplace.NothingToRefund.selector);
        marketplace.refund(0, 1);
        vm.stopPrank();
    }

    function test_Revert_InsuffcientBalance() public list buy {
        vm.startPrank(BUYER);
        vm.expectRevert(Marketplace.NotEnoughBalance.selector);
        marketplace.refund(0, 0.5 ether);
        vm.stopPrank();
    }

    // ---------------------
    // Test withdraw Success
    // ---------------------
    function test_Withdraw_And_EmitEvent() public list buy {
        vm.startPrank(OWNER);
        uint256 contractBalanceBefore = address(marketplace).balance;
        uint256 ownerBalanceBefore = address(OWNER).balance;

        // Emit event
        vm.expectEmit(true, false, false, true);
        emit Marketplace.withdrawn(OWNER, 2e18);
        marketplace.withdraw();
        
        // Check balances
        uint256 contractBalanceAfter = address(marketplace).balance;
        uint256 ownerBalanceAfter = address(OWNER).balance;
        assertEq(contractBalanceAfter, 0);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + contractBalanceBefore);
        vm.stopPrank();
    }

    // ---------------------
    // Test withdraw Failure
    // ---------------------
    function test_Revert_MultipleWithdraw() public list buy {
        vm.startPrank(OWNER);
        marketplace.withdraw();
        vm.expectRevert(Marketplace.NothingToWithdraw.selector);
        marketplace.withdraw();
    }

    function test_Revert_NonOwnerWithdraw() public list buy {
        vm.startPrank(BUYER);
        vm.expectRevert(Marketplace.NotTheOwner.selector);
        marketplace.withdraw();
    }
}
