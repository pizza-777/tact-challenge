import "@stdlib/deploy";

/*
  TASK 3 - Dex contract 
  Create a simple jetton dex contract that trades one pair of token A and B.
  The price of tokens depends on amount of tokens that sc have.
  So, if smartcontract have 10 of token A and 2 of token B, then after sending 1 tokens B you will receive 5 of tokens A.
  
  If user will pool dont have enougth tokens to trade
  (for example someone will send 99999 tokens of B and dex pool have only 10 of tokens A),
  then return sended (tokens B in our example) tokens back to user

  Implement a getter that will give the number of tokens in the pool and +
  one more to get price of token A or token B. +
  
  Note
  Admin can add token A and token B just by sending then to smartcontract (we need to set initial supply for the pool). 
*/
contract JettonWallet {
    owner: Address;
    balance: Int as coins;
    master: Address;
    init(master: Address, owner: Address){        
        self.master = master;
        self.owner = owner;
        self.balance = 0;
    }
}

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

message(0x178d4519) InternalTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    responseAddress: Address;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice?;
}

contract Task3 with Deployable {
  owner: Address;
  a: Int;
  b: Int;
  jAddressA: Address;
  jAddressB: Address;
  decimal: Int;

  init(admin: Address, newJAddressA: Address, newJAddressB: Address) {
    self.owner = admin;
    self.jAddressA = newJAddressA;
    self.jAddressB = newJAddressB;
    self.a = 0;
    self.b = 0;
    self.decimal = 1000000000;
    self.replenishPool(100000);
  }

  receive(msg: TokenNotification) {
    let walletStateInitA: StateInit = initOf JettonWallet(self.jAddressA, msg.from);
    let walletStateInitB: StateInit = initOf JettonWallet(self.jAddressB, msg.from);
    let tokenA: Address = contractAddress(walletStateInitA);
    let tokenB: Address = contractAddress(walletStateInitB);

    //Admin can add token A and token B just by sending then to smartcontract
    if(sender() == self.owner){
     self.replenishPool(msg.amount);
     return;
    }
    
    //check if proper token sended
    if(sender() == self.jAddressA){
      //check Amount
      let price: Int = self.price(self.jAddressA);
      if(price == 0) {
        return;//maybe return token
      }
      let amount: Int = msg.amount * price;
      if(amount > self.b){
        //to return not enough tokens
         self.sendTokens(msg, sender(), msg.amount); //return back
      }             
      self.sendTokens(msg, contractAddress(walletStateInitB), amount); //exchange
      //exchange with A
    }else if(sender() == self.jAddressB){
       //check Amount
      let price: Int = self.price(self.jAddressB);
      if(price == 0) {
        return;
      }
      let amount: Int = msg.amount * price;
      if(amount > self.a){
        //to return not enough tokens
         self.sendTokens(msg, sender(), msg.amount); //return back
      }             
      self.sendTokens(msg, contractAddress(walletStateInitA), amount); //exchange
      //exchange with A
    }else{//unknown token
      //return back tons
      self.sendTokens(msg, sender(), msg.amount); //exchange
    }
  } 

  fun sendTokens(msg:TokenNotification, to: Address, amount: Int) {
    send(SendParameters{
                to: to,
                bounce: false,
                value: 0,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: InternalTransfer{
                    queryId: msg.queryId,
                    amount: amount,
                    from: sender(),
                    responseAddress: msg.from,//user wallet
                    forwardTonAmount: 0,
                    forwardPayload: msg.forwardPayload
                }.toCell()
            });
  }

fun replenishPool(amount: Int){   
       //check if proper token sended
      if(sender() == self.jAddressA){
        self.a = self.a + amount;
      }else if(sender() == self.jAddressB){
        self.b = self.b + amount;
      }else{//unknown token
        //return back
        return;
      }   
}
 
  
  //get price of token A or token B
  get fun price(token: Address): Int { 
    if(token == self.jAddressA){
      return self.b/self.a;
    }

    if(token == self.jAddressB){
      return self.a/self.b;
    }

    return 0;
  }
  
  //a getter that will give the number of tokens in the pool
  get fun balance(token: Address): Int {
    if(token == self.jAddressA){
      return self.a;
    }

    if(token == self.jAddressB){
      return self.b;
    } 

    return 0;
  }
}
