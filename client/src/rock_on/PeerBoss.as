package rock_on
{
	import mx.collections.ArrayCollection;
	
	import world.Point3D;
	
	public class PeerBoss extends ArrayCollection
	{
		public var _venue:Venue;
		public var peerCreatures:ArrayCollection;
		
		public function PeerBoss(venue:Venue, source:Array=null)
		{
			super(source);
			_venue = venue;
		}
		
		public function add(peer:Peer):void
		{
			this.addItem(peer);
			peer.myWorld = _venue.myWorld;
			var destination:Point3D = _venue.pickRandomAvailablePointWithinRect(_venue.boothsRect, _venue.myWorld, 0, _venue.crowdBufferRect, true, true);
			_venue.myWorld.addAsset(peer, destination);
			peer.advanceState(Peer.STOPPED_STATE);
			peer.setQuestStatus();
		}
		
		public function removePeers():void
		{
			var peerLength:int = length;
			for (var i:int = (peerLength - 1); i >= 0; i--)				
			{
				var peer:Peer = this[i] as Peer;
				remove(peer);
			}
		}
		
		public function remove(peer:Peer):void
		{
			_venue.myWorld.removeAsset(peer);
			var index:int = this.getItemIndex(peer);
			this.removeItemAt(index);
			peer = null;
		}		
		
		public function addAfterInitializing(peer:Peer):void
		{
			_venue.myWorld.removeAsset(peer);
			peer.reInitialize();
			peer.lastWorldPoint = null;
			peer.proxiedDestination = null;
			peer.currentDestination = null;
			var destination:Point3D = _venue.pickRandomAvailablePointWithinRect(_venue.boothsRect, _venue.myWorld, 0, _venue.crowdBufferRect, true, true);
			_venue.myWorld.addAsset(peer, destination);
		}		
	}
}