/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/


#import <UIKit/UIKit.h>
#import "CustomToolbarDelegateProtocol.h"
#import "CustomButton.h"

//  CustomToolbar is used to mimic the iOS camera screen.
//  It contains a cancelButton that can be hidden and an actionImage that rotates according to
//  the device orientation. To get feedback from the buttons tapped you have to set a delegate that
//  implements CustomToolbarDelegateProtocol

@interface CustomToolbar : UIView
{
    UIButton *cancelButton;
    CustomButton *actionButton;
    UIImage *actionImage;
    UIImageView *backgroundImageView;
    
    id <CustomToolbarDelegateProtocol> delegate;
    
    BOOL shouldRotateActionButton;
}

@property (retain) UIImage *actionImage;
@property (assign) id <CustomToolbarDelegateProtocol> delegate;
@property (assign) BOOL isCancelButtonHidden;
@property (assign) BOOL shouldRotateActionButton;

@end
