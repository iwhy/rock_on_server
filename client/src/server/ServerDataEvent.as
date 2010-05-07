package server
{
	import flash.events.Event;

	public class ServerDataEvent extends Event
	{
		public static const MODEL_COLLECTION_LOADED:String = "Server:ModelCollectionLoaded";
		public static const USER_LOADED:String = "Server:UserLoaded";	
		public static const USER_CONTENT_LOADED:String = "Server:UserContentLoaded";	
		public static const GAME_CONTENT_LOADED:String = "Server:GameContentLoaded";
		public static const INSTANCE_TO_CREATE:String = "Server:InstanceToCreate";	
		public static const UPDATE_COMPLETE:String = "Server:UpdateComplete";
		public var _model:String;
		public var _params:Object;
		public var _method:String;
		
		public function ServerDataEvent(type:String, model:String=null, params:Object=null, method:String=null, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			updateProperties(model, params, method);
		}
		
		public function updateProperties(model:String=null, params:Object=null, method:String=null):void
		{
			if (model)
			{
				_model = model;			
			}
			if (params)
			{
				_params = params;
			}
			if (method)
			{
				_method = method;
			}			
		}
		
		public function set model(val:String):void
		{
			_model = val;
		}
		
		public function get model():String
		{
			return _model;
		}
			
		public function set method(val:String):void
		{
			_method = val;
		}
		
		public function get method():String
		{
			return _method;
		}	
		
		public function set params(val:Object):void
		{
			_params = val;
		}
		
		public function get params():Object
		{
			return _params;
		}
	
	}
}