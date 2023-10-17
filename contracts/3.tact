import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  Example formula for amountOfAJettonToSend in B->A swap will be
  (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfTokenBToSwap / decimal

  If smart contract pool doesn't have enough jettons to trade,
  then it should send incoming jettons back to the user. For a clearer explanation,
  let's look at the example we described above (smart contract has 10 of jetton A and 2 of jetton B).
  If user will send 3 jettons B, smart contract should reject the message (because contract does not have 3 * 5 = 15 jettons A)
  and send 3 jettons B back to the user.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}
message(0xf8a7ea5) TokenTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

contract Task3 with Deployable {
    owner: Address;
    aAmount: Int as coins;
    bAmount: Int as coins;
    jettonAddressA: Address;
    jettonAddressB: Address;
    decimal: Int;
    jetton: Address?;
    init(admin: Address, newJettonAddressA: Address, newJettonAddressB: Address){
        self.owner = admin;
        self.jettonAddressA = newJettonAddressA; //dex jetton wallet A
        self.jettonAddressB = newJettonAddressB; //dex jetton wallet B
        self.aAmount = 0;
        self.bAmount = 0;
        self.decimal = 1000000000;
    }

    receive(msg: TokenNotification){
      //  nativeReserve(0, 2);
      let  ctx: Context = context();
      require(ctx.sender == self.jettonAddressA || ctx.sender == self.jettonAddressB, "Wrong sender");
      require(msg.amount > 0, "Jetton amount is 0");      
        if (ctx.sender == self.jettonAddressA) {
             if (msg.from == self.owner) {  
                 self.aAmount = self.aAmount + msg.amount;
                 return;
             }
            //dump("jettonA received");
            let amount: Int = (self.bAmount * self.decimal / self.aAmount) * msg.amount / self.decimal;
            if(amount > self.bAmount){
                self.sendJettons(msg, self.jettonAddressA, msg.amount);
                return;
            }
            self.bAmount = self.bAmount - amount;
            self.aAmount = self.aAmount + msg.amount;            
            self.sendJettons(msg, self.jettonAddressB, amount);
        }else{
             if (msg.from == self.owner) {  
                 self.bAmount = self.bAmount + msg.amount;
                 return;
             }
           //dump("jettonB received");
            let amount: Int = (self.aAmount * self.decimal / self.bAmount) * msg.amount / self.decimal;
            if(amount > self.aAmount){
                self.sendJettons(msg, self.jettonAddressB, msg.amount);
                return;
            }
            self.aAmount = self.aAmount - amount;
            self.bAmount = self.bAmount + msg.amount;              
            self.sendJettons(msg, self.jettonAddressA, amount);
        }
    }
     fun sendJettons(msg: TokenNotification, to: Address, amount: Int) {
        //dump("send swap");
        //dump(amount);
        send(SendParameters{to: to,
                value: ton("0.1"),
                bounce: true,
                mode: SendPayGasSeparately + SendIgnoreErrors,
                body: TokenTransfer{queryId: 0,
                    amount: amount,
                    destination: msg.from,
                    responseDestination: myAddress(),
                    customPayload: null,
                    forwardTonAmount: ton("0.01"),
                    forwardPayload: emptySlice()
                }.toCell()
            }
        );
    }

    get fun price(jetton: Address): Int {
        require(self.aAmount > 0 && self.bAmount > 0, "Wrong amount");
        require(jetton == self.jettonAddressA || jetton == self.jettonAddressB, "Wrong addr");
        if (jetton == self.jettonAddressA) {
            return (self.aAmount * self.decimal / self.bAmount)/self.decimal;
        }
        return (self.bAmount * self.decimal / self.aAmount)/self.decimal;
    }
  
    get fun balance(jetton: Address): Int {
        require(jetton == self.jettonAddressA || jetton == self.jettonAddressB, "Wrong addr");
        if (jetton == self.jettonAddressA) {
            return self.aAmount;
        }
        return self.bAmount;
    }
}