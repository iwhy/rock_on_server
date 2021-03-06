package rock_on
{
	import controllers.CreatureController;
	import controllers.DwellingController;
	import controllers.LayerableController;
	import controllers.LevelController;
	import controllers.StructureController;
	import controllers.UsableController;
	import controllers.UserController;
	
	import flash.display.Sprite;
	import flash.events.IEventDispatcher;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.filters.BitmapFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Timer;
	
	import game.Counter;
	import game.CounterEvent;
	import game.GameClock;
	import game.ImposterCreature;
	import game.InventoryEvent;
	
	import helpers.CollectibleDrop;
	import helpers.CreatureGenerator;
	
	import models.Creature;
	import models.OwnedDwelling;
	import models.OwnedSong;
	import models.OwnedStructure;
	import models.Structure;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Button;
	import mx.core.Application;
	import mx.core.FlexGlobals;
	import mx.graphics.BitmapFill;
	
	import server.ServerDataEvent;
	
	import spark.primitives.Rect;
	
	import views.AssetBitmapData;
	import views.BandBoss;
	import views.BouncyBitmap;
	import views.VenueManager;
	import views.WorldBitmapInterface;
	
	import world.ActiveAsset;
	import world.ActiveAssetStack;
	import world.AssetRenderer;
	import world.BitmapBlotter;
	import world.MoodEvent;
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
		public static const CROWD_BUFFER_FRACTION:Number = 0.3;
		
		public var state:int;
		public var friendAvatarsAdded:Boolean;
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
		public var unwalkableRect:Rectangle;
		public var outsideRect:Rectangle;
		
		public var _bandBoss:BandBoss;
		public var _bandMemberManager:BandMemberManager;
		
		public var creatureGenerator:CreatureGenerator;
		public var boothBoss:BoothBoss;
		public var groupieBoss:GroupieBoss;
		public var customerPersonManager:CustomerPersonManager;
		public var listeningStationBoss:ListeningStationBoss;		
		public var stageManager:StageManager;
		public var techManager:TechManager;
		public var haterBoss:HaterBoss;
		public var friendBoss:FriendBoss;
		public var peerBoss:PeerBoss;
		public var decorationBoss:DecorationBoss;
		public var fullyLoaded:Boolean;		

		public var _dwellingController:DwellingController;
		public var _structureController:StructureController;
		public var _creatureController:CreatureController;
		public var _layerableController:LayerableController;
		public var _usableController:UsableController;
		public var _userController:UserController;
		public var _myWorld:World;
		public var _bitmapBlotter:BitmapBlotter;
		
		public var numSuperCustomers:int;
		public var numStaticCustomers:int;
		public var numMovingCustomers:int;
		
		public var stageRects:ArrayCollection;
				
		public function Venue(venueManager:VenueManager, dwellingController:DwellingController, creatureController:CreatureController, layerableController:LayerableController, structureController:StructureController, usableController:UsableController, userController:UserController, bandBoss:BandBoss, params:Object=null, target:IEventDispatcher=null)
		{
			super(params, target);
			
			_layerableController = layerableController;
			_layerableController.addEventListener(ServerDataEvent.FRIEND_AVATARS_LOADED, onFriendAvatarsLoaded);
			
			_structureController = structureController;
			_venueManager = venueManager;
			_dwellingController = dwellingController;
			_creatureController = creatureController;
			_usableController = usableController;
			_userController = userController;
			_bandBoss = bandBoss;
			
			entryPoints = new ArrayCollection();
			setEntrance(params);
			setAdditionalProperties(params);		
			
			addEventListener(VenueEvent.BOOTH_UNSTOCKED, onBoothUnstocked);	
			_structureController.addEventListener(InventoryEvent.ADDED_TO_INVENTORY, onAddedToInventory);	
			_structureController.addEventListener(ServerDataEvent.INSTANCE_CREATED, onNewInstanceCreated);			
			addStageManager();	
		}
		
//		A LIST OF SERVER REQUEST FUNCTIONS
		
		public function doBoothCollection(booth:Booth):void
		{
			
		}
		
		public function doNurture(creature:Creature):void
		{
			
		}
		
		public function doBonusClick(obj:Object):void
		{
			if (obj.amount)
			{
				if (obj.source is OwnedStructure)
					FlexGlobals.topLevelApplication.gdi.sc.sendRequest({id: obj.source.id, user_id: this.user_id, amount: obj.amount, amount_type: obj.amountType}, "owned_structure", obj.action);
				else if (obj.source is Creature)
					FlexGlobals.topLevelApplication.gdi.sc.sendRequest({id: obj.source.id, user_id: this.user_id, amount: obj.amount, amount_type: obj.amountType}, "creature", obj.action);
				_userController.addAmountToUserOnClient(_userController.user, obj.amount, obj.amountType);
				FlexGlobals.topLevelApplication.topBarView.updateTopbarInfo(_userController.user);
			}
			else if (obj.collectible)
			{
				if (obj.source is OwnedStructure)
					FlexGlobals.topLevelApplication.gdi.sc.sendRequest({id: obj.source.id, user_id: this.user_id, collectible: obj.collectible}, "owned_structure", obj.action);
				else if (obj.source is Creature)
					FlexGlobals.topLevelApplication.gdi.sc.sendRequest({id: obj.source.id, user_id: this.user_id, collectible: obj.collectible}, "creature", obj.action);
			}
		}
		
//		END LIST OF SERVER REQUEST FUNCTIONS
		
		public function addStageManager():void
		{
			stageManager = new StageManager(_structureController, this);
			stageManager.initialize();
		}
		
		public function isPointInVenueBounds(pt3D:Point3D):Boolean
		{
			if (pt3D.x > venueRect.right || pt3D.x < venueRect.left || pt3D.z > venueRect.bottom || pt3D.z < venueRect.top)
				return false;
			return true;
		}
		
		public function isPointInRect(pt3D:Point3D, rect:Rectangle):Boolean
		{
			if (pt3D.x < rect.right && pt3D.x > rect.left && pt3D.z < rect.bottom && pt3D.z > rect.top)
				return true;
			return false;
		}
		
		public function isPointInStageRect(pt3D:Point3D):Boolean
		{
			if (pt3D.x < stageRect.right && pt3D.z > stageRect.top)
				return true;
			return false;
		}
		
		public function pickRandomAvailablePointWithinRect(rect:Rectangle, worldSprite:World, heightBase:int, rect2:Rectangle = null, avoidStructures:Boolean = true, avoidPeople:Boolean = true, exemptStructures:ArrayCollection = null):Point3D
		{
			var pt3D:Point3D = new Point3D(0, heightBase, 0);				
			var occupiedSpaces:Array = worldSprite.pathFinder.updateOccupiedSpaces(avoidPeople, avoidStructures, exemptStructures);
			do
			{
				pt3D.x = Math.floor(rect.right - Math.random() * (rect.right - rect.left - 1) - 1);
				pt3D.z = Math.floor(rect.bottom - Math.random() * (rect.bottom - rect.top - 1) - 1);
				if (rect2)
				{
					if (Math.random() < 0.5)
					{
						pt3D.x = Math.floor(rect2.right - Math.random() * (rect2.right - rect2.left - 1) - 1);
						pt3D.z = Math.floor(rect2.bottom - Math.random() * (rect2.bottom - rect2.top - 1) - 1);						
					}
				}
			}
			while (occupiedSpaces[pt3D.x] && occupiedSpaces[pt3D.x][pt3D.y] && occupiedSpaces[pt3D.x][pt3D.y][pt3D.z]);	
			return pt3D;
		}
		
		public function setLayout():void
		{
			venueRect = new Rectangle(0, 0, this.dwelling.dimension, _myWorld.tilesDeep);
			boothsRect = new Rectangle(0, 0, this.dwelling.dimension, Math.round(_myWorld.tilesDeep * BOOTH_SECTION_FRACTION))
			stageBufferRect = new Rectangle(0, (_myWorld.tilesDeep - stageManager.concertStage.structure.depth - STAGE_BUFFER_SQUARES), stageManager.concertStage.structure.width + STAGE_BUFFER_SQUARES, stageManager.concertStage.structure.depth + STAGE_BUFFER_SQUARES);	
			stageRect = new Rectangle(0, (_myWorld.tilesDeep - stageManager.concertStage.structure.depth), stageManager.concertStage.structure.width, stageManager.concertStage.structure.depth);	
			audienceRect = new Rectangle(0, boothsRect.bottom, venueRect.width, venueRect.height - boothsRect.height - 1);
			
			assignedSeats = _myWorld.pathFinder.createSeatingArrangement(audienceRect, stageBufferRect, this.dwelling.capacity);
			
			crowdBufferRect = new Rectangle(stageRect.width + stageBufferRect.top - audienceRect.top - 2, boothsRect.bottom, venueRect.right - (stageRect.width + stageBufferRect.top - audienceRect.top - 2), venueRect.height - boothsRect.height);
			mainCrowdRect = new Rectangle(0, boothsRect.bottom, crowdBufferRect.left, venueRect.bottom - boothsRect.bottom);
			unwalkableRect = new Rectangle(0, boothsRect.bottom, mainCrowdRect.right, (stageBufferRect.bottom - boothsRect.bottom));
			outsideRect = new Rectangle(venueRect.right, 0, this.dwelling.sidewalk_dimension, venueRect.height);
			
			stageRects = new ArrayCollection();
			stageRects.addItem(stageBufferRect);
		}
		
		public function clearFilters():void
		{
			var sprite:ActiveAsset;
			for each (sprite in _myWorld.assetRenderer.unsortedAssets)
			{
				if (!sprite.doNotClearFilters)
					clearSpriteFilters(sprite);
			}
			for each (sprite in stageManager.myStage.assetRenderer.unsortedAssets)
			{
				if (!sprite.doNotClearFilters)
					clearSpriteFilters(sprite);			
			}
			clearUIFilters();
		}
		
		public function clearSpriteFilters(sprite:ActiveAsset):void
		{
			sprite.filters = sprite.unclearableFilters;
		}
		
		private function clearUIFilters():void
		{
			for (var i:int = 0; i < _myWorld.numChildren; i++)
			{
				if (_myWorld.getChildAt(i) is CollectibleDrop)
					(_myWorld.getChildAt(i) as Sprite).filters = null;
			}
		}	
			
		public function onBoothUnstocked(evt:VenueEvent):void
		{
			customerPersonManager.removeBoothFromAvailable(evt.booth);
		}	
		
		public function update(deltaTime:Number):void
		{
			if (customerPersonManager)
				customerPersonManager.update(deltaTime);			
			if (listeningStationBoss)
				listeningStationBoss.passerbyManager.update(deltaTime);							
		}
		
		public function addStaticStuffToVenue():void
		{
			setLayout();
			updateState();				
			createInventory();
			
			stageManager.myWorld = _myWorld;
			customerPersonManager = new CustomerPersonManager(_myWorld, this);
			boothBoss = new BoothBoss(_structureController, _myWorld, this);
			decorationBoss = new DecorationBoss(_structureController, _myWorld, this);
			listeningStationBoss = new ListeningStationBoss(_structureController, _layerableController, stageManager, _myWorld, this, boothBoss, customerPersonManager);

			boothBoss.initialize();
			listeningStationBoss.initialize();
			decorationBoss.initialize();
			
			_myWorld.setOccupiedSpaces();
			
			var extra:ArrayCollection = new ArrayCollection();
			extra.addItem(this.stageBufferRect);
			_myWorld.addOccupiedRectangles(extra);
		}	
		
		public function addMovingStuffToVenue():void
		{
			creatureGenerator = new CreatureGenerator(_layerableController);
			var fans:ArrayCollection = getFans();
			updateAudienceNumbers();
			groupieBoss = new GroupieBoss(customerPersonManager, boothBoss, stageManager.concertStage, _creatureController, _myWorld, this);

			listeningStationBoss.addStaticStationListeners();
			listeningStationBoss.showPassersby();
			
			_creatureController.makeSureOwnedLayerablesAreAssignedToCreatures();
			
			addStaticCustomersToVenue(fans);
//			addSuperCustomersToVenue(stageManager.myStage);
			addMovingCustomersToVenue(fans);
			groupieBoss.setInMotion();
			addTechsToVenue();
			addHatersToVenue();
			addSpecialPeopleToVenue();
			showBandMembersRaceCondition();	
			
			customerPersonManager.startQueueTimersForCustomers();
		}	
		
		public function getFans():ArrayCollection
		{
			var fans:ArrayCollection = _creatureController.getFans();
			this.fancount = fans.length;
			for each (var c:Creature in fans)
			{
				creatureGenerator.gameOwnedCreaturesInUse.addItem(c);
			}
			return fans;
		}
		
		public function updateAudienceNumbers():void
		{
			numStaticCustomers = Math.floor(fancount * VenueManager.STATIC_CUSTOMER_FRACTION);
			numSuperCustomers = Math.ceil(fancount * VenueManager.SUPER_CUSTOMER_FRACTION);
			numMovingCustomers = fancount - numStaticCustomers;	
					
//			getNumberOfBitmaps();			
		}
		
		public function showBandMembersRaceCondition():void
		{
			if (fullyLoaded)
			{
				_bandBoss.showBandMembers();
				trace("band members loaded");
			}
			else
				fullyLoaded = true;
		}		
		
		public function setAdditionalProperties(params:Object):void
		{
			if (params['dwelling'])
				dwelling = params.dwelling;
		}
		
		private function getNumberOfBitmaps():void
		{
			_bitmapBlotter.expectedAssetCount = numStaticCustomers;				
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
		
		public function addStaticCustomersToVenue(fans:ArrayCollection):void
		{
			if (!customerPersonManager.concertStage)
				customerPersonManager.concertStage = stageManager.concertStage;
			trace("number of static customers:" + numStaticCustomers.toString());
			for (var i:int = 0; i < numStaticCustomers; i++)
			{
				var c:Creature = fans[i] as Creature;
				if (c.owned_layerables.length == 0)
					creatureGenerator.addLayersToCreatureByType(c.type, "walk_toward", c);				
				c.has_moods = true;
				var match:Creature = _creatureController.getFanMatch(c.id);
				var cp:CustomerPerson = customerPersonManager.createStaticCustomer(c, match, i);
				cp.advanceState(CustomerPerson.ENTHRALLED_STATE);
				cp.setMood();
			}
		}
		
		public function addSuperCustomersToVenue(worldToUpdate:World):void
		{
			if (!customerPersonManager.concertStage)
				customerPersonManager.concertStage = stageManager.concertStage;
			for (var i:int = 0; i < numSuperCustomers; i++)
			{
				var imposter:ImposterCreature = creatureGenerator.createImposterCreature("Fan");
				customerPersonManager.createSuperCustomer(imposter, worldToUpdate);
			}					
		}
		
		public function addTechsToVenue():void
		{
			techManager = new TechManager(this, _myWorld);
			var techs:ArrayCollection = _creatureController.getConstructedCreaturesByType("Tech");
			techManager.techCreatures = techs;
			initializeTechs();
		}
		
		public function initializeTechs():void
		{			
			for each (var c:Creature in techManager.techCreatures)
			{
				var tech:Tech = new Tech(c, null, c.layerableOrder, 0.5);
				tech.personType = Person.MOVING;
				tech.thinger = c;
				tech.speed = 0.11;
				techManager.add(tech);
			}
		}
		
		public function addHatersToVenue():void
		{
			haterBoss = new HaterBoss(this, _myWorld);
			var haters:ArrayCollection = _creatureController.getConstructedCreaturesByType("Hater");
			haterBoss.haterCreatures = haters;
			initializeHaters();
		}
		
		public function initializeHaters():void
		{
			for each (var c:Creature in haterBoss.haterCreatures)
			{
				var hater:Hater = new Hater(this, c, null, c.layerableOrder, 0.5);
				hater.personType = Person.MOVING;
				hater.thinger = c;
				hater.speed = 0.11;
				haterBoss.add(hater);
			}			
		}
		
		public function addSpecialPeopleToVenue():void
		{
			peerBoss = new PeerBoss(this);
			var peers:ArrayCollection = _creatureController.getPeers(-1);
			peerBoss.peerCreatures = peers;
			initializeSpecialPeople();
		}
		
		public function initializeSpecialPeople():void
		{
			for each (var c:Creature in peerBoss.peerCreatures)
			{
				var peer:Peer = new Peer(this, c, null, c.layerableOrder, 0.5);
				peer.thinger = c;
				peer.personType = Person.MOVING;
				peer.speed = 0.11;
				peerBoss.add(peer);
			}			
		}
		
		private function onFriendAvatarsLoaded(evt:ServerDataEvent):void
		{
			if (!friendAvatarsAdded)
				addFriendsToVenue();			
		}
		
		public function addFriendsToVenue():void
		{
			friendAvatarsAdded = true;
			friendBoss = new FriendBoss(this, _myWorld);
			var friends:ArrayCollection = _creatureController.getConstructedCreaturesByType("Friend");
			friendBoss.friendCreatures = friends;
			initializeFriends();
		}
		
		public function initializeFriends():void
		{
			for each (var c:Creature in friendBoss.friendCreatures)
			{
				var friend:Friend = new Friend(this, c, null, c.layerableOrder, 0.5);
				friend.personType = Person.MOVING;
				friend.thinger = c;
				friend.speed = 0.11;
				friendBoss.add(friend);
			}
			for (var i:int = 0; i < _creatureController.friend_creatures.length; i++)
			{
				var realFriend:Friend = new Friend(this, _creatureController.friend_creatures[i] as Creature, null, (_creatureController.friend_creatures[i] as Creature).layerableOrder, 0.5);
				realFriend.personType = Person.MOVING;
				realFriend.speed = 0.11;
				friendBoss.add(realFriend);
			}			
		}
				
		public function addMovingCustomersToVenue(fans:ArrayCollection):void
		{
			if (!customerPersonManager.concertStage)
				customerPersonManager.concertStage = stageManager.concertStage;
			customerPersonManager.customerCreatures = new ArrayCollection();
			for (var i:int = 0; i < numMovingCustomers; i++)
			{
//				var c:ImposterCreature = creatureGenerator.createImposterCreature("Fan");
				var c:Creature = fans[numStaticCustomers + i] as Creature;
				if (c.owned_layerables.length == 0)
					creatureGenerator.addLayersToCreatureByType(c.type, "walk_toward", c);						
				c.has_moods = true;
				customerPersonManager.customerCreatures.addItem(c);
			}			
			initializeCustomers();
		}
		
		public function initializeCustomers():void
		{
			for each (var c:Creature in customerPersonManager.customerCreatures)
			{	
				var cp:CustomerPerson = customerPersonManager.createMovingCustomer(c);	
				cp.advanceState(CustomerPerson.TEMPORARY_ENTHRALLED_STATE);
				cp.setMood();
			}
		}
		
		public function redrawAllMovers():void
		{
			peerBoss.removePeers();
			haterBoss.removeHaters();
			friendBoss.removeFriends();
			customerPersonManager.removeMovingCustomers();
			techManager.removeTechs();
			
			initializeCustomers();
			initializeHaters();
			initializeSpecialPeople();
			initializeFriends();
			initializeTechs();
		}		
		
		public function redrawAllBandMembers():void
		{
			bandMemberManager.removeBandMembers();
			bandMemberManager.initializeBandMembers();
		}
		
		public function removeCustomersFromVenue():void
		{
			for each (var cp:CustomerPerson in customerPersonManager)
			{
				customerPersonManager.remove(cp);
			}
		}	
		
		public function updateRenderedStructures(os:OwnedStructure, method:String):void
		{
			if (os.structure.structure_type == "Tile")
				this.stageManager.updateRenderedTiles(os, method);
			else if (os.structure.structure_type == "StructureTopper")
				this.decorationBoss.updateRenderedDecorations(os, method);	
			else if (os.structure.structure_type == "Decoration")
			{
				updateStructureDerivatives(os, decorationBoss.decorations);
				this.decorationBoss.updateRenderedDecorations(os, method);
			}
			else if (os.structure.structure_type == "StageDecoration")
			{
				updateStructureDerivatives(os, stageManager.stageDecorations);
				this.stageManager.updateRenderedStageDecorations(os, method);				
			}
			else if (os.structure.structure_type == "Booth")
			{
				updateStructureDerivatives(os, boothBoss.booths);				
				this.boothBoss.updateRenderedBooths(os, method);
			}
			else if (os.structure.structure_type == "ListeningStation")
			{
				updateStructureDerivatives(os, listeningStationBoss.listeningStations);				
				this.listeningStationBoss.updateRenderedStations(os, method);
			}
			else
				throw new Error("No re-rendering handler for structure type");
		}
		
		public function updateStructureDerivatives(os:OwnedStructure, collection:ArrayCollection):void
		{
//			Updates properties of any new instances originally created from the owned structure (e.g. booths, listening stations, etc)
			
			for each (var derivative:OwnedStructure in collection)
			{
				if (derivative.id == os.id)
					derivative.updateProperties(os);
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
				_venueManager.dwellingController.serverController.sendRequest({id: id, level: _venueManager.levelController.level}, "owned_dwelling", "change_venue");
		}
		
		public function startEmptyState():void
		{
			checkForVenueTurnover();
			state = EMPTY_STATE;
		}
		
		public function endEmptyState():void
		{
			
		}
		
		private function setEntrance(params:Object):void
		{
			mainEntrance = new Point3D(params.dwelling.dimension, 0, params.dwelling.dimension - 10);
		}
		
		public function updateFanCount(newFans:ArrayCollection, venue:Venue, station:ListeningStation):void
		{
			_venueManager.dwellingController.serverController.sendRequest({id: venue.id, owned_structure_id: station.id}, "owned_dwelling", "update_fancount");
			for each (var c:Creature in newFans)
			{
				creatureController.serverController.sendRequest({user_id: this.user_id, creature_type: "Fan", reference_id: c.id}, "creature", "add_new");			
			}
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
		
		private function createInventory():void
		{
			FlexGlobals.topLevelApplication.bottomBarView.createInventoryList();
		}
		
		public function removeShowButton():void
		{
			if (FlexGlobals.topLevelApplication.contains(startShowButton))
				FlexGlobals.topLevelApplication.removeChild(startShowButton);
			if (startShowButton)
				startShowButton = null;
		}
		
		private function onAddedToInventory(evt:InventoryEvent):void
		{
			if (evt.item is OwnedStructure)
			{
				var os:OwnedStructure = evt.item as OwnedStructure;
				var asset:ActiveAsset = _myWorld.getAssetFromOwnedStructure(os);
				if (!asset && os.structure.structure_type == "StructureTopper")
				{
					asset = _myWorld.getParentAssetFromTopper(os);
					if (asset)
						asset.toppers = _structureController.getStructureToppers(asset.thinger as OwnedStructure);
						_myWorld.doAssetRedraw(asset);
				}
				else if (asset)
					_myWorld.removeAsset(asset);
				else
					throw new Error("failed to find asset");
			}
		}		
		
		public function convertStationListenerToCustomer(sl:StationListener, fanIndex:int):void
		{
			customerPersonManager.addConvertedCustomer(sl.creature, sl.worldCoords, fanIndex);
		}	
		
		public function redrawAllStructures():void
		{
			var assetTotal:int = myWorld.assetRenderer.unsortedAssets.length;
			var toRedraw:ArrayCollection = new ArrayCollection();
			for (var i:int = 0; i < assetTotal; i++)
			{
				var asset:ActiveAsset = myWorld.assetRenderer.unsortedAssets.getItemAt(i) as ActiveAsset;
				if (asset.thinger is OwnedStructure)
				{
					asset.toppers = _structureController.getStructureToppers(asset.thinger as OwnedStructure);
					toRedraw.addItem(asset);
				}
			}	
			for each (var a:ActiveAsset in toRedraw)
			{
				doStructureRedraw(a);										
			}
		}		
		
		public function doStructureRedraw(asset:ActiveAsset):void
		{
//			Determines parent world for structure to redraw
			var parentWorld:World;
			var os:OwnedStructure = asset.thinger as OwnedStructure;
			if (os.structure.structure_type == "StageDecoration" || os.structure.structure_type == "Tile" || os.structure.structure_type == "ConcertStage")
				parentWorld = this.stageManager.myStage;
			else
				parentWorld = _myWorld;
			redrawStructureInParentWorld(asset, parentWorld);
		}
		
		public function redrawStructureInParentWorld(asset:ActiveAsset, parentWorld:World):void
		{	
//			Redraws structure in main view parent world
			var realAsset:ActiveAsset = parentWorld.getAssetFromOwnedStructure(asset.thinger as OwnedStructure);		
			parentWorld.removeAsset(realAsset);
			var temp:ActiveAssetStack = new ActiveAssetStack(null, asset.movieClip);
			temp.copyFromActiveAsset(asset);
			temp.setMovieClipsForStructure(temp.toppers);
			temp.bitmapWithToppers();
			parentWorld.addAsset(temp, temp.worldCoords);	
//			Assumes that the stage is unwalkable
			parentWorld.updateUnwalkables(temp.thinger as OwnedStructure, null, this.stageRects);
		}		
		
		public function startPostSongExit():void
		{
//			convertStaticToMoving();
			customerPersonManager.initializeStaggeredExit(3);
			customerPersonManager.startStaggeredExit();
			numStaticCustomers -= 3;
		}
		
		public function replaceExitedCustomers():void
		{
			customerPersonManager.initializeExitReplacements(this.numStaticCustomers, 3);
			customerPersonManager.replaceExitedCustomers();
		}
		
		public function reRenderBitmap():void
		{
			_bitmapBlotter.renderInitialBitmap();
		}
		
		public function updateBitmapProperties(asset:ActiveAsset):void
		{
			var abd:AssetBitmapData = _bitmapBlotter.getMatchFromBitmapReferences(asset);
			abd.realCoordX = asset.realCoordX;
			abd.realCoordY = asset.realCoordY;
			abd.reflected = asset.flipped;
		}
		
		public function getOpenSpot(rect:Rectangle, extra:ArrayCollection=null):Point3D
		{
			var pt:Point3D = new Point3D(rect.left + Math.round(Math.random()*rect.width), 0, rect.top + Math.round(Math.random()*rect.height));
			var occupiedSpaces:Array = _myWorld.pathFinder.updateOccupiedSpaces(true, true, null, extra);	
			while (occupiedSpaces[pt.x] && occupiedSpaces[pt.x][pt.y] && occupiedSpaces[pt.x][pt.y][pt.z])
			{
				pt = new Point3D(rect.left + Math.round(Math.random()*rect.width), 0, rect.top + Math.round(Math.random()*rect.height));
			}
			return pt;
		}
		
		public function getOpenSeat(rect:Rectangle, extra:ArrayCollection=null):Point3D
		{
			var occupiedSpaces:Array = _myWorld.pathFinder.updateOccupiedSpaces(true, true, null, extra);
			for each (var pt:Point3D in assignedSeats)
			{
				if (!(occupiedSpaces[pt.x] && occupiedSpaces[pt.x][pt.y] && occupiedSpaces[pt.x][pt.y][pt.z]))
					return pt;
			}
			return getOpenSpot(rect, extra);
		}
		
		private function onNewInstanceCreated(evt:ServerDataEvent):void
		{
			if (evt.params)
			{
				myWorld.onNewInstanceCreated(evt.params);
				stageManager.myStage.onNewInstanceCreated(evt.params);
			}
		}
		
		public function removeAssetFromBitmap(asset:ActiveAsset):void
		{
			_bitmapBlotter.removeBitmapFromReferences(asset);
		}
				
		public function removeMoodClipFromBitmappedAsset(asset:ActiveAsset):BouncyBitmap
		{
			var clip:BouncyBitmap = _bitmapBlotter.removeMoodClipFromBitmap(asset);
			return clip;
		}
		
		public function set myWorld(val:World):void
		{
			_myWorld = val;
		}
		
		public function getWorldFloorStructure():Structure
		{
			for each (var s:Structure in _structureController.structures)
			{
				if (s.id == this.dwelling.floor_structure_id)
					return s;
			}
			return null;
		}
		
		public function getWorldFloorStyle():String
		{
			return this.dwelling.floor_type;			
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
		
		public function set bandBoss(val:BandBoss):void
		{
			_bandBoss = val;
		}
		
		public function get usableController():UsableController
		{
			return _usableController;
		}
		
		public function get structureController():StructureController
		{
			return _structureController;
		}
		
	}
}