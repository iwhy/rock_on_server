package controllers
{
	import flash.display.Bitmap;
	import flash.display.MovieClip;
	import flash.events.IEventDispatcher;
	import flash.geom.Rectangle;
	import flash.utils.getQualifiedClassName;
	
	import models.EssentialModelReference;
	import models.Layerable;
	import models.OwnedLayerable;
	
	import mx.collections.ArrayCollection;
	import mx.core.UIComponent;
	import mx.events.CollectionEvent;
	import mx.events.DynamicEvent;
	
	import rock_on.VenueEvent;
	
	import server.ServerDataEvent;
	
	import views.ContainerUIC;
	import views.InventoryItemRenderer;

	public class LayerableController extends Controller
	{
		public var _layerables:ArrayCollection;
		public var _owned_layerables:ArrayCollection;
		public var _friend_owned_layerables:ArrayCollection;

		public var layerableMovieClipsLoaded:int;
		public var ownedLayerableParentsAssigned:int;
		public var ownedLayerablesAssignedToParents:int;
		
		public var ownedLayerablesLoaded:Boolean;
		public var layerablesLoaded:Boolean;
		public var friendOwnedLayerablesLoaded:Boolean;
		
		public static const EYE_SCALE:Number = 1;
		public static const INSTRUMENT_SCALE:Number = 0.5;
		public static const BODY_SCALE:Number = 0.5;
		
		public function LayerableController(essentialModelController:EssentialModelController, target:IEventDispatcher=null)
		{
			super(essentialModelController, target);
			_layerables = essentialModelController.layerables;
			_owned_layerables = essentialModelController.owned_layerables;
			_friend_owned_layerables = essentialModelController.friend_owned_layerables;
			
			_layerables.addEventListener(CollectionEvent.COLLECTION_CHANGE, onLayerablesCollectionChange);
			_owned_layerables.addEventListener(CollectionEvent.COLLECTION_CHANGE, onOwnedLayerablesCollectionChange);
			_friend_owned_layerables.addEventListener(CollectionEvent.COLLECTION_CHANGE, onFriendOwnedLayerablesCollectionChange);
			
//			essentialModelController.addEventListener(EssentialEvent.INSTANCE_LOADED, onInstanceLoaded);
			essentialModelController.addEventListener(EssentialEvent.PARENT_ASSIGNED, onParentAssigned);	
			essentialModelController.addEventListener(EssentialEvent.ASSIGNED_TO_PARENT, onAssignedToParent);			
		}
		
		private function onFriendOwnedLayerablesCollectionChange(evt:CollectionEvent):void
		{
			if (checkIfOwnedLayerableLoadingComplete())
			{
				friendOwnedLayerablesLoaded = true;
				if (checkIfAllOwnedLayerableParentsAssigned() && checkIfAllOwnedLayerablesAssignedToParents())
				{
					friendAvatarsLoaded();
				}
			}
		}
		
		public function friendAvatarsLoaded():void
		{
			var event:ServerDataEvent = new ServerDataEvent(ServerDataEvent.FRIEND_AVATARS_LOADED);
			dispatchEvent(event);			
		}
		
		public function checkIfAllOwnedLayerableParentsAssigned():Boolean
		{
			if (ownedLayerableParentsAssigned == _owned_layerables.length && _owned_layerables.length > 0)
			{
				return true;
			}
			return false;
		}
		
		public function checkIfAllOwnedLayerablesAssignedToParents():Boolean
		{
			if (ownedLayerablesAssignedToParents == _owned_layerables.length && _owned_layerables.length > 0)
			{
				return true;
			}
			return false;
		}
		
		public function checkIfOwnedLayerableLoadingComplete():Boolean
		{
			var numOwnedLayerables:int = _owned_layerables.length;
			if (_essentialModelController.gdi.sc.allOutoingRequestsReceived("owned_layerable"))
			{
				if (numOwnedLayerables == EssentialModelReference.numInstancesToLoad["owned_layerable"])
				{
					return true;
				}
			}
			return false;
		}
		
		private function checkIfValidOwnedLayerable(ol:OwnedLayerable):Boolean
		{
			if (ol.layerable_id == 0)
			{
				throw new Error("No layerable id for owned layerable");
			}	
			if (ol.creature_id == 0)
			{
				throw new Error("No creature id for owned layerable");
			}
			if (ol.user_id == 0)
			{
				throw new Error("No user id for owned layerable");
			}
			return true;
		}
		
		private function onOwnedLayerablesCollectionChange(evt:CollectionEvent):void
		{
			checkIfValidOwnedLayerable(evt.items[0] as OwnedLayerable);
			if ((evt.items[0] as OwnedLayerable).layerable == null)
			{
				(evt.items[0] as OwnedLayerable).addEventListener(EssentialEvent.PARENT_ASSIGNED, onParentAssigned);	
			}
			else
			{
				ownedLayerableParentsAssigned++;
				checkIfOwnedLayerablesFullyLoaded();
				runEssentialChecks();
			}
		}
	
		private function onLayerablesCollectionChange(evt:CollectionEvent):void
		{
			if ((evt.items[0] as Layerable).mc == null)
			{
				(evt.items[0] as Layerable).addEventListener("movieClipLoaded", onLayerableMovieClipAssigned);			
			}
			else
			{
				layerableMovieClipsLoaded++;
				checkIfLayerablesFullyLoaded();
				runEssentialChecks(true);
			}
		}
		
		private function onAssignedToParent(evt:EssentialEvent):void
		{
			if (evt.instance is OwnedLayerable)
			{
				var ol:OwnedLayerable = evt.instance as OwnedLayerable;
				ownedLayerablesAssignedToParents++;
				checkIfOwnedLayerablesFullyLoaded();
				runEssentialChecks(true);
			}
		}
		
		public function checkIfLayerablesFullyLoaded():Boolean
		{
			if (checkIfAllLayerablesLoaded() && checkIfAllLayerableMovieClipsLoaded())
			{
				var evt:EssentialEvent = new EssentialEvent(EssentialEvent.LAYERABLES_LOADED);
				this.dispatchEvent(evt);
				return true;
			}
			return false;
		}
		
		public function checkIfOwnedLayerablesBelongToUser():Boolean
		{
			for each (var ol:OwnedLayerable in _owned_layerables)
			{
				if (ol.user_id != -1)
				{
					return true;
				}
			}
			return false;
		}
		
		public function checkIfOwnedLayerablesFullyLoaded():Boolean
		{
//			if (checkIfAllOwnedLayerableParentsAssigned() && checkIfAllOwnedLayerablesAssignedToParents() && checkIfAllOwnedLayerablesAdded())
			if (checkIfAllOwnedLayerableParentsAssigned() && checkIfAllOwnedLayerablesAdded() && checkIfOwnedLayerablesBelongToUser() && checkIfOwnedLayerableLoadingComplete())
			{
				var evt:EssentialEvent = new EssentialEvent(EssentialEvent.OWNED_LAYERABLES_LOADED);
				this.dispatchEvent(evt);
				return true;
			}			
			return false;
		}
		
		public function checkIfFriendAvatarsLoaded():Boolean
		{
//			if (checkIfAllOwnedLayerableParentsAssigned() && checkIfAllOwnedLayerablesAssignedToParents() && checkIfAllOwnedLayerablesAdded())
			if (checkIfAllOwnedLayerableParentsAssigned() && checkIfAllOwnedLayerablesAdded())
			{
				if (friendOwnedLayerablesLoaded)
				{
					friendAvatarsLoaded();
					return true;
				}
			}
			return false;
		}
		
		private function checkIfAllLayerableMovieClipsLoaded():Boolean
		{
			for each (var l:Layerable in _layerables)
			{
				if (!l.mc)
				{
					return false;
				}
			}
			return true;
		}
		
		private function checkIfAllLayerablesLoaded():Boolean
		{
			if (_layerables.length == EssentialModelReference.numInstancesToLoad["layerable"])
			{
				return true;
			}
			return false;
		}
		
		private function onParentAssigned(evt:EssentialEvent):void
		{
			var ol:OwnedLayerable = evt.currentTarget as OwnedLayerable;
			ol.removeEventListener(EssentialEvent.PARENT_ASSIGNED, onParentAssigned);
			ownedLayerableParentsAssigned++;			
			checkIfOwnedLayerablesFullyLoaded();
			runEssentialChecks(true);			
		}
		
		public function areLayerablesAssignedToOwnedLayerables():Boolean
		{
			var total:int = 0;
			for each (var ol:OwnedLayerable in _owned_layerables)
			{
				if (ol.layerable)
				{
					total++;
				}
			}
			if (total == _owned_layerables.length)
			{
				return true;
			}
			else
			{
//				trace("layerable refs: " + total.toString());
			}
			return false;
		}
		
		public function checkIfAllOwnedLayerablesAdded():Boolean
		{
			if (_owned_layerables.length == EssentialModelReference.numInstancesToLoad["owned_layerable"])
			{
				return true;
			}
			return false;
		}
		
//		private function checkForLoadingComplete():void
//		{
//			if (_layerables.length == EssentialModelReference.numInstancesToLoad["layerable"] && _owned_layerables.length == EssentialModelReference.numInstancesToLoad["owned_layerable"])
//			{
//				for each (var l:Layerable in _layerables)
//				{
//					if (!l.mc)
//					{
//						return;
//					}
//				}
//				for each (var ol:OwnedLayerable in _owned_layerables)
//				{
//					if (!ol.layerable)
//					{
//						return;
//					}
//				}
//				essentialModelController.checkIfLoadingAndInstantiationComplete();	
//			}			
//		}
		
//		private function onParentMovieClipAssigned(evt:DynamicEvent):void
//		{
//			(evt.target as OwnedLayerable).removeEventListener("parentMovieClipAssigned", onParentMovieClipAssigned);
//			ownedLayerableMovieClipsLoaded++;
//			
//			runEssentialChecks(true);
//		}
		
		private function onLayerableMovieClipAssigned(evt:DynamicEvent):void
		{
			(evt.target as Layerable).removeEventListener("movieClipLoaded", onLayerableMovieClipAssigned);
			layerableMovieClipsLoaded++;
			checkIfLayerablesFullyLoaded();
			runEssentialChecks();
		}
		
		private function runEssentialChecks(checkFriendData:Boolean=false):void
		{
			essentialModelController.checkIfLoadingAndInstantiationComplete();			
			if (checkFriendData)
			{
				checkIfFriendAvatarsLoaded();			
			}
		}
		
//		private function checkIfAllUserDataIsLoaded():void
//		{
//			essentialModelController.checkIfLoadingAndInstantiationComplete();			
//		}
		
//		private function onInstanceLoaded(evt:EssentialEvent):void
//		{
//			if (evt.instance is Layerable)
//			{
//				layerablesLoaded++;
//			}
//			else if (evt.instance is OwnedLayerable)
//			{
//				ownedLayerablesLoaded++;
//			}
//			essentialModelController.checkIfLoadingAndInstantiationComplete();
//		}		
		
		public function getMovieClipCopy(layerable:Layerable, formatted:Boolean=false, dimensionX:int=100, dimensionY:int=100):UIComponent
		{
			var copy:MovieClip = EssentialModelReference.getMovieClipCopy(layerable.mc);
			if (formatted)
			{
				var uic:UIComponent = formatMovieClipByDimensions(copy, dimensionX, dimensionY, 0, 0);
			}
			return uic;
		}
		
		public function updateOwnedLayerableOnServerResponse(olCopy:OwnedLayerable, method:String):void
		{
			var olReference:OwnedLayerable;
			for each (var ol:OwnedLayerable in owned_layerables)
			{
				if (ol.id == olCopy.id)
				{
					olReference = ol;
				}
			}	
			olReference.updateProperties(olCopy);
		}
		
		public function load(params:Object):void
		{

		}
		
		public function instantiate(params:Object, loadedClass:Class):void
		{
			if (loadedClass)
			{
				var layerable:Layerable = new Layerable(params, loadedClass);
				add(layerable);
			}
		}
		
		public function add(layerable:Layerable):void
		{
			_layerables.addItem(layerable);
		}		
		
		public function remove(layerable:Layerable):void
		{
			var i:int = _layerables.getItemIndex(layerable);
			_layerables.removeItemAt(i);
		}
		
		public function set layerables(val:ArrayCollection):void
		{
			_layerables = val;
		}
		
		public function get layerables():ArrayCollection
		{
			return _layerables;
		}
		
		public function set owned_layerables(val:ArrayCollection):void
		{
			_owned_layerables = val;
		}
		
		public function get owned_layerables():ArrayCollection
		{
			return _owned_layerables;
		}
		
		public static function formatMovieClipByDimensions(mc:MovieClip, dimensionX:int, dimensionY:int, itemPaddingX:int, itemPaddingY:int):ContainerUIC
		{
			var ratio:Number = mc.width/mc.height;
			var uic:ContainerUIC = new ContainerUIC();
			uic.width = dimensionX;
			uic.height = dimensionY;
			mc.stop();
			var toScale:Number;
			var rect:Rectangle;
			
			if (mc.width > mc.height)
				toScale = dimensionX / mc.width;
			else 
				toScale = dimensionY / mc.height;
			
			var bitmap:Bitmap = InventoryItemRenderer.bitmapMovieClip(mc, uic, toScale);

			mc.scaleX = toScale;
			mc.scaleY = toScale;
//			rect = mc.getBounds(uic);
			rect = mc.getBounds(uic);
			
//			bitmap.y = -(rect.top) + (dimensionY - mc.height)/2; 							
//			bitmap.x = -(rect.left) + (dimensionX - mc.width)/2;			
			bitmap.y = (dimensionY - mc.height)/2; 							
			bitmap.x = (dimensionX - mc.width)/2;			
			uic.x = itemPaddingX;
			uic.y = itemPaddingY;
			uic.addChild(bitmap);
			return uic;
		}
		
	}
}