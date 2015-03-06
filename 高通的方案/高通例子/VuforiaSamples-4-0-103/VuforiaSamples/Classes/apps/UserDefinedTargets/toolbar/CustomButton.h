/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/


#import <UIKit/UIKit.h>

//  Custom button that contains an UIImageView on its center and can be rotated
//  given a UIDeviceOrientation. This class is used on CustomToolbar in order to
//  mimic the iOS camera screen.

@interface CustomButton : UIButton
{
    UIImageView *customImageView;
    UIImage *customImage;
}

@property (retain) UIImage *customImage;

-(void)rotateWithOrientation:(UIDeviceOrientation)anOrientation;

@end
