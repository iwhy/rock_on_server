package rock_on
{
	import controllers.CreatureController;
	import controllers.DwellingController;
	import controllers.LayerableController;
	import controllers.LevelController;
	import controllers.StructureController;
	
	import flash.events.IEventDispatcher;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.geom.Rectangle;
	import flash.utils.Timer;
	
	import game.Counter;
	import game.CounterEvent;
	import game.GameClock;
	
	import helpers.CreatureGenerator;
	
	import models.OwnedDwelling;
	import models.OwnedStructure;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Button;
	import mx.core.Application;
	import mx.core.FlexGlobals;
	
	import spark.primitives.Rect;
	
	import views.BandBoss;
	import views.VenueManager;
	import views.WorldBitmapInterface;
	
	import world.BitmapBlotter;
	import world.Point3D;
	import world.World;

	public class Venue extends OwnedDwelling
	{	
		public static const UNINITIALIZED_STATE:int = 0;	
		public static const SHOW_STATE:int = 1;
		public static const ENCORE_STATE:int = 2;
		public static const CROWDED_STATE:int = 3;
		public static const EMPTY_STATE:int = 4;
		public static const ENCORE_WAIT_STATE:int = 5;
		public static const SHOW_WAIT_STATE:int = 6;
		
		public static const SHOW_TIME:int = 3600000;
		public static const ENCORE_TIME:int = 360000;
		public static const ENCORE_WAIT_TIME:int = 1800000;
		public static const VENUE_FILL_FRACTION:Number = 0.5;
		
		public static const BOOTH_SECTION_FRACTION:Number = 0.4;
		public static const STAGE_BUFFER_SQUARES:int = 2;
		public static const OUTSIDE_SQUARES:int = 10;
		public static const CROWD_BUFFER_FRACTION:Number = 0.3;
		
		public var state:int;
		public var assignedSeats:ArrayCollection;
		public var numAssignedSeats:int;
		public var startShowButton:Button;
		public var mainEntrance:Point3D;
		public var entryPoints:ArrayCollection;
		public var _venueManager:VenueManager;
		
		public var mainCrowdRect:Rectangle;
		public var venueRect:Rectangle;
		public var boothsRect:Rectangle;
		public var crowdBufferRect:Rectangle;
		public var stageBufferRect:Rectangle;
		public var audienceRect:Rectangle;
		public var stageRect:Rectangle;
		
		public var _bandBoss:BandBoss;
		public var _bandMemberManager:BandMemberManager;
		
		public var creatureGenerator:CreatureGenerator;
		public var boothBoss:BoothBoss;
		public var groupieBoss:GroupieBoss;
		public var customerPersonManager:CustomerPersonManager;
		public var listeningStationBoss:ListeningStationBoss;		
		public var stageManager:StageManager;

		public var _wbi:WorldBitmapInterface;
		public var _dwellingController:DwellingController;
		public var _structureController:StructureController;
		public var _creatureController:CreatureController;
		public var _layerableController:LayerableController;
		public var _myWorld:World;
		public var _bitmapBlotter:BitmapBlotter;
		
		public var numSuperCustomers:int;
		public var numStaticCustomers:int;
		public var numMovingCustomers:int;		
		
		public function Venue(wbi:WorldBitmapInterface, venueManager:VenueManager, dwellingController:DwellingController, creatureController:CreatureController, layerableController:LayerableController, structureController:StructureController, bandBoss:BandBoss, params:Object=null, target:IEventDispatcher=null)
		{
			super(params, target);
			
			_layerableController = layerableController;
			_structureController = structureController;
			_venueManager = venueManager;
			_wbi = wbi;
			_dwellingController = dwellingController;
			_creatureController = creatureController;
			_bandBoss = bandBoss;
			
			entryPoints = new ArrayCollection();
			setEntrance(params);
			setAdditionalProperties(params);
			
			numStaticCustomers = Math.floor(fancount * VenueManager.STATIC_CUSTOMER_FRACTION);
			numSuperCustomers = Math.floor(fancount * VenueManager.SUPER_CUSTOMER_FRACTION);
			numMovingCustomers = fancount - numStaticCustomers - numSuperCustomers;			
			
			addEventListener(VenueEvent.BOOTH_UNSTOCKED, onBoothUnstocked);			
			
			addStageManager();	
		}
		
		public function addStageManager():void
		{
			stageManager = new StageManager(_structureController);
			stageManager.createStage();
		}
		
		public function setLayout():void
		{
			venueRect = new Rectangle(0, 0, _myWorld.tilesWide - OUTSIDE_SQUARES, _myWorld.tilesDeep);
			boothsRect = new Rectangle(0, 0, _myWorld.tilesWide - OUTSIDE_SQUARES, Math.round(_myWorld.tilesDeep * BOOTH_SECTION_FRACTION))
			stageBufferRect = new Rectangle(0, (_myWorld.tilesDeep - stageManager.concertStage.structure.depth - STAGE_BUFFER_SQUARES), stageManager.concertStage.structure.width + STAGE_BUFFER_SQUARES, stageManager.concertStage.structure.depth + STAGE_BUFFER_SQUARES);	
			stageRect = new Rectangle(0, (_myWorld.tilesDeep - stageManager.concertStage.structure.depth), stageManager.concertStage.structure.width, stageManager.concertStage.structure.depth);	
			crowdBufferRect = new Rectangle(Math.ceil((1 - CROWD_BUFFER_FRACTION) * venueRect.width), boothsRect.bottom, venueRect.right - (Math.ceil((1 - CROWD_BUFFER_FRACTION) * venueRect.width)), venueRect.height - boothsRect.height);
			mainCrowdRect = new Rectangle(0, boothsRect.bottom, crowdBufferRect.left, (stageBufferRect.top - boothsRect.bottom - 1));
			audienceRect = new Rectangle(0, boothsRect.bottom, venueRect.width, venueRect.height - boothsRect.height - 1);
			
			assignedSeats = _myWorld.pathFinder.createSeatingArrangement(audienceRect, stageBufferRect, this.dwelling.capacity);
		}
		
		public function onBoothUnstocked(evt:VenueEvent):void
		{
			customerPersonManager.removeBoothFromAvailable(evt.booth);
		}	
		
		public function update(deltaTime:Number):void
		{
			if (customerPersonManager)
			{
				customerPersonManager.update(deltaTime);			
			}
			if (listeningStationBoss)
			{
				listeningStationBoss.passerbyManager.update(deltaTime);							
			}
		}
		
		public function addStaticStuffToVenue():void
		{
			setLayout();
			updateState();	
			
			getNumberOfBitmaps();
			
			customerPersonManager = new CustomerPersonManager(_myWorld, this);
			boothBoss = new BoothBoss(_structureController, _myWorld, this);
			listeningStationBoss = new ListeningStationBoss(_structureController, _layerableController, stageManager, _myWorld, this, boothBoss, customerPersonManager);

//			add UI layer to boothBoss
			boothBoss.setInMotion();
			listeningStationBoss.setInMotion();
		}	
		
		public function addMovingStuffToVenue():void
		{
			creatureGenerator = new CreatureGenerator(_layerableController);
			_wbi.customerPersonManager = customerPersonManager;
			groupieBoss = new GroupieBoss(customerPersonManager, boothBoss, stageManager.concertStage, _creatureController, _myWorld, this);

			listeningStationBoss.addStaticStationListeners();
			listeningStationBoss.showPassersby();
			
			addStaticCustomersToVenue();
			trace("static customers added");
			addSuperCustomersToVenue(stageManager.myStage);
			trace("super customers added");
			addMovingCustomersToVenue();
			trace("moving customers added");
			groupieBoss.setInMotion();
			trace("groupies started");
		}		
		
		public function setAdditionalProperties(params:Object):void
		{
			if (params['dwelling'])
			{
				dwelling = params.dwelling;
			}				
		}
		
		private function getNumberOfBitmaps():void
		{
			var totalStructures:int = 0;
			for each (var os:OwnedStructure in _structureController.owned_structures)
			{
				if (os.structure.structure_type == "Booth")
				{
					totalStructures++;
				}
			}
			_bitmapBlotter.expectedAssetCount = numStaticCustomers + totalStructures;				
		}		
		
		public function updateState():void
		{
			updateStateOnServer(false);
		}
		
		public function updateStateOnServer(showButtonClicked:Boolean):void
		{
			var timeElapsed:int = getUpdatedTimeElapsed();
			_venueManager.dwellingController.serverController.sendRequest({id: id, time_elapsed_client: timeElapsed, show_button_clicked: showButtonClicked}, "owned_dwelling", "update_state");
		}
		
		public function getUpdatedTimeElapsed():int
		{
			var currentDate:Date = new Date();
			var timeSinceStateChanged:int = currentDate.getTime()/1000 + (currentDate.timezoneOffset * 60) - GameClock.convertStringTimeToUnixTime(_state_updated_at);
			return timeSinceStateChanged;
		}
		
		public function addStaticCustomersToVenue():void
		{
			if (!customerPersonManager.concertStage)
			{
				customerPersonManager.concertStage = stageManager.concertStage;
			}
			for (var i:int = 0; i < numStaticCustomers; i++)
			{
				var cp:CustomerPerson = creatureGenerator.createCustomer("Concert Goer", "walk_toward", stageManager.concertStage, boothBoss);
				cp.speed = 0.06;
				customerPersonManager.add(cp, false, i);
			}
		}
		
		public function addSuperCustomersToVenue(worldToUpdate:World):void
		{
			if (!customerPersonManager.concertStage)
			{
				customerPersonManager.concertStage = stageManager.concertStage;
			}
			for (var i:int = 0; i < numSuperCustomers; i++)
			{
				var cp:CustomerPerson = creatureGenerator.createCustomer("Concert Goer", "walk_toward", stageManager.concertStage, boothBoss);
				cp.speed = 0.06;
				cp.isSuperFan = true;
				customerPersonManager.add(cp, true, -1, stageBufferRect, stageRect, worldToUpdate);
			}					
		}
		
		public function addMovingCustomersToVenue():void
		{
			if (!customerPersonManager.concertStage)
			{
				customerPersonManager.concertStage = stageManager.concertStage;
			}
			for (var i:int = 0; i < numMovingCustomers; i++)
			{
				var cp:CustomerPerson = creatureGenerator.createCustomer("Concert Goer", "walk_toward", stageManager.concertStage, boothBoss);
				cp.speed = 0.06;
				customerPersonManager.add(cp, true, -1, boothsRect);
			}			
		}
		
		public function removeCustomersFromVenue():void
		{
			for each (var cp:CustomerPerson in customerPersonManager)
			{
				customerPersonManager.remove(cp);
			}
		}		
		
		public function stateTranslateString():int
		{
			switch (_last_state)
			{
				case "empty_state":
					return EMPTY_STATE;
				case "show_state":
					return SHOW_STATE;
				case "encore_state":
					return ENCORE_STATE;
				case "show_wait_state":
					return SHOW_WAIT_STATE;
				case "encore_wait_state":
					return ENCORE_WAIT_STATE;
				default: throw new Error("Unrecognized state name");					
			}
		}		
		
		public function advanceState(destinationState:int):void
		{
			switch (state)
			{
				case UNINITIALIZED_STATE:
					break;
				case SHOW_STATE:
					endShowState();
					break;				
				case ENCORE_STATE:
					endEncoreState();				
					break;	
				case CROWDED_STATE:
					endCrowdedState();
					break;						
				case EMPTY_STATE:
					endEmptyState();
					break;						
				case ENCORE_WAIT_STATE:
					endEncoreWaitState();
					break;						
				case SHOW_WAIT_STATE:
					endShowWaitState();
					break;						
				default: throw new Error('no state to advance from!');
			}
			switch (destinationState)
			{
				case SHOW_STATE:
					startShowState();
					break;
				case ENCORE_STATE:
					startEncoreState();
					break;
				case CROWDED_STATE:
					startCrowdedState();
					break;
				case EMPTY_STATE:
					startEmptyState();
					break;
				case ENCORE_WAIT_STATE:
					startEncoreWaitState();
					break;
				case SHOW_WAIT_STATE:
					startShowWaitState();
					break;
				default: throw new Error('no state to advance to!');	
			}
		}	
		
		public function startShowState():void
		{
			state = SHOW_STATE;
			updateStateTimer(SHOW_TIME);
		}		
		
		public function updateStateTimer(stateTime:int):void
		{
			var millisecondsElapsed:int = getUpdatedTimeElapsed() * 1000;
			var millisecondsRemaining:int = (stateTime - millisecondsElapsed);
			
			var counter:Counter = new Counter(millisecondsRemaining);
			counter.addEventListener(CounterEvent.COUNTER_COMPLETE, onCounterComplete);
			counter.displayCounter();
			counter.counterCanvas.x = 400;
			counter.counterCanvas.y = 0;
			counter.counterCanvas.setStyle("fontSize", "20");
			counter.counterCanvas.setStyle("fontFamily", "Museo-Slab-900");
			counter.counterCanvas.setStyle("color", 0xffffff);
			FlexGlobals.topLevelApplication.addChild(counter.counterCanvas);
		}
		
		private function onCounterComplete():void
		{
			updateState();
		}
		
		public function checkForMinimumFancount():Boolean
		{
			if (state == EMPTY_STATE && fancount > dwelling.capacity * VENUE_FILL_FRACTION)
			{
				advanceState(SHOW_WAIT_STATE);
				return true;
			}			
			return false;
		}
		
		public function endShowState():void
		{
			
		}
		
		public function startEncoreState():void
		{
			state = ENCORE_STATE;
			updateStateTimer(ENCORE_TIME);			
		}
		
		public function endEncoreState():void
		{
			
		}
		
		public function startCrowdedState():void
		{
			state = CROWDED_STATE;
		}
		
		public function endCrowdedState():void
		{
			
		}
		
		public function checkForVenueTurnover():void
		{
			if (state == ENCORE_STATE || state == ENCORE_WAIT_STATE)
			{
				_venueManager.dwellingController.serverController.sendRequest({id: id, level: _venueManager.levelController.level}, "owned_dwelling", "change_venue");
			}
		}
		
		public function startEmptyState():void
		{
			checkForVenueTurnover();
			state = EMPTY_STATE;
		}
		
		public function endEmptyState():void
		{
			
		}
		
		private function setEntrance(params:Object=null):void
		{
			mainEntrance = new Point3D(14, 0, 10);
		}
		
		public function updateFanCount(fansToAdd:int, venue:Venue, station:ListeningStation):void
		{
			_venueManager.dwellingController.serverController.sendRequest({id: venue.id, to_add: fansToAdd, owned_structure_id: station.id}, "owned_dwelling", "update_fancount");
		}
		
		public function startEncoreWaitState():void
		{
			state = ENCORE_WAIT_STATE;
		}
		
		public function endEncoreWaitState():void
		{
			
		}
		
		public function startShowWaitState():void
		{
			state = SHOW_WAIT_STATE;
//			displayStartShowButton();
		}
		
		public function displayStartShowButton():void
		{
			var startShowButton:Button = FlexGlobals.topLevelApplication.topBarView.enableStartShowButton();
			startShowButton.addEventListener(MouseEvent.CLICK, onStartShowButtonClicked);
		}
		
		private function onStartShowButtonClicked(evt:MouseEvent):void
		{
			updateStateOnServer(true);
		}
		
		public function endShowWaitState():void
		{
			removeShowButton();
		}
		
		public function removeShowButton():void
		{
			if (FlexGlobals.topLevelApplication.contains(startShowButton))
			{
				FlexGlobals.topLevelApplication.removeChild(startShowButton);
			}
			if (startShowButton)
			{
				startShowButton = null;
			}			
		}
		
		public function set myWorld(val:World):void
		{
			_myWorld = val;
		}
		
		public function set bitmapBlotter(val:BitmapBlotter):void
		{
			_bitmapBlotter = val;
		}
		
		public function get myWorld():World
		{
			return _myWorld;
		}
		
		public function get creatureController():CreatureController
		{
			return _creatureController;
		}
		
		public function set bandMemberManager(val:BandMemberManager):void
		{
			_bandMemberManager = val;
		}
		
		public function get bandMemberManager():BandMemberManager
		{
			return _bandMemberManager;
		}
		
	}
}