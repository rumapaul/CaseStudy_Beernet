/*-------------------------------------------------------------------------
 *
 * pp2p.oz
 *
 *    Implements perfect point-to-point link from Guerraoui's book
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
 *    This is an implementation of module 2.3 of R. Guerraouis book on reliable
 *    distributed programming. Properties "reliable delivery", "no duplication"
 *    and "no creation" are guaranteed by the implementation of Port in Mozart.
 *
 * EVENTS
 *
 *    Accepts: pp2pSend(Dest Msg) - Sends message Msg to destination Dest. Dest
 *    must be an Oz Port
 *
 *    Indication: pp2pDeliver(Src Msg) - Delivers message Msg sent by source
 *    Src.
 *    
 *-------------------------------------------------------------------------
 */

functor

import
   Component   at '../corecomp/Component.ozf'
   System

export
   New

define

   DELTA       = 500    % Granularity to tune the link delay (in sync with failure detector)
   INIT_DELAY     = 0   % Initial Timeout value
   MAX_DELAY = 2000   % Timeout must not go beyond this value

   fun {New}
      SitePort       % Port to receive messages
      Listener       % Upper layer component
      FullComponent  % This component
      DelayPeriod      % Link Delay Knob 

      proc {GetPort getPort(P)}
         P = SitePort
      end

      proc {PP2PSend pp2pSend(Dest Msg)}
         try
            thread
               {Delay @DelayPeriod}
               {Port.send Dest SitePort#Msg}
            end
            %{Port.send Dest SitePort#Msg}
         catch _ then
            %% TODO: improve exception handling
            skip
         end
      end

      proc {HandleMessages Str}
         case Str
         of (Src#Msg)|NewStr then
            {@Listener pp2pDeliver(Src Msg)}
            {HandleMessages NewStr}
         [] nil then % Port close
            skip
         %% To avoid crashing when the format is not respected,
         %% uncomment the else statement
         %else
         %   {HandleMessages Str.2}
         end
      end

      proc {InjectLinkDelay injectLinkDelay}
          if @DelayPeriod + DELTA =< MAX_DELAY then
              DelayPeriod := @DelayPeriod + DELTA
          end
          {System.showInfo "Link Delay:"#@DelayPeriod}
      end

      Events = events(
                  getPort:    GetPort
                  pp2pSend:   PP2PSend
                  injectLinkDelay: InjectLinkDelay
                  )

   in
      DelayPeriod = {NewCell INIT_DELAY}
      local
         Stream
      in
         {Port.new Stream SitePort}
         thread
            {HandleMessages Stream}
         end
      end
      FullComponent = {Component.new Events}
      Listener = FullComponent.listener
      FullComponent.trigger
   end
end
