/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.
 
Confidential and Proprietary - Qualcomm Connected Experiences, Inc.
Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/


#import "CustomButton.h"

@implementation CustomButton

#pragma mark - Private

#pragma mark - Properties

-(void)setCustomImage:(UIImage *)anImage
{
    if (customImage != anImage)
    {
        [customImage release];
        customImage = anImage;
        [customImage retain];
        
        customImageView.image = anImage;
        
        CGRect newFrame = CGRectMake((self.frame.size.width - anImage.size.width)/2,
                                     (self.frame.size.height - anImage.size.height)/2,
                                     anImage.size.width,
                                     anImage.size.height);
        customImageView.frame = newFrame;
    }
}

-(UIImage *)customImage
{
    return customImage;
}

#pragma mark - Public

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        customImageView = [[UIImageView alloc] initWithFrame:frame];
        [self addSubview:customImageView];
    }
    return self;
}

-(void)dealloc
{
    [customImageView release];
    [super dealloc];
}

// Although this is a portrait app, we rotate the camera icon to stay upright in
// landscape orientations
-(void)rotateWithOrientation:(UIDeviceOrientation)anOrientation
{
    //  Set rotation
    float rotation = 0;
    BOOL rotate = YES;
    
    switch (anOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            rotation = -M_PI_2;
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            rotation = M_PI_2;
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
        case UIInterfaceOrientationPortrait:
            break;
            
        default:
            // Leave the rotation as it is
            rotate = NO;
            break;
    }
    
    if (YES == rotate) {
        //  Animate rotation
        [UIView animateWithDuration:0.3 animations:^{
            CGAffineTransform transform = CGAffineTransformMakeRotation(rotation);
            customImageView.transform = transform;
        }];
    }
}

@end
