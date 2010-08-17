package clickhandlers
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filters.GlowFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.getDefinitionByName;
	
	import game.MoodBoss;
	
	import helpers.CollectibleDrop;
	
	import mx.controls.Image;
	import mx.events.FlexEvent;
	
	import rock_on.Person;
	import rock_on.Venue;
	import rock_on.VenueEvent;
	
	import views.BottomBar;
	import views.CustomizableProgressBar;
	import views.WorldView;
	
	import world.ActiveAsset;
	import world.WorldEvent;
	
	public class UIBoss extends EventDispatcher
	{
		public var _worldView:WorldView;
		public var _worldViewMouseHandler:WorldViewClickHandler;
		public var _venue:Venue;
		public var _bottomBar:BottomBar;
		
		public static const MAX_FILLERS:int = 6;	
		[Embed(source="../libs/icons/hearts_chain_6.png")]
		public var heartsChain6:Class;		
		[Embed(source="../libs/icons/skin_plain_red.png")]
		public var plainSkinRed:Class;		
		[Embed(source="../libs/icons/skin_plain_black.png")]
		public var plainSkinBlack:Class;		
		
		public function UIBoss(worldView:WorldView, bottomBar:BottomBar, target:IEventDispatcher=null)
		{
			super(target);
			_worldView = worldView;
			_bottomBar = bottomBar;
			_worldView.addEventListener(VenueEvent.VENUE_INITIALIZED, onVenueInitialized);
		}
		
		private function onVenueInitialized(evt:VenueEvent):void
		{
			_worldViewMouseHandler = _worldView.mouseHandler as WorldViewClickHandler;			
			_worldViewMouseHandler.addEventListener(UIEvent.COLLECTIBLE_DROP_FROM_STAGE, onCollectibleDropFromStage);
			_worldViewMouseHandler.addEventListener(UIEvent.REPLACE_BOTTOMBAR, onReplaceBottomBar);	
			_venue = _worldView.venueManager.venue;
		}
		
		private function doCollectibleDrop(person:Person):void
		{
			for each (var reward:Object in person.mood.rewards)
			{
				if (reward.mc)
				{	
					var klass:Class = getDefinitionByName(reward.mc) as Class;
					var mc:MovieClip = new klass() as MovieClip;
					addCollectible(mc, person);
				}
			}
			if ((person.mood.possible_rewards as Array).length > 0)
				addCollectible(MoodBoss.getRandomItemByMood(person.mood), person);			
		}
		
		private function addCollectible(mc:MovieClip, person:Person):void
		{
			var radius:Point = new Point(100, 50);
			var collectibleDrop:CollectibleDrop = new CollectibleDrop(person, mc, radius, _worldView.myWorld, _worldView, 0, 400, .001, null, new Point(person.x, person.y - 70));
			collectibleDrop.addEventListener("removeCollectible", function onRemoveCollectible():void
			{
				_worldView.myWorld.removeChild(collectibleDrop);
			});
			_worldView.myWorld.addChild(collectibleDrop);							
		}
		
		private function onCollectibleDropFromStage(evt:UIEvent):void
		{
			var bar:CustomizableProgressBar = createHeartProgressBar(evt.asset as Person);
			_venue.bandMemberManager.goToStageAndTossItem(evt.asset as Person, _worldView);
			_venue.bandMemberManager.myAvatar.addEventListener(WorldEvent.ITEM_DROPPED, function onItemTossedByAvatar():void
			{
				_venue.bandMemberManager.myAvatar.removeEventListener(WorldEvent.ITEM_DROPPED, onItemTossedByAvatar);
				(evt.asset as Person).removeMoodClip();
				bar.startBar();
			});				
		}
		
		private function onReplaceBottomBar(evt:UIEvent):void
		{
			if (evt.asset && evt.asset is Person)
				_bottomBar.replaceCreatureInfo((evt.asset as Person).creature);
		}
		
		public function createHeartProgressBar(person:Person):CustomizableProgressBar
		{
			var barCoords:Point = getCenterPointAbovePerson(person);
			var img:Image = getProgressBarImage();
			person.doNotClearFilters = true;
			
			var numFillers:int = Math.ceil(Math.random() * MAX_FILLERS);
			var totalTime:int = numFillers * 800;
			var customizableBar:CustomizableProgressBar = new CustomizableProgressBar(21, 24, 22, img, totalTime, 50, HeartEmpty, plainSkinBlack, plainSkinRed, barCoords.x, barCoords.y, numFillers);
			customizableBar.addEventListener(WorldEvent.PROGRESS_BAR_COMPLETE, function onProgressBarComplete():void
			{
				customizableBar.removeEventListener(WorldEvent.PROGRESS_BAR_COMPLETE, onProgressBarComplete);
				person.doNotClearFilters = false;
				_worldView.removeChild(customizableBar);
				doCollectibleDrop(person);				
			});
			customizableBar.x = customizableBar.x + (person.width - customizableBar.width)/2 - 35;
			addFilterForHeartProgressBar(person, customizableBar);
			_worldView.addChild(customizableBar);
			return customizableBar;
		}	
		
		private function getProgressBarImage():Image
		{
			var img:Image = new Image();
			img.source = "../libs/icons/hearts_chain_6.png";
			img.width = 135;
			img.height = 25;	
			return img;
		}
		
		public function getCenterPointAbovePerson(person:Person):Point
		{
			var worldRect:Rectangle = _worldView.myWorld.getBounds(_worldView); 
			var wgRect:Rectangle = _worldView.myWorld.wg.getBounds(_worldView.myWorld);
			return new Point(person.realCoords.x + worldRect.x, 
				person.realCoords.y + wgRect.height/2 - person.height/2);			
		}
		
		private function addFilterForHeartProgressBar(asset:Sprite, customizableBar:CustomizableProgressBar):void
		{
			var gf:GlowFilter = new GlowFilter(0xFFDD00, 1, 2, 2, 20, 20);
			asset.filters = [gf];		
			customizableBar.filters = [gf];
		}			
	}
}