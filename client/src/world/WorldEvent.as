package world
{
	import flash.events.Event;

	public class WorldEvent extends Event
	{
		public static const DESTINATION_REACHED:String = "World:DestinationReached";
		public static const FINAL_DESTINATION_REACHED:String = "World:FinalDestinationReached";	
		public static const DIRECTION_CHANGED:String = "World:DirectionChanged";	
		public static const PATHFINDING_FAILED:String = "World:PathfindingFailed";	
		public static const STRUCTURE_PLACED:String = "World:StructurePlaced";
		public static const ITEM_DROPPED:String = "World:ItemDropped";
		public static const PROGRESS_BAR_COMPLETE:String = "World:ProgressBarComplete";
		public static const WORLD_ASSIGNED:String = "World:WorldAdded";
		public static const ASSETS_DRAWN:String = "World:AssetsDrawn";
		
		public var _activeAsset:ActiveAsset;

		public function WorldEvent(type:String, activeAsset:ActiveAsset, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			_activeAsset = activeAsset;
		}
		
		public function set activeAsset(val:ActiveAsset):void
		{
			_activeAsset = val;
		}
		
		public function get activeAsset():ActiveAsset
		{
			return _activeAsset;
		}			
	}
}