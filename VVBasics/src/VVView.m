//
//  VVView.m
//  VVOpenSource
//
//  Created by bagheera on 11/1/12.
//
//

#import "VVView.h"
#import "VVBasicMacros.h"




//	macro for performing a bitmask and returning a BOOL
#define VVBITMASKCHECK(mask,flagToCheck) ((mask & flagToCheck) == flagToCheck) ? ((BOOL)YES) : ((BOOL)NO)




@implementation VVView


- (id) initWithFrame:(NSRect)n	{
	if (self = [super init])	{
		[self generalInit];
		frame = n;
		bounds = NSMakeRect(0,0,frame.size.width,frame.size.height);
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	deleted = NO;
	spriteManager = [[VVSpriteManager alloc] init];
	spritesNeedUpdate = YES;
	//needsDisplay = YES;
	frame = NSMakeRect(0,0,1,1);
	minFrameSize = NSMakeSize(1.0,1.0);
	bounds = frame;
	superview = nil;
	containerView = nil;
	subviews = [[MutLockArray alloc] init];
	autoresizesSubviews = YES;
	autoresizingMask = VVViewResizeMaxXMargin | VVViewResizeMinYMargin;
	propertyLock = OS_SPINLOCK_INIT;
	lastMouseEvent = nil;
	isOpaque = NO;
	for (int i=0;i<4;++i)	{
		clearColor[i] = 0.0;
		borderColor[i] = 0.0;
	}
	drawBorder = NO;
	mouseDownModifierFlags = 0;
	modifierFlags = 0;
	mouseIsDown = NO;
	clickedSubview = nil;
}
- (void) prepareToBeDeleted	{
	NSMutableArray		*subCopy = [subviews lockCreateArrayCopy];
	if (subCopy != nil)	{
		[subCopy retain];
		for (id subview in subCopy)
			[self removeSubview:subview];
		[subCopy removeAllObjects];
		[subCopy release];
		subCopy = nil;
	}
	
	if (spriteManager != nil)
		[spriteManager prepareToBeDeleted];
	spritesNeedUpdate = NO;
	deleted = YES;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(subviews);
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	OSSpinLockUnlock(&propertyLock);
	[super dealloc];
}


- (void) mouseDown:(NSEvent *)e	{
	NSLog(@"%s",__func__);
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	mouseIsDown = YES;
	NSPoint		locationInWindow = [e locationInWindow];
	NSPoint		localPoint = [self convertPoint:locationInWindow fromView:nil];
	mouseDownModifierFlags = [e modifierFlags];
	modifierFlags = mouseDownModifierFlags;
	if ((mouseDownModifierFlags&NSControlKeyMask)==NSControlKeyMask)
		[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
	else
		[spriteManager localMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
}
- (void) rightMouseDown:(NSEvent *)e	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	mouseIsDown = YES;
	NSPoint		locationInWindow = [e locationInWindow];
	NSPoint		localPoint = [self convertPoint:locationInWindow fromView:nil];
	[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
}
- (void) mouseDragged:(NSEvent *)e	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	[spriteManager localMouseDragged:localPoint];
}
- (void) mouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	mouseIsDown = NO;
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	[spriteManager localMouseUp:localPoint];
}
- (void) rightMouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	mouseIsDown = NO;
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	[spriteManager localRightMouseUp:localPoint];
}
- (void) keyDown:(NSEvent *)e	{
	NSLog(@"%s ... %@",__func__,e);
}
- (void) keyUp:(NSEvent *)e	{
	NSLog(@"%s ... %@",__func__,e);
}


- (NSPoint) convertPoint:(NSPoint)pointInWindow fromView:(id)view	{
	if (deleted || containerView==nil)
		return pointInWindow;
	//	"containerView" points to the NSView-subclass that "owns" me- convert the passed point to coords local to "containerView", then convert them further to coords local to this view
	NSPoint		returnMe = [containerView convertPoint:pointInWindow fromView:nil];
	//	...now run up through my superviews, modifying the point to account for frame offsets!
	id			tmpSuperview = superview;
	if (tmpSuperview != nil)	{
		do	{
			NSRect		superviewFrame = [tmpSuperview frame];
			tmpSuperview = [tmpSuperview superview];
			returnMe.x += superviewFrame.origin.x;
			returnMe.y += superviewFrame.origin.y;
		} while (tmpSuperview != nil);
	}
	return returnMe;
}
//	the point it's passed is in coords local to self!
- (id) vvSubviewHitTest:(NSPoint)p	{
	//NSLog(@"%s ... %@- %f, %f",__func__,self,p.x,p.y);
	//	convert the point so its coords are local to the container view
	//NSPoint				p = [self convertPoint:pointInWindow fromView:nil];
	//NSLog(@"\t\tconverted point is (%f, %f)",p.x,p.y);
	NSRect				localBounds = [self bounds];
	//NSRectLog(@"\t\tmy frame is",localFrame);
	if (!NSPointInRect(p,localBounds))
		return nil;
	id					returnMe = nil;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		NSRect			tmpFrame = [viewPtr frame];
		NSPoint			viewLocalPoint = NSMakePoint(p.x-tmpFrame.origin.x, p.y-tmpFrame.origin.y);
		if (NSPointInRect(p,tmpFrame))	{
			returnMe = [viewPtr vvSubviewHitTest:viewLocalPoint];
			if (returnMe != nil)
				break;
		}
	}
	[subviews unlock];
	if (returnMe == nil)
		returnMe = self;
	return returnMe;
	
	/*
	//	convert the point to coords local to me
	//NSPoint			convertedPoint = [self convertPoint:p fromView:[[self window] contentView]];
	NSRect			localBounds = [self bounds];
	if (p.x<0 || p.y<0 || p.x>localBounds.size.width || p.y>localBounds.size.height)
		return nil;
	id				returnMe = nil;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		NSRect		tmpFrame = [viewPtr frame];
		if (NSPointInRect(p,tmpFrame))	{
			NSPoint		tmpPoint = NSMakePoint(p.x-tmpFrame.origin.x,p.y-tmpFrame.origin.y);
			returnMe = [viewPtr hitTest:tmpPoint];
			if (returnMe != nil)
				break;
		}
	}
	[subviews unlock];
	if (returnMe == nil)
		returnMe = self;
	return returnMe;
	*/
}
- (BOOL) checkRect:(NSRect)n	{
	return NSIntersectsRect(n,frame);
}


- (NSRect) frame	{
	return frame;
}
- (void) setFrame:(NSRect)n	{
	//NSLog(@"%s ... (%f, %f) : %f x %f",__func__,n.origin.x,n.origin.y,n.size.width,n.size.height);
	if (NSEqualRects(n,frame))
		return;
	[self setFrameSize:n.size];
	frame.origin = n.origin;
}
- (void) setFrameSize:(NSSize)proposedSize	{
	//NSLog(@"%s ... (%f x %f)",__func__,n.width,n.height);
	NSSize			oldSize = frame.size;
	NSSize			n = NSMakeSize(fmax(minFrameSize.width,proposedSize.width),fmax(minFrameSize.height,proposedSize.height));
	
	if ([self autoresizesSubviews])	{
		double		widthDelta = n.width - oldSize.width;
		double		heightDelta = n.height - oldSize.height;
		[subviews rdlock];
		for (VVView *viewPtr in [subviews array])	{
			VVViewResizeMask	viewResizeMask = [viewPtr autoresizingMask];
			NSRect				viewNewFrame = [viewPtr frame];
			//NSRectLog(@"\t\torig viewNewFrame is",viewNewFrame);
			int					hSubDivs = 0;
			int					vSubDivs = 0;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinXMargin))
				++hSubDivs;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMaxXMargin))
				++hSubDivs;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeWidth))
				++hSubDivs;
			
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinYMargin))
				++vSubDivs;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMaxYMargin))
				++vSubDivs;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeHeight))
				++vSubDivs;
			
			if (hSubDivs>0 || vSubDivs>0)	{
				if (hSubDivs>0 && VVBITMASKCHECK(viewResizeMask,VVViewResizeWidth))
					viewNewFrame.size.width += widthDelta/hSubDivs;
				if (vSubDivs>0 && VVBITMASKCHECK(viewResizeMask,VVViewResizeHeight))
					viewNewFrame.size.height += heightDelta/vSubDivs;
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinXMargin))
					viewNewFrame.origin.x += widthDelta/hSubDivs;
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinYMargin))
					viewNewFrame.origin.y += heightDelta/vSubDivs;
			}
			//NSRectLog(@"\t\tmod viewNewFrame is",viewNewFrame);
			[viewPtr setFrame:viewNewFrame];
		}
		[subviews unlock];
	}
	
	frame.size = n;
	bounds = NSMakeRect(0,0,frame.size.width,frame.size.height);
}
- (NSRect) bounds	{
	return bounds;
}
- (void) setBounds:(NSRect)n	{
	bounds = n;	
}
- (NSRect) visibleRect	{
	return NSZeroRect;
}


@synthesize autoresizesSubviews;
@synthesize autoresizingMask;
- (void) addSubview:(id)n	{
	if (deleted || n==nil || subviews==nil)
		return;
	[subviews wrlock];
	if (![subviews containsIdenticalPtr:n])	{
		[subviews addObject:n];
		[n setContainerView:containerView];
		if (containerView != nil)
			[containerView setNeedsDisplay:YES];
	}
	[subviews unlock];
}
- (void) removeSubview:(id)n	{
	if (deleted || n==nil || subviews==nil)
		return;
	[subviews lockRemoveIdenticalPtr:n];
	[n setContainerView:nil];
	if (containerView != nil)
		[containerView setNeedsDisplay:YES];
}
- (void) removeFromSuperview	{
	if (deleted)
		return;
	NSLog(@"%s - ERR",__func__);
}
- (void) setContainerView:(id)n	{
	containerView = n;
	if (subviews!=nil && [subviews count]>0)	{
		[subviews lockMakeObjectsPerformSelector:@selector(setContainerView:) withObject:n];
	}
}
- (id) containerView	{
	return containerView;
}
- (MutLockArray *) subviews	{
	return subviews;
}
- (id) window	{
	return nil;
}


- (void) drawRect:(NSRect)r	{
	NSLog(@"ERR: %s",__func__);
	/*		this method should never be called or used, ever.		*/
}
- (void) _drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	
	if (spritesNeedUpdate)
		[self updateSprites];
	
	//	if i'm opaque, fill my bounds
	OSSpinLockLock(&propertyLock);
	if (isOpaque)	{
		glColor4f(clearColor[0], clearColor[1], clearColor[2], 1.0);
		GLDRAWRECT(bounds);
	}
	OSSpinLockUnlock(&propertyLock);
	
	//	tell the sprite manager to draw
	if (spriteManager != nil)
		[spriteManager drawRect:r];
	
	//	...now call the "meat" of my drawing method (where most drawing code will be handled)
	[self drawRect:r inContext:cgl_ctx];
	
	//	if there's a border, draw it now
	OSSpinLockLock(&propertyLock);
	if (drawBorder)	{
		glColor4f(borderColor[0], borderColor[1], borderColor[2], borderColor[3]);
		GLSTROKERECT(bounds);
	}
	OSSpinLockUnlock(&propertyLock);
	
	//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
	[self finishedDrawing];

	//	if i have subviews, tell them to draw now- back to front...
	if (subviews!=nil && [subviews count]>0)	{
		[subviews rdlock];
		for (VVView *viewPtr in [[subviews array] reverseObjectEnumerator])	{
			NSRect		tmpFrame = [viewPtr frame];
			if (NSIntersectsRect(r, tmpFrame))	{
				glPushMatrix();
				glTranslatef(tmpFrame.origin.x, tmpFrame.origin.y, 0.0);
				
				tmpFrame.origin = NSMakePoint(0,0);
				[viewPtr _drawRect:tmpFrame inContext:cgl_ctx];
				
				glPopMatrix();
			}
		}
		[subviews unlock];
	}
}
- (void) drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx	{
	NSLog(@"ERR: %s",__func__);
	/*		this method should be used by subclasses.  put the simple drawing code in here.		*/
}
- (BOOL) isOpaque	{
	return isOpaque;
}
- (void) finishedDrawing	{
	
}
- (void) updateSprites	{
	spritesNeedUpdate = NO;
}

@synthesize deleted;
@synthesize spriteManager;
@synthesize spritesNeedUpdate;
- (void) setSpritesNeedUpdate	{
	spritesNeedUpdate = YES;
}
//@synthesize needsDisplay;
//- (void) setNeedsDisplay	{
//	[self setNeedsDisplay:YES];
//}
//- (void) setNeedsRender:(BOOL)n	{
//	if (n)
//		[self setNeedsDisplay:YES];
//}
//- (void) setNeedsRender	{
//	[self setNeedsDisplay:YES];
//}
//- (BOOL) needsRender	{
//	return needsDisplay;
//}
@synthesize lastMouseEvent;
- (void) setClearColor:(NSColor *)n	{

}
- (void) setClearColors:(GLfloat)r:(GLfloat)g:(GLfloat)b:(GLfloat)a	{

}
- (void) setBorderColor:(NSColor *)n	{

}
- (void) setBorderColors:(GLfloat)r:(GLfloat)g:(GLfloat)b:(GLfloat)a	{

}
@synthesize drawBorder;
@synthesize mouseDownModifierFlags;
@synthesize modifierFlags;
@synthesize mouseIsDown;


@end
