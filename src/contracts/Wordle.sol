pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

//import "hardhat/console.sol";
//import "@openzeppelin/contracts/utils/math/SafeMath.sol";
//import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract Wordle {

  event gameCreated(address gameOwner, address secondPlayer, uint gameBet);
  event MoveMade(address mover, string answer);
  event gameStarted(address gameOwner, uint totalGameBet);
  event gameEnded(address gameOwner, address secondPlayer, uint noOfMovesSecondPlayer, string outcome);

  struct Games {
        bytes32 answer;
        uint depositOwner;
        uint depositSecondPlayer;
        uint noOfMovesOwner;
        uint noOfMovesSecondPlayer;
        address secondPlayer;
        uint256 timeStarted; //timestamp
        State state;
        bool isValid;
        address firstMovePlayer;
    }

  mapping (address => Games) public games;
  enum State { Created, Accepted, Waiting, GameEnded }


  modifier GameShouldNotExist(address owner) {
       require(!(games[owner].isValid == true), "You have already created a game");
        _;
    }

  modifier GameShouldExist(address owner) {
    require(games[owner].isValid == true, "Start This. Game does not exist");
        _;
  }

  modifier IsPlayerInvolved(address owner) {
    require(games[owner].secondPlayer == msg.sender, "You are not involved in the game");
        _;
  }

  constructor() payable {
    // what should we do on deploy?
  }

  function startGame(address secondPlayer, bytes32 secrethash) public payable GameShouldNotExist(msg.sender) {
    //make sure the secondplayer is not owner
    require(msg.sender != secondPlayer, "Please add any other address other than owners");
    //make sure some ether is sent atleast
    require(msg.value > 0, "Please send some money");
    games[msg.sender]  = Games(
        {
            isValid: true,
            secondPlayer: payable(secondPlayer),
            depositOwner: msg.value,
            depositSecondPlayer: 0,
            noOfMovesOwner: 0,
            noOfMovesSecondPlayer: 0,
            timeStarted: block.timestamp,
            state: State.Created,
            answer: secrethash,
            firstMovePlayer: address(0)
        }
    );
    
   emit gameCreated(msg.sender, secondPlayer, msg.value);
  }

  function acceptGame(address gameOwner) public payable GameShouldExist(gameOwner) IsPlayerInvolved(gameOwner) {
    //check if the same amount is sent
    require(games[gameOwner].depositOwner == msg.value, "Please add the sufficient amount");
    //check if game exists
    //check if he is involved in the game or is not a owner - Done by isPlayerInvolved

    //check if game is ready to accept
    require(games[gameOwner].state == State.Created, "It has already been accepted");

    games[gameOwner].state = State.Accepted;
    games[gameOwner].depositSecondPlayer = msg.value;

    uint totalAmount = games[gameOwner].depositOwner +  games[gameOwner].depositSecondPlayer;

    emit gameStarted(gameOwner, totalAmount);
  }
  
  function addMove(address gameOwner, string memory answer) public GameShouldExist(gameOwner)  {
    //chcek if valid game and is occuring
    require(games[gameOwner].state == State.Accepted, "The game has not yet started");
    //check if part of game
    require(gameOwner == msg.sender || games[gameOwner].secondPlayer == msg.sender , "You should be the owner or the second player");

    //check if not exceeding 5 moves
    require(games[gameOwner].noOfMovesOwner < 6 && games[gameOwner].noOfMovesSecondPlayer < 6, "Exceeding the number of moves allowed");
    //add moves
    if(gameOwner == msg.sender){
      games[gameOwner].noOfMovesOwner++;
    }
    if(games[gameOwner].secondPlayer == msg.sender){
      games[gameOwner].noOfMovesSecondPlayer++;
    }

    emit MoveMade(msg.sender, answer);
  }


 function submitAnswer(address gameOwner, string memory secret) public{
    // The game should be ongoing
    // BUG - same player can call this twice
    require(gameOwner == msg.sender || games[gameOwner].secondPlayer == msg.sender , "You should be the owner or the second player");
    // same player cannot call twice
    require(games[gameOwner].firstMovePlayer != msg.sender, "Already submitted answer");

    require(games[gameOwner].state == State.Accepted || games[gameOwner].state == State.Waiting , "The game should be in Accepted or Waiting state");

    require(keccak256(abi.encodePacked(secret)) == games[gameOwner].answer, "Invalid Secret");

    if(games[gameOwner].state == State.Accepted){
      games[gameOwner].state = State.Waiting;
      games[gameOwner].firstMovePlayer = msg.sender;
    }else if(games[gameOwner].state == State.Waiting){
      
      if(games[gameOwner].noOfMovesOwner<games[gameOwner].noOfMovesSecondPlayer){
        //Player 1 won
        payable(gameOwner).transfer(games[gameOwner].depositOwner + games[gameOwner].depositSecondPlayer/2 );
        payable(games[gameOwner].secondPlayer).transfer(games[gameOwner].depositSecondPlayer/2 );
        emit gameEnded(gameOwner, games[gameOwner].secondPlayer,games[gameOwner].noOfMovesOwner, "Player 1 Won");
      }else if(games[gameOwner].noOfMovesOwner>games[gameOwner].noOfMovesSecondPlayer){
        //Player 2 won
        payable(gameOwner).transfer(games[gameOwner].depositOwner/2);
        payable(games[gameOwner].secondPlayer).transfer(games[gameOwner].depositOwner/2 + games[gameOwner].depositSecondPlayer);
        emit gameEnded(gameOwner, games[gameOwner].secondPlayer,games[gameOwner].noOfMovesSecondPlayer, "Player 2 Won");
      }else{
        //draw
        payable(gameOwner).transfer(games[gameOwner].depositOwner);
        payable(games[gameOwner].secondPlayer).transfer(games[gameOwner].depositSecondPlayer);
        emit gameEnded(gameOwner, games[gameOwner].secondPlayer,games[gameOwner].noOfMovesSecondPlayer, "Draw");

      }
      games[gameOwner].state = State.GameEnded;
    }

    ////check if game exists
    //check if the secret is equal to the secret hash 
    //if game not finished, then just add to the list 
    //if won, add ether to the winner's address - 75% 25%
    //
  }

  
  // User from FE --> Moralis
  // Moralis --> generates a random word from random number
  // Moralis hashes the random number --> FE
  // FE --> hash --> SC
  // SC --> Starts the game
  // FE --> Move with word --> SC
  // SC --> Generates event after trx --> Gets caught by Moralis
  // Moralis--> checks if correct word --> by using the stored randome number 
  // If not --> sends nothing to FE and asks to try again
  // FE --> sends correct word --> SC --> gets caught by Moralis
  // Moralis checks if correct , if yes --> sends the first initiated random number --> FE
  // FE --> random number --> SC hashes the random number 
  // SC --> checks if hash(random number) matches stored hash
  // SC compares both players and waits for completition to determine winner 

  //--Other complexities
  // Timer of 24 hours
  // Compare winners by moves
  // allocate funds based on winner - 25% 75%


  //--Data type conversions
  //1. random number --> string
  //2. string --> keccak256 -> Random number hash 
  //3. Random number hash --> bytes32
  //4. bytes32 --> stored in SC
  //5  comparision on SC -->  
  //6.        --> convert random number string --> bytes32 --> keccak256 -> Random number hash (in bytes32)
  //7.        --> Random number bytes32 generated === Random number bytes32 stored ?


  // --Limitations
  //  - One player cannot start two games
  //  - Funds should be withdrawn after each game. Otherwise their instance of game will be lost if they start a new game (can we 
  //    solve this by keeping a global variable of balances?)
  //  - 

  // SMB --> rent user (RU) -->  NFT --> key to gated online services
//                             NFT --> WL to new projects and taking the risk of buy the new NFT
// RU --> takes SMB and goes to metavers land
//  


  // to support receiving ETH by default
  receive() external payable {}
  fallback() external payable {}
}
