package world
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.ui.Mouse;
	import flash.ui.MouseCursor;
	
	import models.EssentialModelReference;
	import models.OwnedDwelling;
	import models.OwnedStructure;
	
	import mx.collections.ArrayCollection;
	import mx.collections.Sort;
	import mx.collections.SortField;
	import mx.containers.Canvas;
	import mx.events.CollectionEvent;
	
	import rock_on.Person;
	
	import views.AssetBitmapData;
	
	public class BitmapBlotter extends BitmapData
	{
		public static const FOOT_CONSTANT:int = 9;
		public static const WIDTH_BUFFER:int = 10;
		public var _backgroundCanvas:Canvas;
		public var bitmapReferences:ArrayCollection;
		public var incrementX:int;
		public var incrementY:int;
		public var relWidth:int;
		public var relHeight:int;
		public var expectedAssetCount:int;
		public var _myWorld:World;
		
		public function BitmapBlotter(width:int, height:int, transparent:Boolean=true, fillColor:uint=4.294967295E9)
		{
			super(width, height, transparent, fillColor);
			bitmapReferences = new ArrayCollection();
			bitmapReferences.addEventListener(CollectionEvent.COLLECTION_CHANGE, onNewBitmapReference);
		}
		
		public function onNewBitmapReference(evt:CollectionEvent):void
		{
			if (bitmapReferences.length == expectedAssetCount)
			{
				bitmapReferences.removeEventListener(CollectionEvent.COLLECTION_CHANGE, onNewBitmapReference);
				renderInitialBitmap();
			}
		}
		
		public function addBitmap(asset:ActiveAsset, animation:String=null, frameNumber:int = 0):void
		{
			var abd:AssetBitmapData = this.getMatchFromBitmapReferences(asset);
			if (abd)
			{
				this.updateAssetBitmapDataLocation(abd, asset);
			}
			else
			{
				abd = createNewAssetBitmapData(asset, animation, frameNumber);
				bitmapReferences.addItem(abd);
			}
		}
		
		public function addInitialBitmap(abd:AssetBitmapData, animation:String, frameNumber:int=0):void
		{
			updateAssetBitmapData(abd, abd.activeAsset, animation, frameNumber);
			bitmapReferences.addItem(abd);
		}
		
		public function updateAssetBitmapDataLocation(abd:AssetBitmapData, asset:ActiveAsset):void
		{
			abd.activeAsset = asset;
			abd.realCoordX = asset.realCoords.x;
			abd.realCoordY = asset.realCoords.y;		
		}
		
		public function updateAssetBitmapData(abd:AssetBitmapData, asset:ActiveAsset, animation:String, frameNumber:int=0):void
		{
			abd.activeAsset = asset;
			var newMc:MovieClip = getNewMovieClip(abd.activeAsset, animation, frameNumber);
			abd.mc = newMc;
			abd.realCoordX = asset.realCoords.x;
			abd.realCoordY = asset.realCoords.y;
		}
		
		public function createNewAssetBitmapData(asset:ActiveAsset, animation:String=null, frameNumber:int=0):AssetBitmapData
		{
			var abd:AssetBitmapData = new AssetBitmapData();
			var newMc:MovieClip = getNewMovieClip(asset, animation, frameNumber);
			abd.mc = newMc;
			abd.activeAsset = asset;
			abd.realCoordX = asset.realCoords.x;
			abd.realCoordY = asset.realCoords.y;	
			return abd;
		}
		
//		public function updateAssetBitmapData(abd:AssetBitmapData, asset:ActiveAsset, animation:String=null, frameNumber:int=0):void
//		{
//			var newMc:MovieClip = getNewMovieClip(asset, animation, frameNumber);
//			abd.mc = newMc;			
//			abd.realCoordX = asset.realCoords.x;
//			abd.realCoordY = asset.realCoords.y;
//		}
		
		public function getMatchingBitmapDataForStructure(os:OwnedStructure):AssetBitmapData
		{
			for each (var abd:AssetBitmapData in this.bitmapReferences)
			{
				if (abd.activeAsset.thinger is OwnedStructure)
				{
					if (abd.activeAsset.thinger.id == os.id)
					{
						return abd;
					}
				}
			}
			return null;
		}
		
		public function removeOwnedStructure(os:OwnedStructure):void
		{
			var abd:AssetBitmapData = this.getMatchingBitmapDataForStructure(os);
			this.removeBitmapFromBlotter(abd);
		}
		
		public function getNewMovieClip(asset:ActiveAsset, animation:String=null, frameNumber:int = 0):MovieClip
		{
			var newMc:MovieClip;
			if (asset is AssetStack)
			{
				newMc = (asset as AssetStack).getMovieClipStackCopy(animation, frameNumber);			
			}
			else
			{
				newMc = EssentialModelReference.getMovieClipCopy((asset.thinger as OwnedStructure).structure.mc);
				newMc.gotoAndPlay(1);
				newMc.stop();
			}
			return newMc;			
		}
		
		public function addStructureAsBitmap(asset:ActiveAsset):void
		{
			var newMc:MovieClip = EssentialModelReference.getMovieClipCopy(asset.movieClip);
			var abd:AssetBitmapData = new AssetBitmapData();
			abd.activeAsset = asset;
			abd.realCoordX = asset.realCoordX;
			abd.realCoordY = asset.realCoordY;
			abd.mc = newMc;
			bitmapReferences.addItem(abd);	
		}
		
		public function getMatchFromBitmapReferences(asset:ActiveAsset):AssetBitmapData
		{
			for each (var abd:AssetBitmapData in bitmapReferences)
			{
				if (abd.activeAsset == asset)
				{
					return abd;
				}
			}
			return null;
		}
				
		public function getMatchingBitmap(asset:ActiveAsset):Bitmap
		{
			for each (var abd:AssetBitmapData in bitmapReferences)
			{
				if (abd.activeAsset == asset)
				{
					return abd.bitmap;
				}
			}	
			return null;			
		}
		
		public function removeRenderedBitmap(asset:ActiveAsset):void
		{
			var abd:AssetBitmapData = getMatchFromBitmapReferences(asset);
			if (abd)
			{
				if (abd.bitmap)
				{
					if (_backgroundCanvas.rawChildren.contains(abd.bitmap))
					{
						_backgroundCanvas.rawChildren.removeChild(abd.bitmap);	
					}
				}
			}			
		}
		
		public function removeBitmapFromBlotter(abd:AssetBitmapData):void
		{
			if (abd.bitmap)
			{
				if (_backgroundCanvas.rawChildren.contains(abd.bitmap))
				{
					_backgroundCanvas.rawChildren.removeChild(abd.bitmap);
					var index:int = bitmapReferences.getItemIndex(abd);
					bitmapReferences.removeItemAt(index);	
				}
			}
		}
		
		public function evaluateBitmap(asset:ActiveAsset):void
		{
			
		}
		
//		public function reRenderBitmap(asset:ActiveAsset, animation:String=null, frameNumber:int=0):void
//		{
//			var abd:AssetBitmapData = getMatchFromBitmapReferences(asset);
//			if (abd == null)
//			{
//				abd = createNewAssetBitmapData(asset, animation, frameNumber);
//			}
//			else
//			{
//				updateAssetBitmapData(abd, asset, animation, frameNumber);
//			}
//			
//			if (getMatchFromBitmapReferences(asset) == null)
//			{
//				bitmapReferences.addItem(abd);
//				sortBitmaps();
//				undrawPreviousBitmaps();
//				renderBitmaps();
//			}
//			else
//			{
//				throw new Error("Trying to re-render an already rendered asset");
//			}
//		}
		
		public function reIntroduceBitmap(abd:AssetBitmapData, animation:String=null, frameNumber:int=0):void
		{
			// Create new bitmap
			abd.mc = getNewMovieClip(abd.activeAsset, animation, frameNumber);
			abd.realCoordX = abd.activeAsset.realCoords.x;
			abd.realCoordY = abd.activeAsset.realCoords.y;			
			abd.newBitmap = getNewBitmap(abd);
			// Get overlaps
			var overlaps:ArrayCollection = getOverlappingBitmaps(abd);
			sortOverlaps(overlaps);
			reRenderOverlaps(overlaps);
		}
		
		public function reRenderOverlaps(overlaps:ArrayCollection):void
		{
			var abd:AssetBitmapData;
			for each (abd in overlaps)
			{
				if (_backgroundCanvas.rawChildren.contains(abd.bitmap))
				{
					_backgroundCanvas.rawChildren.removeChild(abd.bitmap);
				}
			}
			for each (abd in overlaps)
			{
				if (abd.newBitmap)
				{
					abd.bitmap = abd.newBitmap;
				}
				_backgroundCanvas.rawChildren.addChild(abd.bitmap);
			}
		
		}
		
		public function sortOverlaps(overlaps:ArrayCollection):void
		{
			var sortField:SortField = new SortField("realCoordY");
			sortField.numeric = true;
			var sort:Sort = new Sort();
			sort.fields = [sortField];
			overlaps.sort = sort;
			overlaps.refresh();				
		}
		
		public function getOverlappingBitmaps(stander:AssetBitmapData):ArrayCollection
		{
			var overlaps:ArrayCollection = new ArrayCollection();
			for each (var abd:AssetBitmapData in bitmapReferences)
			{
				if ((abd.realCoordY - abd.transformedHeight) < (stander.realCoordY - stander.transformedHeight) && 
					abd.realCoordY > (stander.realCoordY - stander.transformedHeight) && 
					((abd.realCoordX > stander.realCoordX && abd.realCoordX < stander.realCoordX + stander.transformedWidth*2) ||
						abd.realCoordX + abd.transformedWidth*2 > stander.realCoordX && abd.realCoordX + abd.transformedWidth*2 < stander.realCoordX + stander.transformedWidth*2))
				{
					overlaps.addItem(abd);
				}			
			}
			return overlaps;
		}
		
		public function doesBitmapOverlapWithAsset(abd:AssetBitmapData, bitmap:Bitmap):Boolean
		{
			var bp:Bitmap = abd.bitmap;
			if (bitmap.bitmapData.rect.bottom < bp.bitmapData.rect.bottom && 
				bitmap.bitmapData.rect.top > bp.bitmapData.rect.bottom && 
				((bitmap.bitmapData.rect.right > bp.bitmapData.rect.left && bitmap.bitmapData.rect.right < bp.bitmapData.rect.right) ||
					bitmap.bitmapData.rect.left > bp.bitmapData.rect.left && bitmap.bitmapData.rect.left < bp.bitmapData.rect.right))
			{
				return true;
			}
			return false;
		}
		
		public function renderInitialBitmap():void
		{
			sortBitmaps();
			renderBitmaps();
		}
		
		public function renderReplacedBitmaps():void
		{
			updateBitmapLocations();
			sortBitmaps();
//			undrawPreviousBitmaps();
			renderUpdatedBitmaps();
		}
		
		public function renderUpdatedBitmaps():void
		{
			for each (var abd:AssetBitmapData in bitmapReferences)
			{
				if (abd)
				{
					_backgroundCanvas.rawChildren.addChild(abd.bitmap);
				}
			}			
		}
		
		public function updateBitmapLocations():void
		{
			for each (var abd:AssetBitmapData in bitmapReferences)
			{
				if (abd)
				{
					moveRenderedBitmap(abd);
				}
			}
		}
		
		public function renderBitmaps():void
		{
			for each (var abd:AssetBitmapData in bitmapReferences)
			{
				var bp:Bitmap;
				if (abd)
				{
					if (abd.activeAsset is Person)
					{
						bp = getBitmapForPerson(abd);
					}
					else
					{
						bp = getBitmapForStructure(abd);
					}
					_backgroundCanvas.rawChildren.addChild(bp);			
				}
			}			
		}
		
		public function getNewBitmap(abd:AssetBitmapData):Bitmap
		{
			var bp:Bitmap;
			if (abd.activeAsset is Person)
			{
				bp = getBitmapForPerson(abd);
			}
			else
			{
				bp = getBitmapForStructure(abd);
			}	
			return bp;
		}
		
		public function moveRenderedBitmap(abd:AssetBitmapData):void
		{
			var bmd:BitmapData = abd.bitmap.bitmapData;
			var bp:Bitmap = new Bitmap();
			bp.bitmapData = bmd;
			bp.opaqueBackground = null;				
			bp.x = abd.realCoordX - abd.mc.width/2;
			bp.y = relHeight/2 + abd.realCoordY - abd.mc.height;			
//			abd.bitmap.transform.matrix.tx = (abd.realCoordX - abd.mc.width/2) - abd.bitmap.x;
//			abd.bitmap.transform.matrix.ty = (relHeight/2 + abd.realCoordY - abd.mc.height) - abd.bitmap.y;	
			abd.bitmap = bp;
		}
		
		public function getBitmapForStructure(abd:AssetBitmapData):Bitmap
		{
			var bmd:BitmapData = new BitmapData(relWidth, relHeight, true, 0x00000000);
			var bottomSlice:Number = (abd.mc.transform.pixelBounds.bottom/abd.mc.transform.pixelBounds.height)*abd.mc.height;
			var rect:Rectangle = new Rectangle(0, 0, abd.mc.width + WIDTH_BUFFER, abd.mc.height + bottomSlice);
			var matrix:Matrix = new Matrix();
			matrix.tx = abd.mc.width/2;	
			matrix.ty = abd.mc.height;
			bmd.draw(abd.mc, matrix, new ColorTransform(), null, rect);
			var bp:Bitmap = new Bitmap();
			bp.bitmapData = bmd;
			bp.opaqueBackground = null;				
			bp.x = abd.realCoordX - abd.mc.width/2;
			bp.y = relHeight/2 + abd.realCoordY - abd.mc.height;
			abd.bitmap = bp;
			return bp;
		}

		public function getBitmapForPerson(abd:AssetBitmapData):Bitmap
		{
			var bmd:BitmapData = new BitmapData(relWidth, relHeight, true, 0x00000000);
			abd.mc.scaleX = 0.4;
			abd.mc.scaleY = 0.4;
			var rect:Rectangle = new Rectangle(0, 0, abd.mc.width + WIDTH_BUFFER, abd.mc.height + FOOT_CONSTANT);
			var matrix:Matrix = new Matrix();
			matrix.scale(0.4, 0.4);
			matrix.tx = abd.mc.width/2 + WIDTH_BUFFER/2;
			var pb:PeachBody = new PeachBody();
			var pbHeight:int = pb.height;
			var heightDiff:int = abd.mc.height - pb.height;
			matrix.ty = abd.mc.height;
			abd.transformedHeight = matrix.ty;
			abd.transformedWidth = matrix.tx;
			bmd.draw(abd.mc, matrix, new ColorTransform(), null, rect);
			var bp:Bitmap = new Bitmap();
			bp.bitmapData = bmd;
			bp.opaqueBackground = null;				
			bp.x = abd.realCoordX - abd.mc.width/2;
			bp.y = relHeight/2 + abd.realCoordY - abd.mc.height;
			abd.bitmap = bp;
			return bp;
		}
		
		public function undrawPreviousBitmaps():void
		{
//			var totalChildren:int = _backgroundCanvas.rawChildren.numChildren.valueOf();
//			for (var i:int = 0; i < totalChildren; i++)
//			{
//				if (_backgroundCanvas.rawChildren)
//				{
//					_backgroundCanvas.rawChildren.removeChildAt(0);				
//				}
//			}
		}
		
		private function onMouseMove(evt:MouseEvent):void
		{
			for each (var abd:AssetBitmapData in bitmapReferences)
			{
				if (abd.bitmap)
				{
					var hitRect:Rectangle = new Rectangle(abd.bitmap.x, abd.bitmap.y, abd.mc.width, abd.mc.height);
					if (hitRect.contains(_backgroundCanvas.mouseX, _backgroundCanvas.mouseY))
					{
						backgroundCanvas.buttonMode = true;
						break;
					}
					else
					{
						backgroundCanvas.buttonMode = false;
					}
				}	
			}
		}
		
		public function sortBitmaps():void
		{
			var sortField:SortField = new SortField("realCoordY");
			sortField.numeric = true;
			var sort:Sort = new Sort();
			sort.fields = [sortField];
			bitmapReferences.sort = sort;
			bitmapReferences.refresh();					
		}
		
		public function set myWorld(val:World):void
		{
			_myWorld = val;
		}
		
		public function set backgroundCanvas(val:Canvas):void
		{
			_backgroundCanvas = val;
			_backgroundCanvas.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		}
		
		public function get backgroundCanvas():Canvas
		{
			return _backgroundCanvas;
		}
	}
}