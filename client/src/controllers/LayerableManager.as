package controllers
{
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
	
	import views.ContainerUIC;

	public class LayerableManager extends Manager
	{
		public var _layerables:ArrayCollection;
		public var _owned_layerables:ArrayCollection;
		public var ownedLayerableMovieClipsLoaded:int;
		public var ownedLayerablesLoaded:int;
		public var layerablesLoaded:int;
		public var fullyLoaded:Boolean;
		
		public static const EYE_SCALE:Number = 1;
		public static const INSTRUMENT_SCALE:Number = 0.4;
		public static const BODY_SCALE:Number = 0.5;
		
		public function LayerableManager(essentialModelManager:EssentialModelManager, target:IEventDispatcher=null)
		{
			super(essentialModelManager, target);
			_layerables = essentialModelManager.layerables;
			_owned_layerables = essentialModelManager.owned_layerables;
			_owned_layerables.addEventListener(CollectionEvent.COLLECTION_CHANGE, onOwnedLayerablesCollectionChange);
			essentialModelManager.addEventListener(EssentialEvent.INSTANCE_LOADED, onInstanceLoaded);
			essentialModelManager.addEventListener(EssentialEvent.PARENT_ASSIGNED, onParentAssigned);			
			
			ownedLayerableMovieClipsLoaded = 0;
			ownedLayerablesLoaded = 0;
			layerablesLoaded = 0;
		}
		
		private function onOwnedLayerablesCollectionChange(evt:CollectionEvent):void
		{
			(evt.items[0] as OwnedLayerable).addEventListener('parentMovieClipAssigned', onParentMovieClipAssigned);
			(evt.items[0] as OwnedLayerable).addEventListener(EssentialEvent.PARENT_ASSIGNED, onParentAssigned);			
		}
		
		private function onParentAssigned(evt:EssentialEvent):void
		{
			var ol:OwnedLayerable = evt.currentTarget as OwnedLayerable;
			ol.removeEventListener(EssentialEvent.PARENT_ASSIGNED, onParentAssigned);
			if (ol.layerable.mc)
			{
				ownedLayerableMovieClipsLoaded++;
			}		
		}	
		
		private function onParentMovieClipAssigned(evt:DynamicEvent):void
		{
			(evt.target as OwnedLayerable).removeEventListener('parentMovieClipAssigned', onParentMovieClipAssigned);
			ownedLayerableMovieClipsLoaded++;
			essentialModelManager.checkIfAllLoadingComplete();
		}
		
		private function onInstanceLoaded(evt:EssentialEvent):void
		{
			if (evt.instance is Layerable)
			{
				layerablesLoaded++;
			}
			else if (evt.instance is OwnedLayerable)
			{
				ownedLayerablesLoaded++;
			}
			essentialModelManager.checkIfAllLoadingComplete();
		}		
		
		public function getMovieClipCopy(layerable:Layerable, formatted:Boolean=false, dimensionX:int=100, dimensionY:int=100):UIComponent
		{
//			var className:String = flash.utils.getQualifiedClassName(layerable.mc);
//			var klass:Class = essentialModelManager.essentialModelReference.loadedModels[className].klass;
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
			{
				toScale = dimensionX / mc.width;
			}
			else 
			{
				toScale = dimensionY / mc.height;
			}
			
			mc.scaleX = toScale;
			mc.scaleY = toScale;
			rect = mc.getBounds(uic);
			
			mc.y = -(rect.top) + (dimensionY - mc.height)/2; 							
			mc.x = -(rect.left) + (dimensionX - mc.width)/2;			
			uic.x = itemPaddingX;
			uic.y = itemPaddingY;
			uic.addChild(mc);
			return uic;
		}
		
	}
}