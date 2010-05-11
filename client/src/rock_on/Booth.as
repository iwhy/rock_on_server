package rock_on
{
	import flash.events.IEventDispatcher;
	
	import game.GameClock;
	
	import models.OwnedStructure;
	
	import mx.collections.ArrayCollection;
	import mx.events.DynamicEvent;
	
	import views.WorldView;

	public class Booth extends OwnedStructure
	{
		public static const STOCKED_STATE:int = 1;
		public static const UNSTOCKED_STATE:int = 2;
		
		public var queueCapacity:Number;
		public var currentQueue:Number;
		public var actualQueue:Number;
		public var proxiedQueue:ArrayCollection;
		public var hasCustomerEnRoute:Boolean;
		public var state:int;
		
		public var _boothManager:BoothManager;
		[Bindable] public var _venue:Venue;
				
		public function Booth(boothManager:BoothManager, venue:Venue, params:Object=null, target:IEventDispatcher=null)
		{
			super(params, target);
			
			_boothManager = boothManager;
			_venue = venue;
			
			currentQueue = 0;	
			actualQueue = 0;
			proxiedQueue = new ArrayCollection();

			checkForLoadedStructure(params);
		}
		
		public function checkForLoadedStructure(params:Object):void
		{
			if (params['structure'])
			{
				structure = params.structure;
			}			
		}
		
		public function addToProxiedQueue(cp:CustomerPerson, pathLength:Number):void
		{
			var obj:Object = {cp: cp, pathLength: pathLength};
			proxiedQueue.addItem(obj);
		}
		
		public function removeFromProxedQueue(cp:CustomerPerson):void
		{
			for each (var obj:Object in proxiedQueue)
			{
				if (obj.cp == cp)
				{
					var index:int = proxiedQueue.getItemIndex(obj);
					proxiedQueue.removeItemAt(index);
				}
			}
		}
		
		public function getTotalInventory():int
		{
			var totalInventory:int = ContentIndex.setBoothInventoryByName(structure.name);
			return totalInventory;
		}
		
		public function advanceState(destinationState:int):void
		{
			switch (state)
			{	
				case STOCKED_STATE:
					endStockedState();				
					break;	
				case UNSTOCKED_STATE:
					endUnstockedState();
					break;						
				default: throw new Error('no state to advance from!');
			}
			switch (destinationState)
			{
				case STOCKED_STATE:
					startStockedState();
					break;
				case UNSTOCKED_STATE:
					startUnstockedState();
					break;
				default: throw new Error('no state to advance to!');	
			}
		}	
		
		public function endStockedState():void
		{
			
		}	
		
		public function startStockedState():void
		{
			state = STOCKED_STATE;
		}
		
		public function startUnstockedState():void
		{
			state = UNSTOCKED_STATE;
			_boothManager.addBoothCollectionButton(this);
			var evt:DynamicEvent = new DynamicEvent("unStockedState", true, true);
			dispatchEvent(evt);
		}
		
		public function endUnstockedState():void
		{
			
		}
		
		public function updateState():void
		{
			if (inventory_count > 0)
			{
				startStockedState();
			}
			else
			{
				startUnstockedState();
			}
			
			updateInventoryCount();
		}
		
		public function updateInventoryCount():void
		{
			if (state == STOCKED_STATE)
			{
				var fanCount:int = _venue.fancount;
				var averagePurchaseTime:int = (CustomerPerson.ENTHRALLED_TIME + CustomerPerson.QUEUED_TIME + 
					(_venue.myWorld.tilesWide / (WorldView.PERSON_SPEED * 50) * 1000))/1000;
				var updatedAt:int = GameClock.convertStringTimeToUnixTime(updated_at);
				var currentDate:Date = new Date();	
				var currentTime:int = currentDate.getTime()/1000 + (currentDate.getTimezoneOffset() * 60);
				var timeElapsed:int = currentTime - updatedAt;
				var numPurchases:int = (timeElapsed / averagePurchaseTime) * fanCount;
							
				if (numPurchases > inventory_count)
				{
					_boothManager.decreaseInventoryCount(this, inventory_count);
					inventory_count = 0;
				}
				else
				{
					inventory_count = inventory_count - numPurchases;
					_boothManager.decreaseInventoryCount(this, numPurchases);
				}
			}
		}
		
		public function set venue(val:Venue):void
		{
			_venue = val;
		}
		
		public function get boothManager():BoothManager
		{
			return _boothManager;
		}
		
	}
}