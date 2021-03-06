package controllers
{
	import flash.display.Loader;
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;
	import flash.utils.getDefinitionByName;
	
	import game.GameDataInterface;
	
	import helpers.UnprocessedModel;
	
	import models.BoothStructure;
	import models.Creature;
	import models.CreatureGroup;
	import models.Dwelling;
	import models.EssentialModelReference;
	import models.FriendUser;
	import models.Layerable;
	import models.Level;
	import models.OwnedDwelling;
	import models.OwnedLayerable;
	import models.OwnedSong;
	import models.OwnedStructure;
	import models.OwnedThinger;
	import models.OwnedUsable;
	import models.Song;
	import models.Store;
	import models.StoreOwnedThinger;
	import models.Structure;
	import models.Usable;
	import models.User;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.events.DynamicEvent;
	
	import server.ServerController;
	import server.ServerDataEvent;

	public class EssentialModelController extends Controller
	{	
		public var _gdi:GameDataInterface;
		public var instancesToLoad:ArrayCollection;
		public var instancesLoaded:ArrayCollection;	
		
		public var userContentLoaded:Boolean;
		
		public var totalRequests:int = 0;
		public var instancesFullyLoaded:int = 0;
		public var applicationDomain:ApplicationDomain;
		public var essentialModelReference:EssentialModelReference;
		[Bindable] public var layerables:ArrayCollection;
		[Bindable] public var owned_layerables:ArrayCollection;
		[Bindable] public var creatures:ArrayCollection;
		[Bindable] public var thingers:ArrayCollection;
		[Bindable] public var owned_thingers:ArrayCollection;
		[Bindable] public var users:ArrayCollection;
		[Bindable] public var levels:ArrayCollection;
		[Bindable] public var stores:ArrayCollection;
		[Bindable] public var store_owned_thingers:ArrayCollection;
		[Bindable] public var structures:ArrayCollection;
		[Bindable] public var owned_structures:ArrayCollection;
		[Bindable] public var dwellings:ArrayCollection;
		[Bindable] public var owned_dwellings:ArrayCollection;
		[Bindable] public var booth_structures:ArrayCollection;
		[Bindable] public var friend_users:ArrayCollection;
		[Bindable] public var creature_groups:ArrayCollection;
		[Bindable] public var songs:ArrayCollection;
		[Bindable] public var owned_songs:ArrayCollection;
		[Bindable] public var usables:ArrayCollection;
		[Bindable] public var owned_usables:ArrayCollection;
		[Bindable] public var friend_creatures:ArrayCollection;
		[Bindable] public var friend_owned_layerables:ArrayCollection;
		
		public var layerable:Layerable;
		public var creature:Creature;
		public var song:Song;
		public var owned_song:OwnedSong;
		public var owned_thinger:OwnedThinger;
		public var user:User;
		public var store:Store;
		public var creature_group:CreatureGroup;
		public var store_owned_thinger:StoreOwnedThinger;
		public var structure:Structure;
		public var owned_structure:OwnedStructure;
		public var owned_layerable:OwnedLayerable;
		public var dwelling:Dwelling;
		public var owned_dwelling:OwnedDwelling;
		public var level:Level;
		public var booth_structure:BoothStructure;
		public var friend_user:FriendUser;
		public var usable:Usable;
		public var owned_usable:OwnedUsable;
		
		public var baseUrl:String = ServerController.BASE_URL;		
		
		public function EssentialModelController(target:IEventDispatcher=null)
		{
			super(this, target);
			initializeArrays();
		}	
		
		public function initializeArrays():void
		{
			instancesToLoad = new ArrayCollection();
			instancesLoaded = new ArrayCollection();			
			layerables = new ArrayCollection();
			songs = new ArrayCollection();
			owned_songs = new ArrayCollection();
			owned_layerables = new ArrayCollection();
			usables = new ArrayCollection();
			owned_usables = new ArrayCollection();
			creatures = new ArrayCollection();	
			creature_groups = new ArrayCollection();
			thingers = new ArrayCollection();	
			structures = new ArrayCollection();
			owned_structures = new ArrayCollection();
			owned_thingers = new ArrayCollection();
			stores = new ArrayCollection();
			store_owned_thingers = new ArrayCollection();	
			users = new ArrayCollection();
			levels = new ArrayCollection();
			dwellings = new ArrayCollection();
			owned_dwellings = new ArrayCollection();
			booth_structures = new ArrayCollection();
			friend_users = new ArrayCollection();
			friend_creatures = new ArrayCollection();
			friend_owned_layerables = new ArrayCollection();
			essentialModelReference = new EssentialModelReference();
		}
		
		public function loadNewInstance(toLoad:UnprocessedModel):void
		{
			instancesToLoad.addItem(toLoad);
			
			var i:int = 0;
			var relationshipName:String;
			
			for each (relationshipName in toLoad.relationshipData.belongs_to)
			{
				var belongsToId:int = toLoad.relationshipData.belongs_to_id[i];
				doesObjectBelongTo(toLoad, belongsToId, relationshipName);
				i++;
			}
			for each (relationshipName in toLoad.relationshipData.has_many)
			{
				doesObjectHaveMany(toLoad, relationshipName);
			}
			if (toLoad.instance == null)
			{
				instantiateAndUpdate(toLoad);			
			}
		}	
		
		public function doesObjectBelongTo(toLoad:UnprocessedModel, belongsToId:int, belongsToName:String):void
		{
			for each (var um:UnprocessedModel in essentialModelReference.allInstancesLoaded)
			{
				if (um.model == belongsToName && um.instance.id == belongsToId)
				{
					instantiateAndUpdate(toLoad);
					updateBelongsTo(um, toLoad);
					break;
				}
			}			
		}
		
		public function doesObjectHaveMany(toLoad:UnprocessedModel, hasManyName:String):void
		{
			for each (var um:UnprocessedModel in instancesToLoad)
			{			
				for each (var belongsTo:String in um.relationshipData.belongs_to)
				{
					if (belongsTo == hasManyName && um.relationshipData.belongs_to_id == toLoad.instanceData.id)	
					{
						if (um.instance == null)
						{
							instantiateWithHasMany(um, toLoad);							
						}
	//					Do this later
	//					updateHasMany(obj, toLoad, instance);
					}				
				}
			}				
		}
		
		public function instantiateAndUpdate(um:UnprocessedModel):void
		{
			if (um.instance == null)
			{
				instantiateAndAdd(um);
				removeFromToLoad(um);			
			}
		}
		
		public function updateBelongsTo(belongsTo:UnprocessedModel, isChild:UnprocessedModel):void
		{
			addThisToParent(belongsTo, isChild);
			updateChildWithBelongsTo(belongsTo, isChild);			
		}
		
		public function instantiateWithHasMany(belongsTo:UnprocessedModel, isChild:UnprocessedModel):void
		{
			instantiateAndAdd(belongsTo);
			instantiateAndAdd(isChild);
			removeFromToLoad(belongsTo);	
			removeFromToLoad(isChild);	
		}	
		
		public function updateHasMany(belongsTo:UnprocessedModel, isChild:UnprocessedModel):void
		{
			addThisToParent(belongsTo, isChild);
			updateChildWithBelongsTo(belongsTo, isChild);			
		}	
		
		private function onModelLoaded(model:String):void
		{
			var sde:ServerDataEvent = new ServerDataEvent(ServerDataEvent.MODEL_COLLECTION_LOADED, model, null, null, true, true);
			dispatchEvent(sde);
		}
		
		public function updateChildWithBelongsTo(belongsTo:UnprocessedModel, isChild:UnprocessedModel):void
		{
			isChild.instance[belongsTo.model+'_id'] = belongsTo.instance.id;
			
			if (isChild.instance.hasOwnProperty(belongsTo.model))
			{
				assignParentInstanceToChild(belongsTo, isChild);
				
				if (belongsTo.instance.hasOwnProperty('mc'))
				{
					assignParentMovieClipToChild(belongsTo, isChild);
				}
				else
				{
//					throw new Error("Fix me!");
//					why is this here??
//					classesToLoad.addItem(isChild.instance[belongsTo.model]);					
				}
			}
		}
		
		public function assignParentInstanceToChild(belongsTo:UnprocessedModel, isChild:UnprocessedModel):void
		{
//			var className:String = convertToClassCase(belongsTo.model);			
//			var newClass:Class = getDefinitionByName('models.'+className) as Class;				
//			isChild.instance[belongsTo.model] = new newClass(belongsTo.instance);
			isChild.instance[belongsTo.model] = belongsTo.instance;
			
			var evt:EssentialEvent = new EssentialEvent(EssentialEvent.PARENT_ASSIGNED, isChild.instance, isChild.model, true, true);
			isChild.instance.dispatchEvent(evt);			
			
			// Add our copy to list of class copies
			var classCopiesArray:Array = [belongsTo.instance, isChild.instance[belongsTo.model]];
			essentialModelReference.classCopies.push(classCopiesArray);
//			trace(essentialModelReference.classCopies.length.toString());
//			isChild.instance[belongsTo.model] = belongsTo.instance;			
		}		
		
		public function assignParentMovieClipToChild(belongsTo:UnprocessedModel, isChild:UnprocessedModel):void
		{
			var swfIsLoaded:Boolean = false;
			for each (var obj:Object in essentialModelReference.loadedSwfs)
			{
				if (baseUrl+belongsTo.instance['swf_url'] == obj.url)
				{
					swfIsLoaded = true;
					var appDomain:ApplicationDomain = obj.applicationDomain;
				}
			}
			if (swfIsLoaded)
			{
				var className:String = belongsTo.instance.symbol_name;
				var newClass:Class = appDomain.getDefinition(className) as Class;	
//				var newClass:Class = EssentialModelReference.getClassCopy(className);			
				isChild.instance[belongsTo.model].setMovieClipFromClass(newClass);	
				
				if (!EssentialModelReference.loadedModels[className])
				{
					EssentialModelReference.updateLoadedModels(className, newClass, null);
				}
			}
			else if (belongsTo.instance['swf_url'])
			{
//				throw new Error("Fix me!");
//				what the hell am I supposed to have here?				
				essentialModelReference.classesToLoad.addItem(belongsTo.instance);
			}
		}
		
		public function addThisToParent(belongsTo:UnprocessedModel, isChild:UnprocessedModel):void
		{
			if (isChild.model+'s' in belongsTo.instance)
			{
				(belongsTo.instance[isChild.model+'s'] as ArrayCollection).addItem(isChild.instance); 
				
				var parentEvt:EssentialEvent = new EssentialEvent(EssentialEvent.CHILD_ASSIGNED, belongsTo.instance, belongsTo.model);
				belongsTo.instance.dispatchEvent(parentEvt);
				var childEvt:EssentialEvent = new EssentialEvent(EssentialEvent.ASSIGNED_TO_PARENT, isChild.instance, isChild.model); 
	//			isChild.instance.dispatchEvent(childEvt);
				dispatchEvent(childEvt);
			}
		}
		
		public function doesInstanceBelongToFriend(isChild:UnprocessedModel):Boolean
		{
			if (isChild.instance.hasOwnProperty("user_id") && isChild.instance.user_id != -1)
			{
				if (isChild.instance.user_id != _gdi.user.id && isChild.instance.user_id != 0)
				{
					return true;
				}
			}
			return false;
		}
		
		public function removeFromToLoad(toLoad:Object):void
		{
			var index:int = instancesToLoad.getItemIndex(toLoad);
			instancesToLoad.removeItemAt(index);
			checkIfLoadingAndInstantiationComplete();
		}
		
		public function createNewClassInstance(um:UnprocessedModel):void
		{
			var className:String = convertToClassCase(um.model);			
			var newClass:Class = getDefinitionByName('models.'+className) as Class;
			um.instance = new newClass(um.instanceData);	
//			essentialModelReference.loadedModels[className] = {klass: newClass, applicationDomain: null};	
			EssentialModelReference.updateLoadedModels(className, newClass, null);
		}
		
		public function instantiateAndAdd(um:UnprocessedModel):void
		{
			createNewClassInstance(um);
			
			if (um.instance.hasOwnProperty('swf_url'))
			{
				instantiateAndAddSwf(um);
			}
			else
			{
				var evt:EssentialEvent = new EssentialEvent(EssentialEvent.INSTANCE_LOADED, um.instance, um.model, true, true);
				dispatchEvent(evt);
			}
			
			instancesLoaded.addItem(um);
			essentialModelReference.allInstancesLoaded.addItem(um);
			
			if (doesInstanceBelongToFriend(um))
			{
				(this[um.model+'s'] as ArrayCollection).addItem(um.instance); 							
				(this["friend_"+um.model+"s"] as ArrayCollection).addItem(um.instance);				
			}
			else
			{
				(this[um.model+'s'] as ArrayCollection).addItem(um.instance); 			
			}
		}	
		
		public function convertToClassCase(str:String):String
		{
			var arr:Array = str.split('_');
			var result:String = new String();
			for (var i:int = 0; i < arr.length; i++)
			{
				var c:String = (arr[i] as String).charAt(0).toUpperCase();
				var rest:String = (arr[i] as String).substr(1);
				result += c;
				result += rest; 
			}
			return result;
		}
		
		public function instantiateAndAddSwf(um:UnprocessedModel):void
		{
			var isLoaded:Boolean = checkForLoadedSwf(um.instanceData, um.instance);
			essentialModelReference.classesToLoad.addItem(um.instance);
			if (!um.instanceData['symbol_name'] && !um.instanceData['swf_url'])
			{
				// Do nothing? Or just change this into a function
//				var evt:EssentialEvent = new EssentialEvent(EssentialEvent.INSTANCE_LOADED, um.instance, um.model, true, true);
//				dispatchEvent(evt);				
			}
			else if (!um.instanceData['swf_url'])
			{
				throw new Error("Why are you creating a movie clip without a swf url?");
			}			
		}		
		
		public function checkForLoadedSwf(params:Object, parentInstance:Object):Boolean
		{		
			for each (var obj:Object in essentialModelReference.swfsToLoad)
			{
				if (obj['swf_url'] == params['swf_url'])
				{
					return true;
				}
			}
			loadSwf(params['swf_url']);
			essentialModelReference.swfsToLoad.addItem(params);
			return false;				
		}		
		
		public function loadSwf(swfUrl:String):void
		{		
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onClassesLoaded);
			var request:URLRequest = new URLRequest(baseUrl+swfUrl);
			loader.load(request);	
		}
		
		private function onClassesLoaded(evt:Event):void
		{
			applicationDomain = evt.currentTarget.applicationDomain as ApplicationDomain;
			essentialModelReference.loadedSwfs.addItem({applicationDomain: applicationDomain, url: evt.currentTarget.url});
			loadAssociatedClasses(evt.currentTarget.url, evt.currentTarget.loader, applicationDomain);		
		}
		
		public function loadAssociatedClasses(swfUrl:String, classLoader:Loader, appDomain:ApplicationDomain):void
		{
			for each (var obj:Object in essentialModelReference.classesToLoad)
			{
				if (baseUrl+obj['swf_url'] == swfUrl)
				{
					loadClassInstance(obj, appDomain);											
				}
			}
		}
		
		public function loadClassInstance(obj:Object, appDomain:ApplicationDomain):void
		{
			var className:String = obj['symbol_name'];
			
			if (className == null)
			{
				Alert.show(obj.toString() + " is null");
			}
			if (obj is Structure && className == null)
			{
				Alert.show((obj as Structure).id.toString() + " is null");
			}
			
			if (className)
			{
				var loadedClass:Class = appDomain.getDefinition(className) as Class;
				essentialModelReference.loadedClasses.addItem(loadedClass);
//				essentialModelReference.loadedModels[className] = {klass: loadedClass, applicationDomain: appDomain};			
				EssentialModelReference.updateLoadedModels(className, loadedClass, appDomain);
				obj.setMovieClipFromClass(loadedClass);
				
				updateMovieClipForAnyClassCopies(obj, loadedClass);
			}
			
			var evt:EssentialEvent = new EssentialEvent(EssentialEvent.INSTANCE_LOADED, obj, null, true, true);
			dispatchEvent(evt);					
		}		
		
		private function updateMovieClipForAnyClassCopies(obj:Object, loadedClass:Class):void
		{
			for each (var classCopiesArray:Array in essentialModelReference.classCopies)
			{
				for each (var classCopy:Object in classCopiesArray)
				{
					if (classCopy == obj)
					{
						updateMovieClipForAllCopies(classCopiesArray, loadedClass);
					}
				}
			}			
		}
		
		private function updateMovieClipForAllCopies(classCopiesArray:Array, loadedClass:Class):void
		{
			for each (var classCopy:Object in classCopiesArray)
			{
				classCopy.setMovieClipFromClass(loadedClass);
			}
		}
		
		public function checkIfLoadingAndInstantiationComplete():void
		{
			if (instancesToLoad.length == 0 && userContentLoaded)
			{				
				var evt:EssentialEvent = new EssentialEvent(EssentialEvent.LOADING_AND_INSTANTIATION_COMPLETE);
				evt.user = _gdi.user;
				evt.gdi = _gdi;
				dispatchEvent(evt);					
				_gdi.checkForLoadedMovieClips();
			}
		}
		
		public function set gdi(val:GameDataInterface):void
		{
			_gdi = val;
		}

		public function get gdi():GameDataInterface
		{
			return _gdi;
		}
		
	}
}