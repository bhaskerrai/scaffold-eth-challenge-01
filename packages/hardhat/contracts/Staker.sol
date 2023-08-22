// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;  //Do not change the solidity version as it negativly impacts submission grading

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  event Stake(address, uint256);

  uint256 public constant threshold = 1 ether;
  mapping ( address => uint256 ) public balances;
  uint256 public deadline = block.timestamp + 72 hours;
  ExampleExternalContract public exampleExternalContract;
  bool public openForWithdraw = true;
  bool public executed;
  address[] public users;

  constructor(address exampleExternalContractAddress) {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  modifier notCompleted {
    require(!exampleExternalContract.completed(), "Completed!");
    _;
  }

  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
  // ( Make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
  function stake() public payable{
    require(timeLeft() != 0, "Time's up for staking!");
    balances[msg.sender] += msg.value;

    address[] memory usersTemp = users;

    bool isNewUser = true;
    for (uint256 i = 0; i < usersTemp.length; i++) {
      if (usersTemp[i] == msg.sender) {
        isNewUser = false;
        break;
      }
    }
    
    if (isNewUser) {
      users.push(msg.sender);
    }

    openForWithdraw = address(this).balance < threshold;

    emit Stake(msg.sender, msg.value);
  }

  // After some `deadline` allow anyone to call an `execute()` function
  // If the deadline has passed and the threshold is met, it should call `exampleExternalContract.complete{value: address(this).balances}()`
  function execute() notCompleted public {
    require(!executed, "Already Executed!");
    require(timeLeft() == 0 , "There is still some time left!");
    // require(!openForWithdraw, "Didn't reach the threshold!");
    if(openForWithdraw) {
      console.log("Threshold didn't reached");
      return;
    }

    executed = true;

    address[] memory usersTemp = users;

    for(uint256 i = 0; i < usersTemp.length; i++) {
      address user = usersTemp[i];
      uint256 bal = balances[user];
      balances[user] = 0;
      (bool sucess, ) = user.call{value: bal}("");
      require(sucess, "Failed sending ETH to user!");
    }
    exampleExternalContract.complete{value: address(this).balance}();

  }


  // If the `threshold` was not met, allow everyone to call a `withdraw()` function to withdraw their balances
  function withdraw() notCompleted public {
    require(!executed, "Already Executed!");
    require(openForWithdraw, "Threshold Reached!");
    uint256 bal = balances[msg.sender];
    require(bal > 0, "You didn't deposit anything!");
    balances[msg.sender] -= bal;
    (bool success, ) = msg.sender.call{value: bal}("");
    require(success, "Ether transfer to msg.sender failed");
  }

  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  function timeLeft() public view returns (uint256) {
    if (block.timestamp >= deadline) {
      return 0;
    }
    return deadline - block.timestamp;
  }


  // Add the `receive()` special function that receives eth and calls stake()
  receive() external payable {
    stake();
  }

}
