/*-------------------------------------------------------------------------
 *
 * Paxos-TP.oz
 *
 *    Transaction Participant for the Paxos Consensus Commit Protocol    
 *
 * LICENSE
 *
 *    Beernet is released under the Beerware License (see file LICENSE) 
 * 
 * IDENTIFICATION 
 *
 *    Author: Boriss Mejias <boriss.mejias@uclouvain.be>
 *
 *    Last change: $Revision: 403 $ $Author: boriss $
 *
 *    $Date: 2011-05-19 21:45:21 +0200 (Thu, 19 May 2011) $
 *
 * NOTES
 *
 *    Implementation of transaction participant (TP) role on the paxos
 *    consensus algorithm. This is one of the replicas of the protocol. If the
 *    majority of TPs survives the transaction, the transaction will finish. 
 *    
 *-------------------------------------------------------------------------
 */

functor
import
   Component      at '../../corecomp/Component.ozf'
   Constants      at '../../commons/Constants.ozf'
export
   New
define

   NOT_FOUND   = Constants.notFound
   NO_VALUE    = Constants.noValue

   fun {New CallArgs}
      Self
      %Listener
      MsgLayer
      NodeRef
      DB

      Id
      NewItem
      Leader
      RTMs

      %% === Events =========================================================

      %% --- Interaction with TPs ---
      proc {Brew brew(hkey:   HKey
                      leader: TheLeader
                      rtms:   TheRTMs
                      tid:    Tid
                      item:   TrItem 
                      protocol:_ 
                      tag:trapp)}
         Tmp
         DBItem
         Vote
      in 
         RTMs     = TheRTMs
         NewItem  = item(hkey:HKey item:TrItem tid:Tid)
         Leader   := TheLeader
         Tmp      = {@DB get(HKey TrItem.key $)}
         DBItem   = if Tmp == NOT_FOUND orelse Tmp.value == NO_VALUE then
                        item(key:      TrItem.key
                             secret:   TrItem.secret
                             value:    NO_VALUE 
                             version:  0
                             readers:  nil
                             locked:   false)
                    else
                       Tmp
                    end
         %% Brewing vote - tmid needs to be added before sending
         Vote = vote(vote:    _
                     key:     TrItem.key 
                     secret:  TrItem.secret
                     version: DBItem.version 
                     tid:     Tid 
                     tp:      tp(id:Id ref:@NodeRef)
                     tag:     trapp)
         if TrItem.version >= DBItem.version
            andthen TrItem.secret == DBItem.secret
            andthen {Not DBItem.locked} then
            Vote.vote = brewed
            {@DB put(HKey TrItem.key {AdjoinAt DBItem locked true})}
         else
            Vote.vote = denied
         end
         {@MsgLayer dsend(to:@Leader.ref 
                          {Record.adjoinAt Vote tmid @Leader.id})}
         for TM in RTMs do
            {@MsgLayer dsend(to:TM.ref {Record.adjoinAt Vote tmid TM.id})}
         end
      end

      proc {Abort abort}
         DBItem
      in
         DBItem = {@DB get(NewItem.hkey NewItem.item.key $)}
         if DBItem \= NOT_FOUND then
            {PutItemAndAck DBItem}
         else
            {@DB delete(NewItem.hkey NewItem.item.key)}
            {AckDecision NewItem.item}
         end
      end

      proc {Commit commit}
         {PutItemAndAck NewItem.item}
      end

      proc {PutItemAndAck Item}
         {@DB put(NewItem.hkey Item.key {Record.adjoinAt Item locked false})}
         {AckDecision Item}
      end

      proc {AckDecision Item}
         {@MsgLayer dsend(to:@Leader.ref ack(key: Item.key
                                             tid: NewItem.tid
                                             tmid:@Leader.id
                                             tp:  tp(id:Id ref:@NodeRef)
                                             tag: trapp))}
      end

      %% --- Various --------------------------------------------------------

      proc {GetId getId(I)}
         I = Id
      end

      proc {SetDB setDB(ADB)}
         DB := ADB
      end

      proc {SetMsgLayer setMsgLayer(AMsgLayer)}
         MsgLayer := AMsgLayer
         NodeRef  := {@MsgLayer getRef($)}
      end

      Events = events(
                     %% Interaction with TM
                     brew:          Brew
                     abort:         Abort
                     commit:        Commit
                     %% Various
                     getId:         GetId
                     setDB:        SetDB
                     setMsgLayer:   SetMsgLayer
                     )
   in
      local
         FullComponent
      in
         FullComponent  = {Component.new Events}
         Self     = FullComponent.trigger
         %Listener = FullComponent.listener
      end
      MsgLayer = {NewCell Component.dummy}
      DB   = {NewCell Component.dummy}      

      Id       = {Name.new}
      NodeRef  = {NewCell noref}
      Leader   = {NewCell noleader}

      Self
   end
end  

