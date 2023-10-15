import "@stdlib/deploy";
/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining;
}
message(0x5fcc3d14) Transfer {
    queryId: Int as uint64;
    newOwner: Address;
    responseDestination: Address; //address where to send a response with confirmation of a successful transfer and the rest of the incoming message coins.
    customPayload: Cell?;
    forwardAmount: Int as coins;
    forwardPayload: Slice as remaining;
}
message NftWithdrawal {
    queryId: Int as uint64;
    nftAddress: Address;
}

contract Task4 with Deployable {
    seed: Int as uint128;
    lockedTime: Int as uint32 = 0; //кто его устанавливает ,овнер? 
    owner: Address?;
    nft: Address?;
    init(seed: Int){
        self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
    }

    receive(msg: OwnershipAssigned){            
        if (self.nft != null) { //if nft already holded - return nft back to the sender (nft contract)
            //return back nft
            send(SendParameters{
                    to: sender(),//is it self.nft item address?
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: true,
                    body: Transfer{
                      queryId: msg.queryId,
                      newOwner: msg.prevOwner,
                      responseDestination: msg.prevOwner,    
                      forwardAmount: 0,
                      forwardPayload: msg.forwardPayload,//? should I need to change prevOwner? No
                      customPayload: null 
                    }.toCell()
                }
            );
        }else{
          self.lockedTime = msg.forwardPayload.loadUint(32); // load locked time  
          self.nft = sender();  // nft item contract
          self.owner = msg.prevOwner;// prewOwner is the new owner after lock will be disabled
        }
    }

    receive(msg: NftWithdrawal){
        require(sender() != self.owner, "Invalid sender");
        if ((self.lockedTime - now()) > 0) {
            send(SendParameters{to: sender(),
                    value: 0,
                    mode: SendRemainingValue,
                    body: "NFT is still locked".asComment() // ? is it according to the TON's "message with text comment" standard ?
                }
            );
        } else {
            //what does it "mean send nft?"
            //maybe ownership assigned for new owner
            //look at this https://github.com/howardpen9/nft-template-in-tact/blob/84b33672a58e68eb6b6714c65c809426224231b1/sources/contract.tact
            //send message Transfer
            //
            send(SendParameters{
                  to: msg.nftAddress,
                  value: 0,
                  mode: SendRemainingValue,
                  bounce: true,
                  body: Transfer{
                      queryId: msg.queryId,                      
                      newOwner: self.owner!!,
                      responseDestination: self.owner!!,    
                      forwardAmount: 0,
                      customPayload: null,
                      forwardPayload: emptyCell().asSlice()    
                    }.toCell()
                }
            );
            self.nft = null;
            self.owner = null;
            self.lockedTime = 0;
        }
    }

    get fun time(): Int {      
        return self.lockedTime;      
    }

    get fun nft(): Address? {
        return self.nft;//check if null needed?
    }

    get fun owner(): Address? {
        return self.owner;
    }
}