package rock_on
{
	import adobe.utils.CustomActions;
	
	import clickhandlers.UIBoss;
	
	import controllers.UsableController;
	
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Timer;
	
	import game.GameClock;
	import game.MoodBoss;
	
	import helpers.CollectibleDrop;
	
	import models.Creature;
	import models.EssentialModelReference;
	import models.OwnedStructure;
	import models.Usable;
	
	import mx.collections.ArrayCollection;
	import mx.containers.Canvas;
	import mx.containers.HBox;
	import mx.controls.Text;
	import mx.core.FlexGlobals;
	import mx.core.UIComponent;
	import mx.events.DynamicEvent;
	
	import views.AssetBitmapData;
	import views.ExpandingMovieclip;
	import views.HoverTextBox;
	import views.WorldBitmapInterface;
	import views.WorldView;
	
	import world.Point3D;
	import world.World;
	import world.WorldEvent;

	public class CustomerPerson extends Person
	{
		public static const INITIALIZED_STATE:int = 0;
		public static const ENTHRALLED_STATE:int = 1;
		public static const ROAM_STATE:int = 2;
		public static const ROUTE_STATE:int = 3;
		public static const QUEUED_STATE:int = 4;
		public static const GONE_STATE:int = 5;
		public static const HEADTOSTAGE_STATE:int = 6;
		public static const HEADTODOOR_STATE:int = 7;
		public static const BITMAPPED_ENTHRALLED_STATE:int = 8;
		public static const ITEM_PICKUP_STATE:int = 9;
		public static const HEAD_BOB_STATE:int = 10;
		public static const EXIT_STATE:int = 11;
		public static const DIRECTED_STATE:int = 12;
		public static const TEMPORARY_ENTHRALLED_STATE:int = 13;

		public static const HUNGER_DELAY:int = 360000;
		public static const HUNGRY:String = "Hungry";
		public static const THIRSTY:String = "Thirsty";
		public static const MAX_DROPS_END_MOOD:int = 3;
		
		public static const TEMPORARY_ENTHRALLED_TIME:int = 20000 + 40000 * Math.random();
		public static const QUEUED_TIME:int = 4000;
		public static const FAN_CONVERSION_DELAY:int = 2000;
		public static const MUSIC_DELAY:int = 2000000 + 1000000 * Math.random();
		public static var ENTHRALLED_TIME:int;
				
		public var temporaryEnthralledTimer:Timer;
		public var enthralledTimer:Timer;
		public var queuedTimer:Timer;
		
		public var numQueuedTimers:int = 0;
		public var numEnthralledTimers:int = 0;
		
		public var state:int;
		public var currentBooth:BoothAsset;
		public var currentBoothPosition:int;
		public var activityTimer:Timer;
		public var isSuperFan:Boolean;
		public var seatNumber:int;
		public var _boothBoss:BoothBoss;
		public var _venue:Venue;
		
		public var itemPickupAnimations:Array;
		public var pickupBooth:BoothAsset;
		public var proxiedForItemPickup:Boolean;
		
		private var customerAnimations:Object = {
			head_bob_away: 						{"body": "head_bob_away", "shoes": "stand_still_away", "bottom": "stand_still_away", "bottom custom": "stand_still_away", "top": "stand_still_away", "top custom": "stand_still_away", "hair front": "head_bob_away", "hair band": "head_bob_away"}
		}
		
		public function CustomerPerson(boothBoss:BoothBoss, creature:Creature, movieClip:MovieClip=null, layerableOrder:Array=null, scale:Number=1)
		{
			super(creature, movieClip, layerableOrder, scale);

			_boothBoss = boothBoss;
			startInitializedState();
			addEventListener(MouseEvent.CLICK, onMouseClicked);
			addEventListener(WorldEvent.PATHFINDING_FAILED, onPathfindingFailed);			
		}
		
		public function initializeForQueueing():void
		{
			var tempTimer:Timer = new Timer(ENTHRALLED_TIME * Math.random());
			tempTimer.addEventListener(TimerEvent.TIMER, initializeEnthralledTimer);
			tempTimer.start();
		}
		
		private function initializeEnthralledTimer(evt:TimerEvent):void
		{
//			Routes person for the first time, then sets enthralled timer for the first time
			var tempTimer:Timer = evt.currentTarget as Timer;	
			tempTimer.stop();
			tempTimer.removeEventListener(TimerEvent.TIMER, initializeEnthralledTimer);
			tempTimer = null;
			if (Math.random() < 0.5)
				advanceState(ROUTE_STATE);
			resetEnthralledTimer();
		}
		
		private function onPathfindingFailed(evt:WorldEvent):void
		{
			advanceState(CustomerPerson.TEMPORARY_ENTHRALLED_STATE);
		}
		
		public function reInitialize():void
		{
			if (temporaryEnthralledTimer)
			{
				temporaryEnthralledTimer.stop();
				temporaryEnthralledTimer = null;
			}
			if (enthralledTimer)
			{
				enthralledTimer.stop();
				enthralledTimer = null;
			}
			if (activityTimer)
			{
				activityTimer.stop();
				activityTimer = null;
			}
			if (queuedTimer)
			{
				queuedTimer.stop();
				queuedTimer = null;
			}
			currentBooth = null;
		}
		
		public function setMood():void
		{
			if (_creature.has_moods)
			{
				if (_creature.last_nurture)
				{
					var timeSinceLastMeal:Number = new Date().getTime() - GameClock.convertStringTimeToUnixTime(_creature.last_nurture);				
					if (timeSinceLastMeal > CustomerPerson.HUNGER_DELAY)
						mood = MoodBoss.assignMoodByString(CustomerPerson.HUNGRY);
				}
				else
					mood = MoodBoss.assignMoodByCreatureAndPersonType(_creature.type, personType, FlexGlobals.topLevelApplication.gdi.user.level.rank);
				
				if (mood)
					startMood(mood);				
			}
		}	
		
		private function onMouseClicked(evt:MouseEvent):void
		{			
			if (mood && !proxiedForItemPickup && personType == Person.MOVING)
				handleMood(mood);
		}
				
		public function handleMood(mood:Object):void
		{
			trace("mood: " + mood.toString());
			itemPickupAnimations = mood.animation;			
			
			if (mood.move_to)
			{
				proxiedForItemPickup = true;				
				transitionToItemPickup(mood);
			}
			else if (mood.animation)
				doMultipleAnimations(itemPickupAnimations);
		}
		
		public function transitionToItemPickup(mood:Object):void
		{
			if (state == CustomerPerson.QUEUED_STATE)
			{
				if (queuedTimer)
				{
					refreshQueuedTimer();	
					doItemPickup();
				}
				pickupBooth = currentBooth;
			}
			else if (state == CustomerPerson.ROUTE_STATE)
				pickupBooth = currentBooth;
			else
				advanceState(CustomerPerson.ROUTE_STATE);
		}
		
		public function updateMood(deltaTime:Number):void
		{
			if (creature.has_moods)
			{

			}				
		}
		
		public function update(deltaTime:Number):Boolean
		{
//			updateMood(deltaTime);
			
			switch (state)
			{
				case INITIALIZED_STATE:
					doInitializedState(deltaTime);
					break;
				case ROAM_STATE:
					doRoamState(deltaTime);
					break;
				case ENTHRALLED_STATE:
					doEnthralledState(deltaTime);
					break;	
				case TEMPORARY_ENTHRALLED_STATE:
					break;
				case BITMAPPED_ENTHRALLED_STATE:
					doBitmappedEnthralledState(deltaTime);
					break;
				case QUEUED_STATE:
					doQueuedState(deltaTime);
					break;
				case ROUTE_STATE:
					doRouteState(deltaTime);	
					break;
				case HEADTOSTAGE_STATE:
					doHeadToStageState(deltaTime);	
					break;
				case HEADTODOOR_STATE:
					doHeadToDoorState(deltaTime);	
					break;
				case HEAD_BOB_STATE:
					break;
				case DIRECTED_STATE:
					break;
				case EXIT_STATE:
					break;
				case GONE_STATE:
					doGoneState(deltaTime);
					return true;
				default: throw new Error('oh noes!');
			}		
			return false;
		}
		
		public function advanceState(destinationState:int):void
		{
			switch (state)
			{	
				case INITIALIZED_STATE:
					endInitializedState();
					break;
				case ROAM_STATE:
					endRoamState();
					break;
				case ENTHRALLED_STATE:
					endEnthralledState();				
					break;	
				case TEMPORARY_ENTHRALLED_STATE:
					endTemporaryEnthralledState();
					break;
				case BITMAPPED_ENTHRALLED_STATE:
					endBitmappedEnthralledState();
					break;
				case ROUTE_STATE:
					endRouteState();
					break;	
				case QUEUED_STATE:
					endQueuedState();
					break;	
				case HEADTOSTAGE_STATE:
					endHeadToStageState();
					break;	
				case HEADTODOOR_STATE:
					endHeadToStageState();
					break;	
				case HEAD_BOB_STATE:
					endHeadBobState();
					break;
				case DIRECTED_STATE:
					endDirectedState();
					break;
				case EXIT_STATE:
					endExitState();
					break;
				case GONE_STATE:
					break;					
				default: throw new Error('no state to advance from!');
			}
			switch (destinationState)
			{
				case ROAM_STATE:
					startRoamState();
					break;
				case ENTHRALLED_STATE:
					startEnthralledState();
					break;
				case TEMPORARY_ENTHRALLED_STATE:
					startTemporaryEnthralledState();
					break;
				case BITMAPPED_ENTHRALLED_STATE:
					startBitmappedEnthralledState();
					break;
				case QUEUED_STATE:
					startQueuedState();
					break;
				case ROUTE_STATE:
					startRouteState();
					break;
				case HEADTOSTAGE_STATE:
					startHeadToStageState();
					break;					
				case HEADTODOOR_STATE:
					startHeadToDoorState();
					break;	
				case HEAD_BOB_STATE:
					startHeadBobState();
					break;
				case DIRECTED_STATE:
					startDirectedState();
					break;
				case EXIT_STATE:
					startExitState();
					break;
				case GONE_STATE:
					startGoneState();
					break;	
				default: throw new Error('no state to advance to!');	
			}
		}	
		
		public function startInitializedState():void
		{
			state = INITIALIZED_STATE;
		}
		
		override public function generateMoodMessage():HoverTextBox
		{
			if (mood)
			{		
				var hoverBox:HoverTextBox = new HoverTextBox(mood.message as String);
				return hoverBox;		
			}
			return null;
		}		
				
		public function doInitializedState(deltaTime:Number):void
		{
			
		}
		
		public function endInitializedState():void
		{
			
		}
		
		public function startRoamState():void
		{
			state = ROAM_STATE;
			personType = Person.MOVING;
			
			var destination:Point3D = pickPointNearStructure(_venue.boothsRect);
			
//			Move person somewhere in valid rect space (not outside, not into stage)
			var extra:ArrayCollection = new ArrayCollection();
			extra.addItem(_venue.outsideRect);
			movePerson(destination, true, true, false, null, 0, extra);
			trace("customer person roamed");
		}
		
		public function timedConversion(fanIndex:int):void
		{
			var convertTimer:Timer = new Timer(fanIndex * FAN_CONVERSION_DELAY);
			convertTimer.addEventListener(TimerEvent.TIMER, onConversionComplete);
			convertTimer.start();
		}	
		
		private function onConversionComplete(evt:TimerEvent):void
		{
			trace("conversion timer complete");
			var convertTimer:Timer = evt.currentTarget as Timer;
			convertTimer.removeEventListener(TimerEvent.TIMER, onConversionComplete);
			convertTimer.stop();
			
			advanceState(HEADTODOOR_STATE);
		}
		
		public function endBitmappedEnthralledState():void
		{
			
		}
		
		public function doBitmappedEnthralledState(deltaTime:Number):void
		{
			
		}
		
		public function startHeadBobState():void
		{
			state = HEAD_BOB_STATE;
			doComplexAnimation("head_bob_away", this.customerAnimations["head_bob_away"]);
			var relationship:Array = getHorizontalAndVerticalRelationship(_stageManager.concertStage.getCornerMatrix());						
			if (getReflection(relationship))
				flipMovieClips();
		}
		
		public function startDirectedState():void
		{
			state = DIRECTED_STATE;
			this.speed = 0.12;
			var extra:ArrayCollection = new ArrayCollection();
			extra.addItem(_venue.stageBufferRect);
			extra.addItem(_venue.outsideRect);
			movePerson(this.worldDestination, true, true, false, null, 0, extra);
		}
		
		public function endHeadBobState():void
		{
			
		}
		
		public function startHeadToDoorState():void
		{
			state = HEADTODOOR_STATE;
			var door:Point3D = _venue.mainEntrance;
			movePerson(door, true);
		}
		
		public function startExitState():void
		{
			state = EXIT_STATE;
			this.speed = 0.13;
			
			var extra:ArrayCollection = new ArrayCollection();
			extra.addItem(_venue.outsideRect);
			movePerson(new Point3D(_venue.mainEntrance.x, _venue.mainEntrance.y, _venue.mainEntrance.z), true);
		}
		
		public function startGoneState():void
		{
//			_venue.removeAssetFromBitmap(this);
		}
		
		public function doGoneState(deltaTime:Number):void
		{
			
		}
		
		public function endGoneState():void
		{
			
		}
		
		public function endHeadToDoorState():void
		{
			
		}
		
		public function endExitState():void
		{
			
		}
		
		public function endDirectedState():void
		{

		}
		
		public function doHeadToDoorState(deltaTime:Number):void
		{
			
		}
		
		public function endRoamState():void
		{
			
		}
		
		public function doRoamState(deltaTime:Number):void
		{
			
		}
		
		public function startEnthralledState():void
		{
			state = ENTHRALLED_STATE;			
			var obj:Object = standFacingObject(_stageManager.concertStage, 1);
		}
		
		public function startTemporaryEnthralledState():void
		{
			state = TEMPORARY_ENTHRALLED_STATE;			
			var obj:Object = standFacingObject(_stageManager.concertStage, 1);
			
			temporaryEnthralledTimer = new Timer(CustomerPerson.TEMPORARY_ENTHRALLED_TIME);
//			temporaryEnthralledTimer.addEventListener(TimerEvent.TIMER, routeToQueue);
			temporaryEnthralledTimer.addEventListener(TimerEvent.TIMER, roam);
			temporaryEnthralledTimer.start();
//			numEnthralledTimers++;				
		}
		
		public function startBitmappedEnthralledState():void
		{
			state = BITMAPPED_ENTHRALLED_STATE;
			
			var frameNumber:int = 1;
			var obj:Object = standFacingObject(this._venue.stageManager.concertStage, frameNumber);
			_world.removeAssetFromWorld(this);
			_world.bitmapBlotter.addRenderedBitmap(this, obj.animation, obj.frameNumber, obj.reflection);
		}
		
		private function resetEnthralledTimer():void
		{
			if (Math.random() < 0.5)
				enthralledTimer = new Timer(ENTHRALLED_TIME + ENTHRALLED_TIME/2 * Math.random());
			else
				enthralledTimer = new Timer(ENTHRALLED_TIME - ENTHRALLED_TIME/2 * Math.random());
			enthralledTimer.addEventListener(TimerEvent.TIMER, routeToQueue);
			enthralledTimer.start();
		}
		
		private function routeToQueue(evt:TimerEvent):void
		{
//			Condition this somehow
			trace("route to queue");
			if (Math.random() < 0.5)
			{
				enthralledTimer.stop();
				enthralledTimer.removeEventListener(TimerEvent.TIMER, routeToQueue);
				numEnthralledTimers--;
				if (state == ENTHRALLED_STATE || state == TEMPORARY_ENTHRALLED_STATE)
					advanceState(ROUTE_STATE);			
			}
			resetEnthralledTimer();
		}
		
		private function roam(evt:TimerEvent):void
		{
			trace("roam");
			if (Math.random() < 0.5)
			{
				temporaryEnthralledTimer.stop();
				temporaryEnthralledTimer.removeEventListener(TimerEvent.TIMER, roam);
				if (state == TEMPORARY_ENTHRALLED_STATE)
					advanceState(ROAM_STATE);			
			}		
		}
		
		public function endEnthralledState():void
		{
			
		}
		
		public function endTemporaryEnthralledState():void
		{
			if (temporaryEnthralledTimer)
			{
				temporaryEnthralledTimer.stop();
//				temporaryEnthralledTimer.removeEventListener(TimerEvent.TIMER, routeToQueue);
				temporaryEnthralledTimer.removeEventListener(TimerEvent.TIMER, roam);
				temporaryEnthralledTimer = null;
			}
		}
		
		public function doEnthralledState(deltaTime:Number):void
		{
			
		}
		
		public function startQueuedState():void
		{
			trace("start queued state");
			state = QUEUED_STATE;
			standFacingObject(currentBooth.thinger as OwnedStructure);
			currentBooth.actualQueue++;			
			checkIfFrontOfQueue();
		}
		
		public function checkIfFrontOfQueue():void
		{
			if (!currentBooth)
				throw new Error("Should have a current booth");
			if (queuedTimer)
			{
//				throw new Error("Queued timer already exists");
			}
			if (currentBoothPosition == 1 && !queuedTimer)
			{
				startQueuedTimer();
				if (proxiedForItemPickup)
					doItemPickup();
			}
			else if (currentBoothPosition == 0)
				throw new Error("Booth position is 0");
		}
		
		public function doItemPickup():void
		{
			doMultipleAnimations(itemPickupAnimations);
			
			for (var i:int = 0; i < Math.round(Math.random() * CustomerPerson.MAX_DROPS_END_MOOD); i++)
			{
				FlexGlobals.topLevelApplication.uiBoss.doCollectibleDropByMood(this, _myWorld);
			}
			removeMoodClip();
			trace("item pickup complete");
			endMood();
		}
		
		public function startQueuedTimer():void
		{
			if (state != QUEUED_STATE)
				throw new Error("State is not queued state");
			
			queuedTimer = new Timer(CustomerPerson.QUEUED_TIME);
			queuedTimer.addEventListener(TimerEvent.TIMER, exitQueue);
			queuedTimer.start();	
			numQueuedTimers++;	
		}

		public function refreshQueuedTimer():void
		{
			if (state != QUEUED_STATE)
				throw new Error("State is not queued state");
			
			queuedTimer.stop();
			queuedTimer.removeEventListener(TimerEvent.TIMER, exitQueue);
			queuedTimer = new Timer(CustomerPerson.QUEUED_TIME);
			queuedTimer.addEventListener(TimerEvent.TIMER, exitQueue);
			queuedTimer.start();		
		}
		
		public function moveUpInQueue():void
		{		
			var destination:Point3D = new Point3D(Math.floor(worldCoords.x), Math.floor(worldCoords.y), Math.floor(worldCoords.z));
			(this.currentBooth.thinger as OwnedStructure).addPointsByRotation(destination, -1);
			movePerson(destination);
		}
		
		private function exitQueue(evt:TimerEvent):void
		{
			if (state == QUEUED_STATE)
			{
				decrementQueue();
				worldDestination = null;
				proxiedForItemPickup = false;
				
				queuedTimer.stop();
				queuedTimer.removeEventListener(TimerEvent.TIMER, exitQueue);
				queuedTimer = null;			
				
				_venue.customerPersonManager.assignNextState(this);
//				advanceState(HEADTOSTAGE_STATE);
//				advanceState(ROAM_STATE);
			}
			else
			{
//				trace("Queued Timers: " + numQueuedTimers.toString());		
//				trace("Enthralled Timers: " + numEnthralledTimers.toString());				
				throw new Error("State is not queued state");
				queuedTimer.stop();
				queuedTimer.removeEventListener(TimerEvent.TIMER, exitQueue);
				queuedTimer = null;				
			}
			
			numQueuedTimers--;
			trace(numQueuedTimers.toString());			
		}
		
		private function decrementQueue():void
		{
			currentBooth.boothBoss.decreaseInventoryCount(currentBooth.thinger as Booth, 1);
			currentBooth.currentQueue--;
			currentBooth.actualQueue--;			
		}
		
		public function endQueuedState():void
		{
			dispatchExitQueueEvent();
			resetCurrentBooth();
		}
		
		private function resetCurrentBooth():void
		{
			currentBooth = null;			
		}
		
		private function dispatchExitQueueEvent():void
		{
			var evt:DynamicEvent = new DynamicEvent("queueDecremented", true, true);
			evt.person = this;
			evt.booth = currentBooth;
			dispatchEvent(evt);
			currentBooth.checkInventoryCount();
		}
		
		public function doQueuedState(deltaTime:Number):void
		{
			
		}
		
		public function startHeadToStageState():void
		{
			state = HEADTOSTAGE_STATE;
			
			var extra:ArrayCollection = new ArrayCollection();
			extra.addItem(_venue.stageBufferRect);
			extra.addItem(_venue.outsideRect);
			var destination:Point3D = _venue.getOpenSeat(_venue.mainCrowdRect, extra);
			movePerson(destination, true);
		}
		
		public function endHeadToStageState():void
		{
			
		}
		
		public function doHeadToStageState(deltaTime:Number):void
		{
			
		}
		
		public function getBoothForRouteState():BoothAsset
		{
			var booth:BoothAsset;
			if (proxiedForItemPickup)
			{
				booth = _boothBoss.getRandomBooth(currentBooth);
				pickupBooth = booth;
			}
			else
			{
				booth = _boothBoss.getRandomBooth(currentBooth);
				pickupBooth = null;
			}	
			return booth;
		}
		
		public function startRouteState():void
		{
			state = ROUTE_STATE;
			personType = Person.MOVING;
			
			var booth:BoothAsset = getBoothForRouteState();
			
			if (booth == null)
//				advanceState(ROAM_STATE);
				_venue.customerPersonManager.assignNextState(this);
			else
			{
				currentBooth = booth;
				currentBooth.currentQueue++;
							
				dispatchRouteEvent();
			}			
		}
		
		public function setQueuedPosition(index:int):void
		{
			currentBoothPosition = index;	
		}
		
		public function dispatchRouteEvent():void
		{
			var evt:DynamicEvent = new DynamicEvent("customerRouted", true, true);
			evt.cp = this;
			evt.booth = currentBooth;
			dispatchEvent(evt);
		}
		
		public function endRouteState():void
		{
			
		}
		
		public function doRouteState(deltaTime:Number):void
		{
			
		}	
		
		public function getBoothActivityTime():int
		{
			return QUEUED_TIME;
		}
		
		public function getEnthralledActivityTime():int
		{
			return TEMPORARY_ENTHRALLED_TIME;
		}
		
		public function pickPointNearStructure(bounds:Rectangle, avoid:Rectangle=null, worldToUpdate:World=null):Point3D
		{
			var extra:ArrayCollection = new ArrayCollection();
			extra.addItem(_venue.outsideRect);
			
			trace("pick point near structure");
			var stagePoint:Point3D;
			var occupiedSpaces:Array;
			if (worldToUpdate)
				occupiedSpaces = worldToUpdate.pathFinder.updateOccupiedSpaces(true, true, null, extra);
			else
				occupiedSpaces = _myWorld.pathFinder.updateOccupiedSpaces(true, true, null, extra);			
			
			if (availableSpaces(occupiedSpaces))
			{
				var xDimension:int;
				var zDimension:int;
				if (avoid)
				{
					do 
					{
						xDimension = Math.round(Math.random()*bounds.width);
						zDimension = bounds.top + Math.round(Math.random()*bounds.height);
						stagePoint = new Point3D(xDimension, 0, zDimension);				
					}
					while ((occupiedSpaces[stagePoint.x] && occupiedSpaces[stagePoint.x][stagePoint.y] && occupiedSpaces[stagePoint.x][stagePoint.y][stagePoint.z]) || 
						(xDimension >= avoid.left && xDimension <= avoid.right && zDimension >= avoid.top && zDimension <= avoid.bottom));					
				}
				else
				{
					do 
					{
						xDimension = Math.round(Math.random()*bounds.width);
						zDimension = bounds.top + Math.round(Math.random()*bounds.height);
						stagePoint = new Point3D(xDimension, 0, zDimension);				
					}
					while (occupiedSpaces[stagePoint.x] && occupiedSpaces[stagePoint.x][stagePoint.y] && occupiedSpaces[stagePoint.x][stagePoint.y][stagePoint.z]);
				}
			}
			else
			{
				throw new Error("There are no available spaces in this world");
			}
			trace("point picked");
			return stagePoint;
		}
		
		private function availableSpaces(occupiedSpaces:Array):Boolean
		{
			if (occupiedSpaces.length > _myWorld.tilesDeep*_myWorld.tilesWide)
				return false;
			return true;
		}
		
		public function updateBoothFront(index:int):void
		{
			var boothFront:Point3D;
			var extra:ArrayCollection = new ArrayCollection();
			extra.addItem(_venue.outsideRect);
			
			if (state == ROUTE_STATE)
			{
				boothFront = _boothBoss.getBoothFront(currentBooth, index, true);
				if (boothFront)
					updateDestination(boothFront);
				else
//					advanceState(ROAM_STATE);
					_venue.customerPersonManager.assignNextState(this);
			}
			else if (state == QUEUED_STATE)
			{
				boothFront = _boothBoss.getBoothFront(currentBooth, index, false, true);
				movePerson(boothFront, true, true, false, null, 0, extra);
			}
			else
				throw new Error("Should not be updating booth front when not in route state");
		}
		
		public function doWantsMusicMood():void
		{
			
		}		
		
		public function getPathToBoothLength(routedCustomer:Boolean=false, queuedCustomer:Boolean=false):int
		{
//			A preliminary guess as to who will get there first
			
			var boothFront:Point3D = _boothBoss.getBoothFront(currentBooth, 0, routedCustomer, queuedCustomer);
//			if (boothFront)
//			{
//				var currentPoint:Point3D = new Point3D(Math.round(worldCoords.x), Math.round(worldCoords.y), Math.round(worldCoords.z));
//				var path:ArrayCollection = _myWorld.pathFinder.calculatePathGrid(this, currentPoint, boothFront, false);
//				return path.length;
//			}
//			else
//				return 0;
			return Math.abs(boothFront.x - worldCoords.x) + Math.abs(boothFront.z - worldCoords.z);
			
		}
		
		public function isCustomerAtQueue():void
		{
			var extra:ArrayCollection = new ArrayCollection();
			extra.addItem(_venue.outsideRect);
			
			if (proxiedDestination)
			{
				if (worldCoords.x != proxiedDestination.x || worldCoords.y != proxiedDestination.y || worldCoords.z != proxiedDestination.z)
					movePerson(proxiedDestination, true, true, false, null, 0, extra);
				else
				{
					if (state == ROUTE_STATE)
						advanceState(QUEUED_STATE);					
					else
						throw new Error("Must be in route state");
				}
			}
			else
			{
				if (state == ROUTE_STATE)
					advanceState(QUEUED_STATE);				
				else
					throw new Error("Must be in route state");
			}
		}
		
		public function set venue(val:Venue):void
		{
			_venue = val;
		}
		
		public function get venue():Venue
		{
			return _venue;
		}
				
	}
}