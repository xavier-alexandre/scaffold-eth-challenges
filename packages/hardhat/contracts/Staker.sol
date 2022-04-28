pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;
    mapping(address => uint256) public balances;
    uint256 public constant threshold = 1 ether;
    uint256 public deadline = block.timestamp + 72 hours;
    bool public openForWithdraw = false;

    constructor(address exampleExternalContractAddress) public {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
    }

    // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
    //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
    event Stake(address, uint256);

    modifier deadlineReached(bool isComplete) {
        if (isComplete) {
            require(timeLeft() == 0, "Deadline not met");
        } else {
            require(timeLeft() > 0, "Deadline met");
        }
        _;
    }

    modifier notOverThreshold() {
        require(
            address(this).balance <= threshold,
            "Balance not over threshold"
        );
        _;
    }

    modifier notCompleted() {
        require(
            !exampleExternalContract.completed(),
            "External contract not completed"
        );
        _;
    }

    // "payable" means that whatever value is passed in msg.value will add up to the internal contract balance
    function stake() public payable deadlineReached(false) notCompleted {
        balances[msg.sender] += msg.value;
        emit Stake(msg.sender, msg.value);
    }

    // After some `deadline` allow anyone to call an `execute()` function
    //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
    function execute() public deadlineReached(true) notCompleted {
        if (address(this).balance >= threshold) {
            exampleExternalContract.complete{value: address(this).balance}();
        } else {
            openForWithdraw = true;
        }
    }

    // if the `threshold` was not met, allow everyone to call a `withdraw()` function

    // Add a `withdraw(address payable)` function lets users withdraw their balance
    function withdraw(address payable addr)
        public
        payable
        deadlineReached(true)
        notOverThreshold
        notCompleted
    {
        require(addr == msg.sender, "Can only withdraw to your own address");
        require(openForWithdraw, "Not yet open for withdraw");
        // msg.sender.transfer(balances[msg.sender]);
        (bool success, ) = addr.call{value: balances[msg.sender]}("");
        require(success, "Transfer failed.");
        balances[addr] = 0;
    }

    // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
    function timeLeft() public view returns (uint256) {
        if (deadline >= block.timestamp) {
            return deadline - block.timestamp;
        } else {
            0;
        }
    }

    // Add the `receive()` special function that receives eth and calls stake()
    receive() external payable {
        stake();
    }
}
